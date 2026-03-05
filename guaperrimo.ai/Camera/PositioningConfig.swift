//
//  PositioningConfig.swift
//  guaperrimo.ai
//

import Foundation

// Constants accessed from nonisolated contexts (camera processing queue).
// Using nonisolated(unsafe) to avoid MainActor isolation inference.
enum PositioningConfig {
    // MARK: - Stillness detection
    nonisolated(unsafe) static let stillnessWindowFrames = 30
    nonisolated(unsafe) static let stillnessThresholdPx: CGFloat = 8.0
    nonisolated(unsafe) static let movementCancelThresholdPx: CGFloat = 15.0

    // MARK: - Shoulder width (pixel-based at ~120cm distance)
    nonisolated(unsafe) static let shoulderWidthMinPx: CGFloat = 160.0
    nonisolated(unsafe) static let shoulderWidthMaxPx: CGFloat = 240.0

    // MARK: - Center tolerance
    nonisolated(unsafe) static let centerTolerance: CGFloat = 0.10  // midpoint must be within 40-60%

    // MARK: - Vertical position — neck must be in upper portion of frame
    // Vision coordinates: 0 = bottom, 1 = top
    // Lowered from 0.65 to accommodate phone-on-desk angle
    nonisolated(unsafe) static let neckYMin: CGFloat = 0.40

    // MARK: - Joint confidence
    nonisolated(unsafe) static let jointConfidenceMin: Float = 0.2

    // MARK: - Anti-oscillation (state hysteresis)
    nonisolated(unsafe) static let stateConfirmationFrames = 8

    // MARK: - Countdown
    nonisolated(unsafe) static let countdownSeconds = 3

    // MARK: - Tracked joints for stillness
    nonisolated(unsafe) static let trackedJointCount = 6
}
