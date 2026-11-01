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
            TexturedBackground()

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
                UserPhotoCard(image: image, url: imageUrl)
                    .overlay(alignment: .bottom) {
                        if viewModel.isSpeaking {
                            SpeakingPillView { viewModel.skipSpeaking() }
                                .padding(.bottom, 12)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isSpeaking)
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
            IconButton(systemName: "xmark", accessibilityLabel: String(localized: "preview_close")) {
                dismiss()
            }

            Spacer()

            VStack(spacing: 4) {
                Text(String(localized: "session_title"))
                    .font(.headline)
                    .foregroundStyle(.white)

                if let label = viewModel.locationService.fix?.label {
                    Label(label, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(DS.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HeaderSpacer()
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.top, DS.Space.xs)
        .padding(.bottom, DS.Space.s)
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
            if hasCanvas {
                canvasContent(isInteractive: false)
                    .transition(.opacity)
            } else {
                messageText
                    .transition(.opacity)
            }

        case .waitingForInput:
            if hasCanvas {
                canvasContent(isInteractive: !viewModel.isSpeaking)
                    .transition(.opacity)
            } else {
                VStack(spacing: 32) {
                    messageText

                    inputArea
                }
                .transition(.opacity)
            }

        case .finished:
            ScrollView {
                VStack(spacing: 16) {
                    if hasCanvas {
                        GenerativeCanvas(components: viewModel.currentUI, isInteractive: false)
                    } else {
                        messageText
                    }

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
                    .font(.largeTitle)
                    .foregroundStyle(DS.warning)

                Text(message)
                    .font(.body)
                    .foregroundStyle(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                PrimaryButton(title: String(localized: "error_retry")) {
                    viewModel.retry()
                }
                .padding(.horizontal, DS.Space.l)
            }
            .transition(.opacity)
        }
    }

    // MARK: - Generative canvas

    private var hasCanvas: Bool { !viewModel.currentUI.isEmpty }

    /// The server composed this turn: render its components instead of message + options.
    /// The mic stays available below them when the turn takes voice.
    private func canvasContent(isInteractive: Bool) -> some View {
        VStack(spacing: DS.Space.l) {
            GenerativeCanvas(
                components: viewModel.currentUI,
                isInteractive: isInteractive,
                onChip: { id, label in viewModel.selectOption(ChatOption(id: id, label: label)) },
                onSliderConfirm: { id, value in viewModel.sendUIAction(componentId: id, value: value) }
            )
            .padding(.horizontal, DS.Space.l)

            if isInteractive && canvasTakesVoice {
                voiceArea
            }
        }
    }

    private var canvasTakesVoice: Bool {
        viewModel.currentInputMode == .voice || viewModel.currentUI.contains(where: \.isChipsWithVoice)
    }

    @ViewBuilder
    private var voiceArea: some View {
        if let errorMsg = viewModel.speechService.errorMessage {
            micErrorView(errorMsg)
        } else if let transcript = pendingTranscript {
            confirmTranscriptView(transcript)
        } else {
            micInput
        }
    }

    // MARK: - Location consent

    /// Shown once, before the first turn, so the system alert that follows has context.
    private var locationConsentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "mappin.and.ellipse")
                .font(.largeTitle)
                .foregroundStyle(DS.success)

            Text(String(localized: "location_consent_title"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(String(localized: "location_consent_body"))
                .font(.body)
                .foregroundStyle(DS.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: DS.Space.s) {
                PrimaryButton(title: String(localized: "location_allow"), systemImage: "location.fill") {
                    viewModel.allowLocation()
                }

                SecondaryButton(title: String(localized: "location_skip"), fullWidth: true) {
                    viewModel.skipLocation()
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
            PrimaryButton(title: String(localized: "shopping_view"), systemImage: "bag.fill", style: .light) {
                viewModel.showShoppingList = true
            }

            if liked {
                Text(String(localized: "shopping_liked"))
                    .font(.subheadline)
                    .foregroundStyle(DS.success)
            } else {
                SecondaryButton(title: String(localized: "shopping_like"), systemImage: "heart.fill") {
                    ShoppingListStore.shared.markLiked()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
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
        case .none, .ui:
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
                    Chip(label: option.label)
                        .frame(minHeight: DS.minTap)
                        .contentShape(Capsule())
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
                    .foregroundStyle(DS.textSecondary)
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
                    .font(.title)
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
                .foregroundStyle(DS.textTertiary)
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
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.m))
                .padding(.horizontal, 24)

            HStack(spacing: 16) {
                // Retry button
                SecondaryButton(title: String(localized: "voice_retry"), systemImage: "arrow.counterclockwise") {
                    pendingTranscript = nil
                }

                // Send button
                PrimaryButton(title: String(localized: "voice_send"), systemImage: "paperplane.fill", style: .light) {
                    let text = transcript
                    pendingTranscript = nil
                    viewModel.sendVoiceResponse(text)
                }
            }
        }
    }

    // MARK: - Mic error (permission denied)

    private func micErrorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash.fill")
                .font(.largeTitle)
                .foregroundStyle(DS.warning)

            Text(message)
                .font(.body)
                .foregroundStyle(DS.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            PrimaryButton(title: String(localized: "open_settings"), systemImage: "gear", style: .light) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .padding(.horizontal, DS.Space.l)
        }
    }
}
#endif
