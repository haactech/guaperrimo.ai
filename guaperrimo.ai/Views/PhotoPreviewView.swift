//
//  PhotoPreviewView.swift
//  guaperrimo.ai
//

#if os(iOS)
import OSLog
import SwiftUI
import UIKit

private let logger = Logger(subsystem: "ai.guaperrimo", category: "PhotoPreview")

struct PhotoPreviewView: View {
    let image: UIImage
    let onRetake: () -> Void

    @State private var isSaved = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showConversation = false
    @State private var uploadedSessionId: String?
    @State private var uploadedImageUrl: String?

    private let uploadService = ImageUploadService()

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

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
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
                        uploadImage()
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Label(
                                    isSaved
                                        ? String(localized: "photo_saved")
                                        : String(localized: "save_photo"),
                                    systemImage: isSaved ? "checkmark" : "square.and.arrow.up"
                                )
                            }
                        }
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
        .animation(.easeInOut(duration: 0.3), value: errorMessage)
        .fullScreenCover(isPresented: $showConversation) {
            if let sessionId = uploadedSessionId, let imageUrl = uploadedImageUrl {
                ConversationView(sessionId: sessionId, imageUrl: imageUrl)
            }
        }
    }

    private func uploadImage() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let sessionId = UUID().uuidString
                logger.info("🚀 Starting upload — session: \(sessionId)")
                let response = try await uploadService.upload(image: image, sessionId: sessionId)
                logger.info("✅ Saved — session: \(response.sessionId), url: \(response.url)")
                isSaved = true
                uploadedSessionId = response.sessionId
                uploadedImageUrl = response.url
                showConversation = true
            } catch {
                logger.error("❌ Upload failed: \(String(describing: error))")
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
#endif
