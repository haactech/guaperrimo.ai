//
//  ConversationView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct ConversationView: View {
    @State private var viewModel: ConversationViewModel
    @State private var pendingTranscript: String?
    @State private var isHoldingMic = false
    @Environment(\.dismiss) private var dismiss

    private let imageUrl: String
    private let image: UIImage?

    init(sessionId: String, imageUrl: String, image: UIImage? = nil, forceStyleMirror: Bool = false) {
        self.imageUrl = imageUrl
        self.image = image
        let vm = ConversationViewModel(sessionId: sessionId, imageUrl: imageUrl)
        vm.forceStyleMirror = forceStyleMirror
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if showsPhoto {
                    photoLayout
                } else {
                    Spacer()

                    mainContent

                    Spacer()
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showLookCarousel) {
            StyleMirrorView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showShoppingList) {
            ShoppingListView()
        }
        .fullScreenCover(isPresented: $viewModel.showStylePreview) {
            StylePreviewView(
                message: viewModel.currentMessage,
                direction: viewModel.direction ?? StyleDirectionDTO(brief: nil, ideas: []),
                selectedIds: viewModel.selectedIdeaIds,
                comment: $viewModel.previewComment,
                isSending: viewModel.isSendingSelection,
                errorMessage: viewModel.previewError,
                onToggle: { viewModel.toggleIdea($0) },
                onSend: {
                    viewModel.sendIdeaSelection(
                        ids: viewModel.orderedSelectedIdeaIds,
                        comment: viewModel.previewComment
                    )
                },
                onClose: { viewModel.showStylePreview = false }
            )
        }
        .onAppear {
            viewModel.startConversation()
        }
        .onChange(of: viewModel.speechService.isFinalized) { _, finalized in
            guard finalized && pendingTranscript == nil else { return }
            let transcript = viewModel.speechService.transcript
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !transcript.isEmpty {
                pendingTranscript = transcript
            }
        }
    }

    // MARK: - Photo layout

    /// The photo stays visible while the stylist talks, asks and thinks; the
    /// closing summary and errors need the whole screen.
    private var showsPhoto: Bool {
        switch viewModel.state {
        case .locationConsent, .loading, .speaking, .waitingForInput, .processing: true
        case .finished, .error: false
        }
    }

    /// The card takes ~43% of the available height; everything else scrolls
    /// only when it does not fit (small screens, long messages).
    private var photoLayout: some View {
        GeometryReader { geo in
            VStack(spacing: 16) {
                SessionPhotoCard(image: image, imageUrl: imageUrl)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.height * 0.43)

                ScrollView {
                    mainContent
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geo.size.height * 0.57 - 16 - 8)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1), in: Circle())
            }

            Spacer()

            Text("guaperrimo.ai")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Main content (state switch)

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.state {
        case .locationConsent:
            locationConsentView
                .transition(.opacity)

        case .loading:
            ThinkingIndicatorView(message: String(localized: "thinking_first"))
                .transition(.opacity)

        case .processing:
            ThinkingIndicatorView(message: String(localized: "thinking_next"))
                .transition(.opacity)

        case .speaking:
            messageText
                .transition(.opacity)

        case .waitingForInput:
            VStack(spacing: 32) {
                messageText

                inputArea
            }
            .transition(.opacity)

        case .finished:
            ScrollView {
                VStack(spacing: 16) {
                    messageText

                    LookIndicatorView(
                        lookState: viewModel.lookState,
                        readyCount: viewModel.readyLooksCount,
                        totalCount: viewModel.totalLooksCount,
                        timeoutMessage: viewModel.lookTimeoutMessage,
                        onTap: { viewModel.openLookCarousel() }
                    )

                    if !viewModel.shoppingList.isEmpty {
                        shoppingListActions
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .transition(.opacity)

        case .error(let message):
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    viewModel.retry()
                } label: {
                    Text(String(localized: "error_retry"))
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                }
            }
            .transition(.opacity)
        }
    }

    // MARK: - Location consent

    /// Shown once, before the first turn, so the system alert that follows has context.
    private var locationConsentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text(String(localized: "location_consent_title"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(String(localized: "location_consent_body"))
                .font(.body)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Button {
                    viewModel.allowLocation()
                } label: {
                    Label(String(localized: "location_allow"), systemImage: "location.fill")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                }

                Button {
                    viewModel.skipLocation()
                } label: {
                    Text(String(localized: "location_skip"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.1), in: Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    // MARK: - Shopping list

    private var shoppingListActions: some View {
        let liked = ShoppingListStore.shared.current?.liked == true
        return VStack(spacing: 10) {
            Button {
                viewModel.showShoppingList = true
            } label: {
                Label(String(localized: "shopping_view"), systemImage: "bag.fill")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: Capsule())
            }

            if liked {
                Text(String(localized: "shopping_liked"))
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else {
                Button {
                    ShoppingListStore.shared.markLiked()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Label(String(localized: "shopping_like"), systemImage: "heart.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Message text

    private var messageText: some View {
        Text(viewModel.currentMessage)
            .font(.title3)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 32)
    }

    // MARK: - Input area (buttons or mic)

    @ViewBuilder
    private var inputArea: some View {
        switch viewModel.currentInputMode {
        case .buttons:
            buttonsInput
        case .voice:
            if let errorMsg = viewModel.speechService.errorMessage {
                micErrorView(errorMsg)
            } else if let transcript = pendingTranscript {
                confirmTranscriptView(transcript)
            } else {
                micInput
            }
        case .preview:
            previewReopenButton
        case .none:
            EmptyView()
        }
    }

    // MARK: - Style preview (reopen after closing it)

    private var previewReopenButton: some View {
        Button {
            viewModel.openStylePreview()
        } label: {
            Label(String(localized: "preview_open"), systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(.white, in: Capsule())
        }
    }

    // MARK: - Pill buttons

    private var buttonsInput: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.currentOptions) { option in
                Button {
                    viewModel.selectOption(option)
                } label: {
                    Text(option.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .background(Color.white.opacity(0.15), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
                .disabled(viewModel.isSpeaking)
                .opacity(viewModel.isSpeaking ? 0.4 : 1.0)
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Push-to-talk mic

    private var micInput: some View {
        VStack(spacing: 16) {
            // Live transcript while recording
            if isHoldingMic && !viewModel.speechService.transcript.isEmpty {
                Text(viewModel.speechService.transcript)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .transition(.opacity)
            }

            // Mic button — hold to record
            ZStack {
                Circle()
                    .fill(isHoldingMic ? Color.red.opacity(0.25) : Color.white.opacity(0.12))
                    .frame(width: 80, height: 80)

                if isHoldingMic {
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 3)
                        .frame(width: 96, height: 96)
                        .transition(.scale)
                }

                Image(systemName: isHoldingMic ? "mic.fill" : "mic")
                    .font(.system(size: 30))
                    .foregroundStyle(isHoldingMic ? .red : .white)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isHoldingMic && !viewModel.isSpeaking else { return }
                        isHoldingMic = true
                        viewModel.speechService.startListening()
                    }
                    .onEnded { _ in
                        guard isHoldingMic else { return }
                        isHoldingMic = false
                        viewModel.speechService.stopListening()
                        // Don't read transcript here — STT needs time to finalize.
                        // The onChange(of: isFinalized) handler will set pendingTranscript.
                    }
            )
            .disabled(viewModel.isSpeaking)
            .opacity(viewModel.isSpeaking ? 0.4 : 1.0)

            Text(isHoldingMic
                 ? String(localized: "voice_listening")
                 : String(localized: "voice_hold_hint"))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .onAppear {
            // Mic + speech permission are requested when the user is about to speak,
            // not at session start, so the alerts arrive with context.
            viewModel.speechService.requestAuthorization()
        }
    }

    // MARK: - Confirm transcript

    private func confirmTranscriptView(_ transcript: String) -> some View {
        VStack(spacing: 20) {
            Text(transcript)
                .font(.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

            HStack(spacing: 16) {
                // Retry button
                Button {
                    pendingTranscript = nil
                } label: {
                    Label(String(localized: "voice_retry"), systemImage: "arrow.counterclockwise")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .background(Color.white.opacity(0.15), in: Capsule())
                }

                // Send button
                Button {
                    let text = transcript
                    pendingTranscript = nil
                    viewModel.sendVoiceResponse(text)
                } label: {
                    Label(String(localized: "voice_send"), systemImage: "paperplane.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(minHeight: 44)
                        .background(.white, in: Capsule())
                }
            }
        }
    }

    // MARK: - Mic error (permission denied)

    private func micErrorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)

            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label(String(localized: "open_settings"), systemImage: "gear")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .frame(minHeight: 44)
                    .background(.white, in: Capsule())
            }
        }
    }
}
#endif
