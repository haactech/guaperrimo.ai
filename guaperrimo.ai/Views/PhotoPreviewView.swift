//
//  PhotoPreviewView.swift
//  guaperrimo.ai
//

#if os(iOS)
import Photos
import SwiftUI
import UIKit

struct PhotoPreviewView: View {
    let image: UIImage
    let onRetake: () -> Void
    let onSave: () -> Void

    @State private var isSaved = false
    @State private var isSaving = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()

            VStack {
                Spacer()

                if isSaved {
                    Label(String(localized: "photo_saved"), systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.opacity.combined(with: .scale))
                        .padding(.bottom, 16)
                }

                HStack(spacing: 40) {
                    Button {
                        onRetake()
                    } label: {
                        Label(String(localized: "retake"), systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(.ultraThinMaterial, in: Capsule())
                    }

                    Button {
                        saveToPhotoLibrary()
                    } label: {
                        Label(
                            isSaved
                                ? String(localized: "photo_saved")
                                : String(localized: "save_photo"),
                            systemImage: isSaved ? "checkmark" : "square.and.arrow.down"
                        )
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                    }
                    .disabled(isSaving || isSaved)
                }
                .padding(.bottom, 40)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isSaved)
    }

    private func saveToPhotoLibrary() {
        isSaving = true
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in isSaving = false }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                guard let data = image.jpegData(compressionQuality: 0.95) else { return }
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            } completionHandler: { success, _ in
                Task { @MainActor in
                    isSaving = false
                    if success {
                        isSaved = true
                        onSave()
                    }
                }
            }
        }
    }
}
#endif
