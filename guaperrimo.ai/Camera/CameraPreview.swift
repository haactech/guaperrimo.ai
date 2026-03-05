//
//  CameraPreview.swift
//  guaperrimo.ai
//

#if os(iOS)
import AVFoundation
import SwiftUI

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill

        // Disable mirror so preview shows the real (un-mirrored) image
        if let connection = view.previewLayer.connection {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }

        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
#endif
