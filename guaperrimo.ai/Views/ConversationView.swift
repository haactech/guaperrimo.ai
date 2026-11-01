//
//  ConversationView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct ConversationView: View {
    @State private var viewModel: ConversationViewModel
    @State private var pendingTranscript: String?
    @State private var voiceHeardNothing = false
    @State private var showLeaveConfirm = false
    @State private var showHistory = false
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
            MyLooksView()
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
                onNone: {
                    viewModel.sendIdeaSelection(
                        ids: [],
                        comment: String(localized: "preview_none_comment")
                    )
                },
                onClose: { viewModel.closeStylePreview() }
            )
        }
        .sheet(isPresented: $showHistory) {
            ConversationHistoryView(entries: viewModel.history)
        }
        .confirmationDialog(String(localized: "leave_title"), isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button(String(localized: "leave_confirm"), role: .destructive) { dismiss() }
            Button(String(localized: "leave_cancel"), role: .cancel) {}
        }
        .onAppear {
            viewModel.startConversation()
        }
        .onChange(of: viewModel.speechService.isFinalized) { _, finalized in
            guard finalized && pendingTranscript == nil else { return }
            let transcript = viewModel.speechService.transcript
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if transcript.isEmpty {
                voiceHeardNothing = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            } else {
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

    /// Leaving mid-turn throws away the analysis in progress, so ask first.
    private var needsLeaveConfirmation: Bool {
        switch viewModel.state {
        case .loading, .processing, .speaking: true
        default: false
        }
    }

    private var header: some View {
        HStack {
            IconButton(systemName: "xmark", accessibilityLabel: String(localized: "preview_close")) {
                if needsLeaveConfirmation {
                    showLeaveConfirm = true
                } else {
                    dismiss()
                }
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
            ThinkingIndicatorView(message: viewModel.progressText ?? String(localized: "thinking_first"))
                .transition(.opacity)

        case .processing:
            ThinkingIndicatorView(message: viewModel.progressText ?? String(localized: "thinking_next"))
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
            VStack(spacing: DS.Space.s) {
                if hasCanvas {
                    canvasContent(isInteractive: !viewModel.isSpeaking)
                } else {
                    VStack(spacing: 32) {
                        messageText

                        inputArea
                    }
                }

                if viewModel.history.count >= 2 {
                    TertiaryButton(title: String(localized: "history_open")) { showHistory = true }
                }
            }
            .transition(.opacity)

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
        PrimaryButton(title: String(localized: "shopping_view"), systemImage: "heart.fill", style: .light) {
            viewModel.showShoppingList = true
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
        VStack(spacing: 8) {
            // A failed send must not be silent once the preview is closed.
            if let error = viewModel.previewError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(DS.warning)
                    .multilineTextAlignment(.center)
            }
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

    // MARK: - Tap-to-talk mic

    private var micInput: some View {
        let isListening = viewModel.speechService.isListening
        return VStack(spacing: 16) {
            // Live transcript while recording
            if isListening && !viewModel.speechService.transcript.isEmpty {
                Text(viewModel.speechService.transcript)
                    .font(.body)
                    .foregroundStyle(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .transition(.opacity)
            }

            // Tap to start, tap again to stop
            Button {
                toggleMic()
            } label: {
                ZStack {
                    Circle()
                        .fill(isListening ? Color.red.opacity(0.25) : Color.white.opacity(0.12))
                        .frame(width: 80, height: 80)

                    if isListening {
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 3)
                            .frame(width: 96, height: 96)
                            .transition(.scale)
                    }

                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.title)
                        .foregroundStyle(isListening ? .red : .white)
                }
                .frame(width: 100, height: 100)
                .contentShape(Circle())
            }
            .accessibilityLabel(String(localized: isListening ? "voice_tap_stop" : "voice_tap_hint"))
            .disabled(viewModel.isSpeaking)
            .opacity(viewModel.isSpeaking ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isListening)

            Text(micCaption(isListening: isListening))
                .font(.caption)
                .foregroundStyle(voiceHeardNothing && !isListening ? DS.warning : DS.textTertiary)
        }
        .onAppear {
            // Mic + speech permission are requested when the user is about to speak,
            // not at session start, so the alerts arrive with context.
            viewModel.speechService.requestAuthorization()
        }
    }

    private func micCaption(isListening: Bool) -> String {
        if isListening { return String(localized: "voice_tap_stop") }
        if voiceHeardNothing { return String(localized: "voice_empty") }
        return String(localized: "voice_tap_hint")
    }

    private func toggleMic() {
        let speech = viewModel.speechService
        if speech.isListening {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            speech.stopListening()
            // Don't read the transcript here — STT needs time to finalize.
            // The onChange(of: isFinalized) handler decides what happens next.
        } else if !viewModel.isSpeaking {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            voiceHeardNothing = false
            speech.startListening()
        }
    }

    // MARK: - Confirm transcript

    private func confirmTranscriptView(_ transcript: String) -> some View {
        VoiceConfirmView(
            transcript: transcript,
            onSend: {
                pendingTranscript = nil
                viewModel.sendVoiceResponse(transcript)
            },
            onRepeat: { pendingTranscript = nil }
        )
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
