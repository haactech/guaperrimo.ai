//
//  PhotoPreviewView.swift
//  guaperrimo.ai
//

#if os(iOS)
import OSLog
import SwiftUI
import UIKit

private let logger = Logger(subsystem: "ai.guaperrimo", category: "PhotoPreview")

/// Confirms the captured photo and starts the stylist session.
/// "Analizar mi outfit" uploads the photo and opens the conversation. Once uploaded, the same
/// button becomes "Continuar sesión", so closing the conversation does not leave a dead end.
struct PhotoPreviewView: View {
    let image: UIImage
    let onRetake: () -> Void

    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var showConversation = false
    @State private var uploadedSessionId: String?
    @State private var uploadedImageUrl: String?

    private let uploadService = ImageUploadService()

    private var hasUploaded: Bool {
        uploadedSessionId != nil && uploadedImageUrl != nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()

            VStack {
                Spacer()

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .scale))
                }

                HStack(spacing: 12) {
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
                    .disabled(isUploading)

                    Button {
                        if hasUploaded {
                            showConversation = true
                        } else {
                            uploadImage()
                        }
                    } label: {
                        Group {
                            if isUploading {
                                ProgressView()
                                    .tint(.black)
                            } else if hasUploaded {
                                Label(String(localized: "continue_session"), systemImage: "arrow.right.circle.fill")
                            } else {
                                Label(String(localized: "analyze_outfit"), systemImage: "sparkles")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                    }
                    .disabled(isUploading)
                }
                .padding(.bottom, 40)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isUploading)
        .animation(.easeInOut(duration: 0.3), value: errorMessage)
        .fullScreenCover(isPresented: $showConversation) {
            if let sessionId = uploadedSessionId, let imageUrl = uploadedImageUrl {
                ConversationView(sessionId: sessionId, imageUrl: imageUrl, image: image)
            }
        }
    }

    private func uploadImage() {
        isUploading = true
        errorMessage = nil

        Task {
            do {
                let sessionId = UUID().uuidString
                logger.info("🚀 Starting upload — session: \(sessionId)")
                let response = try await uploadService.upload(image: image, sessionId: sessionId)
                logger.info("✅ Uploaded — session: \(response.sessionId), url: \(response.url)")
                uploadedSessionId = response.sessionId
                uploadedImageUrl = response.url
                showConversation = true
            } catch {
                logger.error("❌ Upload failed: \(String(describing: error))")
                errorMessage = String(localized: "upload_failed")
            }
            isUploading = false
        }
    }
}
#endif
