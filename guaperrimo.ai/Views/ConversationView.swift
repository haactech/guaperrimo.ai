//
//  ConversationView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct ConversationView: View {
    @State private var viewModel: ConversationViewModel
    @State private var inputText = ""
    @Environment(\.dismiss) private var dismiss

    init(sessionId: String) {
        _viewModel = State(initialValue: ConversationViewModel(sessionId: sessionId))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
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

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(message: message) { option in
                                    viewModel.selectOption(option)
                                }
                                .id(message.id)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            if viewModel.isThinking {
                                ThinkingIndicatorView()
                                    .id("thinking")
                                    .transition(.opacity)
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.messages.count) {
                        withAnimation {
                            if let lastId = viewModel.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.isThinking) { _, isThinking in
                        if isThinking {
                            withAnimation {
                                proxy.scrollTo("thinking", anchor: .bottom)
                            }
                        }
                    }
                }

                // Input bar
                ConversationInputBar(
                    text: $inputText,
                    isListening: viewModel.speechService.isListening,
                    onSend: {
                        let text = inputText
                        inputText = ""
                        viewModel.sendMessage(text)
                    },
                    onMicTap: {
                        handleMicTap()
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.messages.count)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isThinking)
        .onAppear {
            viewModel.speechService.requestAuthorization()
            viewModel.startAnalysis()
        }
    }

    private func handleMicTap() {
        if viewModel.speechService.isListening {
            viewModel.speechService.stopListening()
            let transcript = viewModel.speechService.transcript
            if !transcript.isEmpty {
                inputText = transcript
            }
        } else {
            viewModel.speechService.startListening()
        }
    }
}
#endif
