//
//  BodyGuide.swift
//  guaperrimo.ai
//
//  The framing guide: a smooth human outline (head to mid-shin) that reacts to
//  the positioning state, plus the large instruction the user reads from
//  120 cm away. The figure is a visual guide only: BodyPoseDetector reads
//  Vision joints (shoulder width, neck height), not this rectangle.
//

import SwiftUI

// MARK: - Guide shape

/// A relaxed standing figure, arms slightly away from the body, drawn as one
/// closed outline smoothed with a Catmull-Rom spline. Fills its bounding rect;
/// the bottom edge is meant to be faded out by the caller.
struct BodyGuideShape: Shape {
    /// Right half of the outline, from the top of the head down to the crotch,
    /// as (x from centre, y from top) fractions of the bounding rect.
    private static let rightHalf: [(CGFloat, CGFloat)] = [
        (0.000, 0.000),  // top of head
        (0.080, 0.012),
        (0.112, 0.070),  // side of head
        (0.095, 0.130),
        (0.052, 0.158),  // jaw to neck
        (0.050, 0.195),  // neck base
        (0.190, 0.212),  // trapezius
        (0.300, 0.240),  // shoulder
        (0.330, 0.300),  // deltoid
        (0.338, 0.440),  // elbow
        (0.322, 0.550),
        (0.306, 0.610),  // wrist
        (0.292, 0.665),  // hand
        (0.270, 0.705),  // fingertips
        (0.244, 0.690),
        (0.244, 0.612),  // wrist, inner
        (0.256, 0.520),
        (0.266, 0.440),  // elbow, inner
        (0.246, 0.350),
        (0.214, 0.286),  // armpit
        (0.204, 0.360),
        (0.178, 0.470),  // waist
        (0.218, 0.570),  // hip
        (0.210, 0.680),
        (0.180, 0.800),
        (0.165, 0.860),  // knee
        (0.145, 0.950),
        (0.135, 1.000),  // shin, outer bottom
        (0.045, 1.000),  // shin, inner bottom
        (0.050, 0.950),
        (0.055, 0.860),  // knee, inner
        (0.060, 0.740),
        (0.000, 0.635),  // crotch
    ]

    func path(in rect: CGRect) -> Path {
        let right = Self.rightHalf
        // Closed polygon: right side top → bottom, then the mirrored left side bottom → top.
        let left = right.dropFirst().dropLast().reversed().map { (-$0.0, $0.1) }
        let points = (right + left).map { p in
            CGPoint(x: rect.midX + p.0 * rect.width, y: rect.minY + p.1 * rect.height)
        }
        return Path.catmullRom(closed: points)
    }
}

private extension Path {
    /// Closed Catmull-Rom spline through `points`, as cubic Béziers.
    static func catmullRom(closed points: [CGPoint]) -> Path {
        var path = Path()
        let n = points.count
        guard n > 2 else { return path }
        path.move(to: points[0])
        for i in 0..<n {
            let p0 = points[(i - 1 + n) % n]
            let p1 = points[i]
            let p2 = points[(i + 1) % n]
            let p3 = points[(i + 2) % n]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Guide figure

/// The outline with its fill and glow, in one of four looks.
struct BodyGuideFigure: View {
    enum Look { case searching, adjusting, aligned, capturing }

    let look: Look
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ink: Color {
        switch look {
        case .searching, .adjusting: DS.textPrimary
        case .aligned, .capturing: DS.success
        }
    }

    private var strokeOpacity: Double {
        switch look {
        case .searching: breathing ? 0.95 : 0.55
        case .adjusting: 0.4
        case .aligned, .capturing: 1
        }
    }

    private var fillOpacity: Double {
        switch look {
        case .searching: 0.06
        case .adjusting: 0.04
        case .aligned: 0.14
        case .capturing: 0.18
        }
    }

    var body: some View {
        ZStack {
            BodyGuideShape()
                .fill(ink.opacity(fillOpacity))
            BodyGuideShape()
                .stroke(ink.opacity(look == .aligned || look == .capturing ? 0.45 : 0.15), lineWidth: 10)
                .blur(radius: 8)
            BodyGuideShape()
                .stroke(ink.opacity(strokeOpacity), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .mask(
            LinearGradient(
                stops: [.init(color: .white, location: 0), .init(color: .white, location: 0.86), .init(color: .clear, location: 1)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .scaleEffect(look == .capturing && breathing ? 1.015 : 1)
        .animation(.easeInOut(duration: 0.35), value: look)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Overlay

/// Silhouette plus the large instruction, driven by the detector's state.
struct CameraGuideLayer: View {
    let state: PositioningState
    let countdownActive: Bool
    /// Shown only while nobody is in frame.
    let setupHint: String?

    private var look: BodyGuideFigure.Look {
        if countdownActive { return .capturing }
        switch state {
        case .noPerson: return .searching
        case .tooFar, .tooClose, .offCenter: return .adjusting
        case .aligned, .stillConfirmed: return .aligned
        }
    }

    private var instruction: String {
        if countdownActive { return String(localized: "hold_still") }
        switch state {
        case .noPerson: return String(localized: "no_person")
        case .tooFar: return String(localized: "too_far")
        case .tooClose: return String(localized: "too_close")
        case .offCenter(.left): return String(localized: "move_right")
        case .offCenter(.right): return String(localized: "move_left")
        case .aligned: return String(localized: "stay_still")
        case .stillConfirmed: return String(localized: "hold_still")
        }
    }

    private var directionSymbol: String? {
        guard !countdownActive else { return nil }
        switch state {
        case .tooFar: return "arrow.up.left.and.arrow.down.right"
        case .tooClose: return "arrow.down.right.and.arrow.up.left"
        case .offCenter(.left): return "chevron.right.2"
        case .offCenter(.right): return "chevron.left.2"
        default: return nil
        }
    }

    var body: some View {
        GeometryReader { geo in
            let screenH = geo.size.height
            let screenW = geo.size.width
            let figureH = screenH * 0.68
            let figureW = figureH * 0.45
            let bottomMargin = screenH * 0.15
            let centerY = screenH - bottomMargin - figureH / 2

            ZStack {
                BodyGuideFigure(look: look)
                    .frame(width: figureW, height: figureH)
                    .position(x: screenW / 2, y: centerY)

                if let directionSymbol {
                    Image(systemName: directionSymbol)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                        .shadow(color: DS.bg.opacity(0.8), radius: 6)
                        .position(x: screenW / 2, y: centerY - figureH * 0.08)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }

                VStack(spacing: DS.Space.xs) {
                    Text(instruction)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(look == .aligned || look == .capturing ? DS.success : DS.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Space.m)
                        .padding(.vertical, DS.Space.s)
                        .background(DS.bg.opacity(0.72), in: RoundedRectangle(cornerRadius: DS.Radius.m))
                        .animation(.easeInOut(duration: 0.25), value: instruction)

                    if let setupHint, state == .noPerson, !countdownActive {
                        Text(setupHint)
                            .font(DS.Font.monoSmall)
                            .foregroundStyle(DS.textSecondary)
                            .padding(.horizontal, DS.Space.s)
                            .padding(.vertical, DS.Space.xxs)
                            .background(DS.bg.opacity(0.6), in: RoundedRectangle(cornerRadius: DS.Radius.s))
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, DS.Space.inset)
                .frame(maxWidth: .infinity)
                .position(x: screenW / 2, y: screenH * 0.105)
            }
            .animation(.easeInOut(duration: 0.3), value: directionSymbol)
            .animation(.easeInOut(duration: 0.3), value: state == .noPerson)
        }
        .allowsHitTesting(false)
    }
}
