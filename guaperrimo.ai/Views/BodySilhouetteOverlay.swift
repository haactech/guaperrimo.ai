//
//  BodySilhouetteOverlay.swift
//  guaperrimo.ai
//

import SwiftUI

// MARK: - Head-to-knees silhouette shape

/// Draws a human silhouette from head to knees (no lower legs/feet).
/// Designed to fill its bounding rect — the parent view controls sizing & positioning.
struct BodySilhouetteShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let centerX = w * 0.5

        // --- Proportions relative to bounding rect ---
        // Head
        let headCenterY = h * 0.05
        let headRX = w * 0.12
        let headRY = h * 0.04

        // Neck
        let neckTop = headCenterY + headRY
        let neckBottom = h * 0.115
        let neckHalfW = w * 0.045

        // Shoulders
        let shoulderY = h * 0.14
        let shoulderHalfW = w * 0.30

        // Arms
        let armTopY = shoulderY + h * 0.01
        let elbowY = h * 0.32
        let wristY = h * 0.44
        let armOuterOffset = w * 0.055
        let elbowOuterOffset = w * 0.085
        let wristOuterOffset = w * 0.06

        // Torso
        let waistY = h * 0.46
        let waistHalfW = w * 0.21
        let hipY = h * 0.56
        let hipHalfW = w * 0.26

        // Upper legs (end at knees — bottom of shape)
        let kneeY = h * 0.98
        let legOuterW = w * 0.13
        let legInnerGap = w * 0.05

        var path = Path()

        // Head (ellipse)
        path.addEllipse(in: CGRect(
            x: centerX - headRX,
            y: headCenterY - headRY,
            width: headRX * 2,
            height: headRY * 2
        ))

        // -------- Left side (top → down) --------
        path.move(to: CGPoint(x: centerX - neckHalfW, y: neckTop))
        path.addLine(to: CGPoint(x: centerX - neckHalfW, y: neckBottom))

        // Neck → shoulder
        path.addQuadCurve(
            to: CGPoint(x: centerX - shoulderHalfW, y: shoulderY),
            control: CGPoint(x: centerX - shoulderHalfW * 0.5, y: neckBottom)
        )

        // Left arm down
        let lArmX = centerX - shoulderHalfW - armOuterOffset
        let lElbowX = centerX - waistHalfW - elbowOuterOffset
        let lWristX = centerX - waistHalfW - wristOuterOffset

        path.addLine(to: CGPoint(x: lArmX, y: armTopY))
        path.addQuadCurve(
            to: CGPoint(x: lElbowX, y: elbowY),
            control: CGPoint(x: lArmX - w * 0.015, y: (armTopY + elbowY) / 2)
        )
        path.addQuadCurve(
            to: CGPoint(x: lWristX, y: wristY),
            control: CGPoint(x: lElbowX - w * 0.015, y: (elbowY + wristY) / 2)
        )

        // Hand bump
        path.addQuadCurve(
            to: CGPoint(x: lWristX + w * 0.04, y: wristY + h * 0.02),
            control: CGPoint(x: lWristX - w * 0.012, y: wristY + h * 0.015)
        )

        // Back up to waist
        path.addLine(to: CGPoint(x: centerX - waistHalfW, y: waistY))

        // Waist → hip
        path.addQuadCurve(
            to: CGPoint(x: centerX - hipHalfW, y: hipY),
            control: CGPoint(x: centerX - hipHalfW, y: (waistY + hipY) / 2)
        )

        // Left thigh outer → knee
        path.addQuadCurve(
            to: CGPoint(x: centerX - legOuterW, y: kneeY),
            control: CGPoint(x: centerX - hipHalfW + w * 0.03, y: (hipY + kneeY) / 2)
        )

        // Flat knee bottom (left)
        path.addLine(to: CGPoint(x: centerX - legInnerGap, y: kneeY))

        // Left inner thigh going up
        path.addLine(to: CGPoint(x: centerX - legInnerGap, y: hipY + h * 0.06))

        // Crotch curve
        path.addQuadCurve(
            to: CGPoint(x: centerX + legInnerGap, y: hipY + h * 0.06),
            control: CGPoint(x: centerX, y: hipY + h * 0.10)
        )

        // Right inner thigh going down
        path.addLine(to: CGPoint(x: centerX + legInnerGap, y: kneeY))

        // Flat knee bottom (right)
        path.addLine(to: CGPoint(x: centerX + legOuterW, y: kneeY))

        // Right thigh outer going up
        path.addQuadCurve(
            to: CGPoint(x: centerX + hipHalfW, y: hipY),
            control: CGPoint(x: centerX + hipHalfW - w * 0.03, y: (hipY + kneeY) / 2)
        )

        // Right hip → waist
        path.addQuadCurve(
            to: CGPoint(x: centerX + waistHalfW, y: waistY),
            control: CGPoint(x: centerX + hipHalfW, y: (waistY + hipY) / 2)
        )

        // Right hand
        let rWristX = centerX + waistHalfW + wristOuterOffset
        let rElbowX = centerX + waistHalfW + elbowOuterOffset
        let rArmX = centerX + shoulderHalfW + armOuterOffset

        path.addLine(to: CGPoint(x: rWristX - w * 0.04, y: wristY + h * 0.02))
        path.addQuadCurve(
            to: CGPoint(x: rWristX, y: wristY),
            control: CGPoint(x: rWristX + w * 0.012, y: wristY + h * 0.015)
        )

        // Right arm going up
        path.addQuadCurve(
            to: CGPoint(x: rElbowX, y: elbowY),
            control: CGPoint(x: rWristX + w * 0.015, y: (elbowY + wristY) / 2)
        )
        path.addQuadCurve(
            to: CGPoint(x: rArmX, y: armTopY),
            control: CGPoint(x: rArmX + w * 0.015, y: (armTopY + elbowY) / 2)
        )

        // Right shoulder → neck
        path.addLine(to: CGPoint(x: centerX + shoulderHalfW, y: shoulderY))
        path.addQuadCurve(
            to: CGPoint(x: centerX + neckHalfW, y: neckBottom),
            control: CGPoint(x: centerX + shoulderHalfW * 0.5, y: neckBottom)
        )
        path.addLine(to: CGPoint(x: centerX + neckHalfW, y: neckTop))

        return path
    }
}

// MARK: - Overlay view with positioning per spec

/// Positions the silhouette at 70% screen height, anchored to the lower portion.
/// Head starts at ~18% from top, knees end at ~12% from bottom.
struct BodySilhouetteOverlay: View {
    var strokeColor: Color = Color.red.opacity(0.8)
    var isBlinking: Bool = false
    var isPulsing: Bool = false

    var body: some View {
        GeometryReader { geo in
            let screenH = geo.size.height
            let screenW = geo.size.width
            let silhouetteHeight = screenH * 0.70
            let silhouetteWidth = silhouetteHeight * 0.45  // aspect ratio per spec
            let bottomMargin = screenH * 0.12
            let centerY = screenH - bottomMargin - silhouetteHeight / 2

            BodySilhouetteShape()
                .stroke(
                    strokeColor,
                    style: StrokeStyle(lineWidth: 3, dash: [10, 5])
                )
                .frame(width: silhouetteWidth, height: silhouetteHeight)
                .position(x: screenW / 2, y: centerY)
        }
        .opacity(isBlinking ? 0.1 : 1.0)
        .scaleEffect(isPulsing ? 1.02 : 1.0)
        .animation(
            isBlinking
                ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                : .easeInOut(duration: 0.3),
            value: isBlinking
        )
        .animation(
            isPulsing
                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                : .easeInOut(duration: 0.3),
            value: isPulsing
        )
        .animation(.easeInOut(duration: 0.3), value: strokeColor.description)
    }
}
