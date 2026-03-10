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

    init(sessionId: String, imageUrl: String) {
        _viewModel = State(initialValue: ConversationViewModel(sessionId: sessionId, imageUrl: imageUrl))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer()

                mainContent

                Spacer()
            }
        }
        .onAppear {
            viewModel.speechService.requestAuthorization()
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
        case .loading, .processing:
            VStack(spacing: 20) {
                ThinkingIndicatorView()
            }
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

                    if !viewModel.priorityActions.isEmpty {
                        ForEach(viewModel.priorityActions) { action in
                            PriorityActionCardView(action: action)
                        }
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

    // MARK: - Message text

    private var messageText: some View {
        Text(viewModel.currentMessage)
            .font(.title3)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
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
        case .none:
            EmptyView()
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
