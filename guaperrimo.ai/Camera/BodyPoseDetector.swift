//
//  BodyPoseDetector.swift
//  guaperrimo.ai
//

#if os(iOS)
import AVFoundation
import Vision
import os

nonisolated(unsafe) private let logger = Logger(subsystem: "ai.guaperrimo", category: "BodyPoseDetector")

nonisolated enum OffCenterDirection: Sendable, Equatable {
    case left, right
}

nonisolated enum PositioningState: Sendable, Equatable {
    case noPerson
    case tooClose
    case tooFar
    case offCenter(OffCenterDirection)
    case aligned
    case stillConfirmed
}

// MARK: - Debug info

nonisolated struct BodyPoseDebugInfo: Sendable {
    struct JointInfo: Sendable {
        let name: String
        let position: CGPoint  // normalized Vision coords (0-1)
        let confidence: Float
    }

    var joints: [JointInfo] = []
    var shoulderWidthPx: CGFloat = 0
    var centerOffsetX: CGFloat = 0  // normalized, 0.5 = centered
    var neckY: CGFloat = 0          // normalized Vision y
    var stillnessProgress: CGFloat = 0  // 0-1, ratio of buffer filled
    var averageDisplacement: CGFloat = 0
    var rawState: PositioningState = .noPerson  // pre-hysteresis state
}

@Observable
final class BodyPoseDetector {
    var positioningState: PositioningState = .noPerson
    var averageJointDisplacement: CGFloat = 0.0
    var debugInfo = BodyPoseDebugInfo()

    // MARK: - Private state protected by lock

    private struct BufferState {
        var frameCounter: Int = 0
        var stillnessBuffer: [[CGPoint]]  // [jointIndex][frameIndex]
        var bufferIndex: Int = 0
        var bufferFilled: Bool = false

        // Hysteresis
        var candidateState: PositioningState = .noPerson
        var candidateFrameCount: Int = 0
        var confirmedState: PositioningState = .noPerson

        init() {
            let jointCount = PositioningConfig.trackedJointCount
            let windowSize = PositioningConfig.stillnessWindowFrames
            stillnessBuffer = Array(
                repeating: Array(repeating: .zero, count: windowSize),
                count: jointCount
            )
        }
    }

    private let lock = OSAllocatedUnfairLock(initialState: BufferState())

    // 6 joints tracked for stillness — nose + shoulders + hips + neck
    nonisolated(unsafe) private static let trackedJoints: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .neck, .leftShoulder, .rightShoulder, .leftHip, .rightHip
    ]

    // MARK: - Process frame

    nonisolated func processFrame(_ sampleBuffer: CMSampleBuffer) {
        // Frame skip: analyze 1 of every 2 frames (~15fps)
        let shouldSkip = lock.withLock { state -> Bool in
            state.frameCounter += 1
            return state.frameCounter % 2 != 0
        }
        if shouldSkip { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up
        )

        let request = VNDetectHumanBodyPoseRequest()

        do {
            try handler.perform([request])
        } catch {
            return
        }

        guard let observation = request.results?.first else {
            // No person detected — but DON'T reset buffer immediately.
            // Let hysteresis decide. Only reset if confirmed state moves away from aligned.
            let published = updateStateWithHysteresis(newState: .noPerson)
            Task { @MainActor in
                self.averageJointDisplacement = 0
                self.debugInfo = BodyPoseDebugInfo()
                if let state = published { self.positioningState = state }
            }
            return
        }

        let imageWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let imageHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        let (newState, displacement, info) = evaluatePositioning(
            observation: observation,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )

        let published = updateStateWithHysteresis(newState: newState)
        Task { @MainActor in
            self.averageJointDisplacement = displacement
            self.debugInfo = info
            if let state = published {
                self.positioningState = state
            }
        }
    }

    // MARK: - State hysteresis (anti-oscillation)

    /// Only publishes a state change after `stateConfirmationFrames` consecutive frames agree.
    /// Returns the new confirmed state if changed, nil otherwise.
    /// Also resets the stillness buffer when confirmed state leaves aligned/stillConfirmed.
    private nonisolated func updateStateWithHysteresis(newState: PositioningState) -> PositioningState? {
        lock.withLock { state -> PositioningState? in
            if newState == state.candidateState {
                state.candidateFrameCount += 1
            } else {
                state.candidateState = newState
                state.candidateFrameCount = 1
            }

            if state.candidateFrameCount >= PositioningConfig.stateConfirmationFrames
                && state.candidateState != state.confirmedState {
                let oldState = state.confirmedState
                state.confirmedState = state.candidateState
                let newConfirmed = state.confirmedState

                // Reset stillness buffer only when CONFIRMED state leaves aligned/stillConfirmed
                let wasAligned = (oldState == .aligned || oldState == .stillConfirmed)
                let isAligned = (newConfirmed == .aligned || newConfirmed == .stillConfirmed)
                if wasAligned && !isAligned {
                    state.bufferIndex = 0
                    state.bufferFilled = false
                }

                logger.debug("State: \(String(describing: oldState)) → \(String(describing: newConfirmed))")
                return newConfirmed
            }
            return nil
        }
    }

    // MARK: - State evaluation (priority order per spec)
    //
    // 1. No observation           → noPerson
    // 2. Knees not visible         → tooClose
    // 3. Neck not in top third     → tooFar
    // 4. Shoulders off-center      → offCenter
    // 5. All OK                    → aligned
    // 6. Still for 75 frames       → stillConfirmed

    private nonisolated func evaluatePositioning(
        observation: VNHumanBodyPoseObservation,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> (state: PositioningState, displacement: CGFloat, debugInfo: BodyPoseDebugInfo) {
        let conf = PositioningConfig.jointConfidenceMin
        var info = BodyPoseDebugInfo()

        // Collect debug joint info
        let debugJointNames: [(VNHumanBodyPoseObservation.JointName, String)] = [
            (.neck, "neck"), (.leftShoulder, "L.shoulder"), (.rightShoulder, "R.shoulder"),
            (.leftHip, "L.hip"), (.rightHip, "R.hip"),
            (.leftKnee, "L.knee"), (.rightKnee, "R.knee"),
            (.nose, "nose")
        ]
        for (jointName, label) in debugJointNames {
            if let pt = try? observation.recognizedPoint(jointName) {
                info.joints.append(.init(name: label, position: pt.location, confidence: pt.confidence))
            }
        }

        // Need at least shoulders to evaluate anything
        let leftShoulder = try? observation.recognizedPoint(.leftShoulder)
        let rightShoulder = try? observation.recognizedPoint(.rightShoulder)
        let lsConf = leftShoulder?.confidence ?? 0
        let rsConf = rightShoulder?.confidence ?? 0

        guard let leftShoulder, let rightShoulder,
              lsConf > conf, rsConf > conf
        else {
            info.rawState = .noPerson
            logger.debug("RAW=noPerson | L.shoulder=\(lsConf, format: .fixed(precision: 2)) R.shoulder=\(rsConf, format: .fixed(precision: 2)) threshold=\(conf, format: .fixed(precision: 2))")
            return (.noPerson, 0, info)
        }

        // Shoulder width in pixels (for debug)
        let shoulderWidthPx = abs(leftShoulder.location.x - rightShoulder.location.x) * imageWidth
        info.shoulderWidthPx = shoulderWidthPx

        // Priority 1: At least one hip must be visible (if not → user is too close)
        let leftHip = try? observation.recognizedPoint(.leftHip)
        let rightHip = try? observation.recognizedPoint(.rightHip)
        let lhConf = leftHip?.confidence ?? 0
        let rhConf = rightHip?.confidence ?? 0
        let anyHipVisible = lhConf > conf || rhConf > conf
        if !anyHipVisible {
            info.rawState = .tooClose
            logger.debug("RAW=tooClose | L.hip=\(lhConf, format: .fixed(precision: 2)) R.hip=\(rhConf, format: .fixed(precision: 2))")
            return (.tooClose, 0, info)
        }

        // Priority 2: Neck must be in upper portion of frame
        // Vision coords: y=0 is bottom, y=1 is top.
        let neck = try? observation.recognizedPoint(.neck)
        if let neck = neck, neck.confidence > conf {
            info.neckY = neck.location.y
            if neck.location.y < PositioningConfig.neckYMin {
                info.rawState = .tooFar
                logger.debug("RAW=tooFar | neckY=\(neck.location.y, format: .fixed(precision: 3)) need>\(PositioningConfig.neckYMin, format: .fixed(precision: 2))")
                return (.tooFar, 0, info)
            }
        }

        // Priority 3: Horizontal centering — shoulder midpoint within 40-60%
        let midpointX = (leftShoulder.location.x + rightShoulder.location.x) / 2.0
        info.centerOffsetX = midpointX
        let centerMin = 0.5 - PositioningConfig.centerTolerance
        let centerMax = 0.5 + PositioningConfig.centerTolerance

        if midpointX < centerMin {
            info.rawState = .offCenter(.right)
            logger.debug("RAW=offCenter(R) | midX=\(midpointX, format: .fixed(precision: 3))")
            return (.offCenter(.right), 0, info)
        }
        if midpointX > centerMax {
            info.rawState = .offCenter(.left)
            logger.debug("RAW=offCenter(L) | midX=\(midpointX, format: .fixed(precision: 3))")
            return (.offCenter(.left), 0, info)
        }

        // All positioning checks pass — person is aligned
        // Now check stillness
        let pixelPositions = Self.trackedJoints.map { jointName -> CGPoint in
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence > conf
            else {
                return .zero
            }
            return CGPoint(
                x: point.location.x * imageWidth,
                y: point.location.y * imageHeight
            )
        }

        let (isStill, avgDisplacement) = updateStillnessBuffer(positions: pixelPositions)
        info.averageDisplacement = avgDisplacement

        // Stillness progress for debug
        let progress = lock.withLock { state -> CGFloat in
            if state.bufferFilled { return 1.0 }
            return CGFloat(state.bufferIndex) / CGFloat(PositioningConfig.stillnessWindowFrames)
        }
        info.stillnessProgress = progress

        if isStill {
            info.rawState = .stillConfirmed
            logger.debug("RAW=stillConfirmed | disp=\(avgDisplacement, format: .fixed(precision: 1)) stillness=\(progress * 100, format: .fixed(precision: 0))%")
            return (.stillConfirmed, avgDisplacement, info)
        }

        info.rawState = .aligned
        logger.debug("RAW=aligned | disp=\(avgDisplacement, format: .fixed(precision: 1)) stillness=\(progress * 100, format: .fixed(precision: 0))% neckY=\(info.neckY, format: .fixed(precision: 3)) midX=\(info.centerOffsetX, format: .fixed(precision: 3))")
        return (.aligned, avgDisplacement, info)
    }

    // MARK: - Stillness buffer

    private nonisolated func updateStillnessBuffer(positions: [CGPoint]) -> (isStill: Bool, avgDisplacement: CGFloat) {
        lock.withLock { state -> (Bool, CGFloat) in
            let idx = state.bufferIndex
            for j in 0..<positions.count {
                state.stillnessBuffer[j][idx] = positions[j]
            }
            state.bufferIndex = (idx + 1) % PositioningConfig.stillnessWindowFrames
            if state.bufferIndex == 0 {
                state.bufferFilled = true
            }

            guard state.bufferFilled else { return (false, 0) }

            // Calculate average displacement across all tracked joints
            let windowSize = PositioningConfig.stillnessWindowFrames
            var totalDisplacement: CGFloat = 0
            var validJoints = 0

            for j in 0..<positions.count {
                let buffer = state.stillnessBuffer[j]
                if positions[j] == .zero { continue }

                var jointDisplacement: CGFloat = 0
                for i in 1..<windowSize {
                    let prev = buffer[(state.bufferIndex + i - 1) % windowSize]
                    let curr = buffer[(state.bufferIndex + i) % windowSize]
                    if prev == .zero || curr == .zero { continue }
                    let dx = curr.x - prev.x
                    let dy = curr.y - prev.y
                    jointDisplacement += sqrt(dx * dx + dy * dy)
                }
                totalDisplacement += jointDisplacement / CGFloat(windowSize - 1)
                validJoints += 1
            }

            guard validJoints > 0 else { return (false, 0) }
            let avgDisplacement = totalDisplacement / CGFloat(validJoints)
            return (avgDisplacement < PositioningConfig.stillnessThresholdPx, avgDisplacement)
        }
    }

    nonisolated func resetState() {
        lock.withLock { state in
            state.bufferIndex = 0
            state.bufferFilled = false
            state.candidateFrameCount = 0
            state.candidateState = .noPerson
            state.confirmedState = .noPerson
        }
        Task { @MainActor in
            self.positioningState = .noPerson
            self.averageJointDisplacement = 0
            self.debugInfo = BodyPoseDebugInfo()
        }
    }
}
#endif
