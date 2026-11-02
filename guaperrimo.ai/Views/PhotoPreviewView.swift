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
            DS.bg.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .ignoresSafeArea()

            VStack {
                Spacer()

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(DS.textPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(DS.danger.opacity(0.25), in: RoundedRectangle(cornerRadius: DS.Radius.m))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .scale))
                }

                HStack(spacing: DS.Space.s) {
                    SecondaryButton(title: String(localized: "retake"), systemImage: "arrow.counterclockwise") {
                        onRetake()
                    }
                    .disabled(isUploading)

                    if isUploading {
                        ProgressView()
                            .tint(DS.onAccent)
                            .frame(maxWidth: .infinity, minHeight: DS.minTap)
                            .background(DS.accent, in: RoundedRectangle(cornerRadius: DS.Radius.button))
                    } else {
                        PrimaryButton(
                            title: hasUploaded ? String(localized: "continue_session") : String(localized: "analyze_outfit"),
                            systemImage: hasUploaded ? "arrow.right.circle.fill" : "sparkles"
                        ) {
                            if hasUploaded {
                                showConversation = true
                            } else {
                                uploadImage()
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Space.l)
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
