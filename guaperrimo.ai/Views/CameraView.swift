//
//  CameraView.swift
//  guaperrimo.ai
//

#if os(iOS)
import AVFoundation
import SwiftUI

// MARK: - Onboarding instruction screen (shown once)

struct SetupInstructionView: View {
    let onReady: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Setup illustration
                VStack(spacing: 16) {
                    Image(systemName: "iphone.and.arrow.left.and.arrow.right")
                        .font(.system(size: 64))
                        .foregroundStyle(.white.opacity(0.8))

                    // Distance indicator
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.title3)
                        Text("120 cm")
                            .font(.title3.weight(.semibold))
                    }
                    .foregroundStyle(.green)
                }

                // Instruction text
                Text(String(localized: "onboarding_instruction"))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Ready button
                Button {
                    onReady()
                } label: {
                    Text(String(localized: "onboarding_ready"))
                        .font(.headline)
                        .foregroundStyle  (.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Shake gesture detector

#if DEBUG
struct ShakeDetector: UIViewRepresentable {
    let onShake: () -> Void

    func makeUIView(context: Context) -> ShakeDetectorUIView {
        let view = ShakeDetectorUIView()
        view.onShake = onShake
        return view
    }

    func updateUIView(_ uiView: ShakeDetectorUIView, context: Context) {
        uiView.onShake = onShake
    }

    final class ShakeDetectorUIView: UIView {
        var onShake: (() -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            becomeFirstResponder()
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            if motion == .motionShake {
                onShake?()
            }
        }
    }
}
#endif

// MARK: - Main camera view

struct CameraView: View {
    @State private var cameraManager = CameraManager()
    @State private var countdownRemaining: Int = 0
    @State private var countdownActive = false
    @State private var countdownTimer: Timer?
    @State private var countdownProgress: CGFloat = 0.0
    @State private var showFlash = false
    @State private var showOnboarding: Bool
    @State private var debugTimerActive = false
    @State private var debugTimerRemaining: Int = 0
    @State private var debugTimer: Timer?
    #if DEBUG
    @State private var showDebugPanel = true
    #endif

    init() {
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenCameraOnboarding")
        _showOnboarding = State(initialValue: !hasSeenOnboarding)
    }

    private var posState: PositioningState {
        cameraManager.bodyPoseDetector.positioningState
    }

    private var hasSeenOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "hasSeenCameraOnboarding")
    }

    var body: some View {
        if showOnboarding {
            SetupInstructionView {
                UserDefaults.standard.set(true, forKey: "hasSeenCameraOnboarding")
                withAnimation {
                    showOnboarding = false
                }
            }
        } else {
            cameraContent
        }
    }

    private var cameraContent: some View {
        ZStack {
            // Layer 1: Camera preview
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()

            // Layer 2: Silhouette overlay
            BodySilhouetteOverlay(
                strokeColor: silhouetteColor,
                isBlinking: posState == .noPerson,
                isPulsing: countdownActive
            )
            .ignoresSafeArea()

            // Layer 3: Controls
            VStack(spacing: 0) {
                // Compact banner for returning users
                if hasSeenOnboarding {
                    Text(String(localized: "setup_banner"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.4), in: Capsule())
                        .padding(.top, 52)
                }

                // Positioning instruction
                Text(instructionText)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.top, hasSeenOnboarding ? 8 : 60)
                    .animation(.easeInOut(duration: 0.3), value: instructionText)

                Spacer()

                // Capture controls
                HStack(alignment: .center, spacing: 40) {
                    // 5s timer button
                    Button {
                        startDebugTimer()
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .stroke(.white.opacity(0.6), lineWidth: 2)
                                    .frame(width: 50, height: 50)
                                if debugTimerActive {
                                    Text("\(debugTimerRemaining)")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(.yellow)
                                } else {
                                    Image(systemName: "timer")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white)
                                }
                            }
                            Text("5s")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .disabled(debugTimerActive || countdownActive)

                    // Main capture / countdown
                    ZStack {
                        if countdownActive {
                            Circle()
                                .trim(from: 0, to: countdownProgress)
                                .stroke(.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 90, height: 90)

                            Text("\(countdownRemaining)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        } else {
                            Button {
                                cameraManager.capturePhoto()
                                triggerFlash()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 72, height: 72)
                                    Circle()
                                        .stroke(.white, lineWidth: 4)
                                        .frame(width: 82, height: 82)
                                }
                            }
                            .disabled(debugTimerActive)
                        }
                    }

                    // Spacer to balance layout
                    Color.clear
                        .frame(width: 50, height: 50)
                }
                .padding(.bottom, 40)
            }

            // Layer 4: Flash overlay
            if showFlash {
                Color.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Permission denied overlay
            if cameraManager.cameraPermission == .denied ||
                cameraManager.cameraPermission == .restricted {
                CameraPermissionView()
            }

            #if DEBUG
            // Debug panel overlay (top-right)
            if showDebugPanel {
                debugPanelOverlay
            }

            // Shake detector (invisible, just listens for shake)
            ShakeDetector {
                showDebugPanel.toggle()
            }
            .frame(width: 0, height: 0)
            #endif
        }
        .statusBarHidden()
        .onChange(of: posState) { oldState, newState in
            handleStateChange(from: oldState, to: newState)
        }
        .onChange(of: cameraManager.bodyPoseDetector.averageJointDisplacement) { _, newDisplacement in
            if countdownActive && newDisplacement > PositioningConfig.movementCancelThresholdPx {
                cancelCountdown()
            }
        }
        .fullScreenCover(isPresented: $cameraManager.isPhotoTaken) {
            if let image = cameraManager.capturedImage {
                PhotoPreviewView(
                    image: image,
                    onRetake: {
                        cameraManager.retakePhoto()
                    }
                )
            }
        }
        .onAppear {
            cameraManager.checkPermission()
        }
        .onDisappear {
            cancelCountdown()
            cancelDebugTimer()
            cameraManager.stopSession()
        }
    }

    // MARK: - State-driven UI

    private var instructionText: String {
        if countdownActive {
            return String(localized: "hold_still")
        }
        switch posState {
        case .noPerson:
            return String(localized: "no_person")
        case .tooFar:
            return String(localized: "too_far")
        case .tooClose:
            return String(localized: "too_close")
        case .offCenter(.left):
            return String(localized: "move_right")
        case .offCenter(.right):
            return String(localized: "move_left")
        case .aligned:
            return String(localized: "stay_still")
        case .stillConfirmed:
            return String(localized: "hold_still")
        }
    }

    private var silhouetteColor: Color {
        switch posState {
        case .noPerson:
            return Color.white           // blinking handled by overlay animation
        case .tooClose, .tooFar, .offCenter:
            return Color.white.opacity(0.25)
        case .aligned:
            return Color.green.opacity(0.7)
        case .stillConfirmed:
            return Color.green
        }
    }

    // MARK: - State transitions

    private func handleStateChange(from oldState: PositioningState, to newState: PositioningState) {
        switch newState {
        case .stillConfirmed:
            if !countdownActive {
                startCountdown()
            }
        case .aligned:
            // Still aligned but moving -- don't cancel yet
            break
        default:
            if countdownActive {
                cancelCountdown()
            }
        }
    }

    // MARK: - Countdown

    private func startCountdown() {
        let total = PositioningConfig.countdownSeconds
        countdownRemaining = total
        countdownProgress = 0.0
        countdownActive = true

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                guard countdownActive else { return }
                countdownRemaining -= 1

                withAnimation(.linear(duration: 1.0)) {
                    countdownProgress = CGFloat(total - countdownRemaining) / CGFloat(total)
                }

                if countdownRemaining <= 0 {
                    cancelCountdown()
                    cameraManager.capturePhoto()
                    triggerFlash()
                }
            }
        }

        // Animate the first segment
        withAnimation(.linear(duration: 1.0)) {
            countdownProgress = 1.0 / CGFloat(total)
        }
    }

    private func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownActive = false
        countdownRemaining = 0
        countdownProgress = 0.0
    }

    // MARK: - Debug 5s timer (ignores pose detection)

    private func startDebugTimer() {
        guard !debugTimerActive else { return }
        debugTimerRemaining = 5
        debugTimerActive = true

        debugTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                guard debugTimerActive else { return }
                debugTimerRemaining -= 1
                if debugTimerRemaining <= 0 {
                    cancelDebugTimer()
                    cameraManager.debugOverlayEnabled = true
                    cameraManager.debugScreenSize = UIScreen.main.bounds.size
                    cameraManager.capturePhoto()
                    triggerFlash()
                }
            }
        }
    }

    private func cancelDebugTimer() {
        debugTimer?.invalidate()
        debugTimer = nil
        debugTimerActive = false
        debugTimerRemaining = 0
    }

    private func triggerFlash() {
        showFlash = true
        withAnimation(.easeOut(duration: 0.15)) {
            showFlash = false
        }
    }

    // MARK: - Debug panel

    #if DEBUG
    private var debugPanelOverlay: some View {
        let info = cameraManager.bodyPoseDetector.debugInfo
        let displacement = cameraManager.bodyPoseDetector.averageJointDisplacement

        return VStack(alignment: .leading, spacing: 4) {
            Text("CONFIRMED: \(String(describing: posState))")
            Text("RAW: \(String(describing: info.rawState))")
            Text(String(format: "Displacement: %.1f px", displacement))
            Text(String(format: "Shoulder W: %.0f px", info.shoulderWidthPx))
            Text(String(format: "Center X: %.3f", info.centerOffsetX))
            Text(String(format: "Neck Y: %.3f", info.neckY))
            Text(String(format: "Stillness: %.0f%%", info.stillnessProgress * 100))

            Divider().background(.white.opacity(0.3))

            ForEach(Array(info.joints.enumerated()), id: \.offset) { _, joint in
                HStack(spacing: 4) {
                    Circle()
                        .fill(joint.confidence > PositioningConfig.jointConfidenceMin ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(String(format: "%@ %.2f", joint.name, joint.confidence))
                }
            }
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.white)
        .padding(8)
        .background(.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 80)
        .padding(.trailing, 8)
        .allowsHitTesting(false)
    }
    #endif
}
#endif
