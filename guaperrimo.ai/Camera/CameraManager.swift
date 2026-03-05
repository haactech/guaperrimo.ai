//
//  CameraManager.swift
//  guaperrimo.ai
//

#if os(iOS)
import AudioToolbox
import AVFoundation
import SwiftUI
import UIKit

@Observable
final class CameraManager: NSObject {
    var capturedImage: UIImage?
    var isPhotoTaken = false
    var cameraPermission: AVAuthorizationStatus = .notDetermined
    let bodyPoseDetector = BodyPoseDetector()

    private(set) var session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    func checkPermission() {
        cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraPermission {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.cameraPermission = granted ? .authorized : .denied
                    if granted { self.setupSession() }
                }
            }
        case .authorized:
            setupSession()
        default:
            break
        }
    }

    func setupSession() {
        sessionQueue.async { [self] in
            session.beginConfiguration()
            session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .front
            ),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                session.commitConfiguration()
                return
            }

            session.addInput(input)

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            if session.canAddOutput(videoDataOutput) {
                session.addOutput(videoDataOutput)
            }

            // Fix orientation: deliver frames in portrait so Vision coordinates match screen
            if let videoConnection = videoDataOutput.connection(with: .video) {
                videoConnection.videoRotationAngle = 90
            }
            if let photoConnection = photoOutput.connection(with: .video) {
                photoConnection.videoRotationAngle = 90
            }

            session.commitConfiguration()
            session.startRunning()
        }
    }

    func startSession() {
        sessionQueue.async { [self] in
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [self] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    func capturePhoto() {
        playShutterSound()
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func playShutterSound() {
        AudioServicesPlaySystemSound(1108)
    }

    var debugOverlayEnabled = false
    var debugScreenSize: CGSize = .zero

    func retakePhoto() {
        capturedImage = nil
        isPhotoTaken = false
        debugOverlayEnabled = false
    }

    /// Composites the silhouette guide + body pose debug info onto the photo.
    /// Maps screen coordinates → photo coordinates accounting for aspectFill crop.
    func overlayGuideOnImage(_ image: UIImage, screenSize: CGSize) -> UIImage {
        let imgW = image.size.width
        let imgH = image.size.height
        let debugInfo = bodyPoseDetector.debugInfo
        let posState = bodyPoseDetector.positioningState

        // --- Calculate the visible rect (what aspectFill shows on screen) ---
        let imgAspect = imgW / imgH
        let scrAspect = screenSize.width / screenSize.height

        let visibleRect: CGRect
        if imgAspect > scrAspect {
            let visibleW = imgH * scrAspect
            let cropX = (imgW - visibleW) / 2
            visibleRect = CGRect(x: cropX, y: 0, width: visibleW, height: imgH)
        } else {
            let visibleH = imgW / scrAspect
            let cropY = (imgH - visibleH) / 2
            visibleRect = CGRect(x: 0, y: cropY, width: imgW, height: visibleH)
        }

        // --- Silhouette rect ---
        let silH = visibleRect.height * 0.70
        let silW = silH * 0.45
        let bottomMargin = visibleRect.height * 0.12

        let silRect = CGRect(
            x: visibleRect.midX - silW / 2,
            y: visibleRect.maxY - bottomMargin - silH,
            width: silW,
            height: silH
        )

        let confMin = PositioningConfig.jointConfidenceMin

        // --- Draw ---
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { ctx in
            image.draw(at: .zero)

            // Silhouette outline
            let shape = BodySilhouetteShape()
            let path = shape.path(in: silRect)
            ctx.cgContext.setStrokeColor(UIColor.red.withAlphaComponent(0.8).cgColor)
            ctx.cgContext.setLineWidth(max(4, imgW / 250))
            ctx.cgContext.setLineDash(phase: 0, lengths: [16, 8])
            ctx.cgContext.addPath(path.cgPath)
            ctx.cgContext.strokePath()

            // Crosshair at center
            let cx = visibleRect.midX
            let cy = visibleRect.midY
            ctx.cgContext.setStrokeColor(UIColor.yellow.withAlphaComponent(0.5).cgColor)
            ctx.cgContext.setLineWidth(2)
            ctx.cgContext.setLineDash(phase: 0, lengths: [])
            ctx.cgContext.move(to: CGPoint(x: cx - 30, y: cy))
            ctx.cgContext.addLine(to: CGPoint(x: cx + 30, y: cy))
            ctx.cgContext.move(to: CGPoint(x: cx, y: cy - 30))
            ctx.cgContext.addLine(to: CGPoint(x: cx, y: cy + 30))
            ctx.cgContext.strokePath()

            // Visible area border
            ctx.cgContext.setStrokeColor(UIColor.yellow.withAlphaComponent(0.3).cgColor)
            ctx.cgContext.setLineWidth(3)
            ctx.cgContext.stroke(visibleRect)

            // --- Joint dots from Vision ---
            let dotRadius: CGFloat = max(8, imgW / 150)
            for joint in debugInfo.joints {
                // Vision coords: (0,0) = bottom-left, (1,1) = top-right
                // UIKit image coords: (0,0) = top-left, (w,h) = bottom-right
                let px = joint.position.x * imgW
                let py = (1.0 - joint.position.y) * imgH  // flip Y

                let isConfident = joint.confidence > confMin
                let dotColor = isConfident
                    ? UIColor.green.withAlphaComponent(0.9)
                    : UIColor.red.withAlphaComponent(0.9)

                ctx.cgContext.setFillColor(dotColor.cgColor)
                ctx.cgContext.fillEllipse(in: CGRect(
                    x: px - dotRadius, y: py - dotRadius,
                    width: dotRadius * 2, height: dotRadius * 2
                ))

                // Label next to dot
                let label = String(format: "%@ %.2f", joint.name, joint.confidence)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: max(14, imgW / 100), weight: .bold),
                    .foregroundColor: UIColor.white,
                    .backgroundColor: UIColor.black.withAlphaComponent(0.6)
                ]
                let nsLabel = NSString(string: label)
                nsLabel.draw(at: CGPoint(x: px + dotRadius + 4, y: py - dotRadius), withAttributes: attrs)
            }

            // --- Skeleton lines connecting joints ---
            let jointPositions: [String: CGPoint] = Dictionary(
                debugInfo.joints.map { ($0.name, CGPoint(x: $0.position.x * imgW, y: (1.0 - $0.position.y) * imgH)) },
                uniquingKeysWith: { first, _ in first }
            )
            let connections: [(String, String)] = [
                ("neck", "L.shoulder"), ("neck", "R.shoulder"),
                ("L.shoulder", "L.hip"), ("R.shoulder", "R.hip"),
                ("L.hip", "L.knee"), ("R.hip", "R.knee"),
                ("L.hip", "R.hip"), ("L.shoulder", "R.shoulder"),
                ("neck", "nose")
            ]
            ctx.cgContext.setStrokeColor(UIColor.cyan.withAlphaComponent(0.6).cgColor)
            ctx.cgContext.setLineWidth(max(2, imgW / 400))
            ctx.cgContext.setLineDash(phase: 0, lengths: [])
            for (from, to) in connections {
                if let p1 = jointPositions[from], let p2 = jointPositions[to] {
                    ctx.cgContext.move(to: p1)
                    ctx.cgContext.addLine(to: p2)
                }
            }
            ctx.cgContext.strokePath()

            // --- Debug info text panel (top-left) ---
            let lines: [String] = [
                "STATE: \(posState)",
                "RAW: \(debugInfo.rawState)",
                String(format: "Displacement: %.1f px", debugInfo.averageDisplacement),
                String(format: "Shoulder W: %.0f px", debugInfo.shoulderWidthPx),
                String(format: "Center X: %.3f (need 0.4-0.6)", debugInfo.centerOffsetX),
                String(format: "Neck Y: %.3f (need >%.2f)", debugInfo.neckY, PositioningConfig.neckYMin),
                String(format: "Stillness: %.0f%%", debugInfo.stillnessProgress * 100),
                String(format: "Conf threshold: %.2f", PositioningConfig.jointConfidenceMin),
            ]

            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: max(16, imgW / 80), weight: .medium),
                .foregroundColor: UIColor.white
            ]

            // Background for text
            let lineHeight = max(20, imgW / 60)
            let panelHeight = lineHeight * CGFloat(lines.count) + 20
            let panelWidth = imgW * 0.55
            ctx.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
            ctx.cgContext.fill(CGRect(x: 10, y: 10, width: panelWidth, height: panelHeight))

            for (i, line) in lines.enumerated() {
                let nsLine = NSString(string: line)
                nsLine.draw(
                    at: CGPoint(x: 20, y: 18 + lineHeight * CGFloat(i)),
                    withAttributes: textAttrs
                )
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        bodyPoseDetector.processFrame(sampleBuffer)
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)
        else { return }

        Task { @MainActor in
            self.capturedImage = self.debugOverlayEnabled
                ? self.overlayGuideOnImage(image, screenSize: self.debugScreenSize)
                : image
            self.isPhotoTaken = true
        }
    }
}
#endif
