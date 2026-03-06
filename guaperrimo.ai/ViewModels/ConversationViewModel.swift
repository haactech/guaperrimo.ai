//
//  ConversationViewModel.swift
//  guaperrimo.ai
//

#if os(iOS)
import OSLog

private let logger = Logger(subsystem: "ai.guaperrimo", category: "Conversation")

@Observable
@MainActor
final class ConversationViewModel {
    var messages: [ConversationMessage] = []
    var isThinking = false

    let speechService = SpeechRecognitionService()
    private let stylistService: StylistService
    private let ttsService: TTSService
    private let sessionId: String

    init(sessionId: String, stylistService: StylistService = LiveStylistService(), ttsService: TTSService = ElevenLabsTTSService()) {
        self.sessionId = sessionId
        self.stylistService = stylistService
        self.ttsService = ttsService
    }

    func startAnalysis() {
        guard messages.isEmpty else { return }
        isThinking = true

        Task {
            do {
                let analysis = try await stylistService.analyzePhoto(sessionId: sessionId)
                isThinking = false
                logger.info("Stylist analysis received")

                // Step 1: Show the detailed analysis (what the stylist sees)
                if let analysisText = analysis.analysis, !analysisText.isEmpty {
                    let analysisMessage = ConversationMessage(role: .stylist, text: analysisText)
                    messages.append(analysisMessage)
                    await ttsService.speak(analysisText)
                }

                // Step 2: Show the summary with style options
                let options = analysis.options.map { StyleOption(id: $0.id, title: $0.title, description: $0.description) }
                let optionsMessage = ConversationMessage(role: .stylist, text: analysis.message, options: options)
                messages.append(optionsMessage)

                // Speak the message (if analysis was already spoken, speak the summary; otherwise speak the message)
                await ttsService.speak(analysis.message)
            } catch {
                logger.error("Analysis failed: \(error.localizedDescription)")
                isThinking = false
                let errorMsg = ConversationMessage(role: .stylist, text: "Sorry, I couldn't analyze your photo right now. Please try again.")
                messages.append(errorMsg)
            }
        }
    }

    func selectOption(_ option: StyleOption) {
        let userMessage = ConversationMessage(role: .user, text: option.title)
        messages.append(userMessage)
        continueConversation(userText: option.title)
    }

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let userMessage = ConversationMessage(role: .user, text: trimmed)
        messages.append(userMessage)
        continueConversation(userText: trimmed)
    }

    private func continueConversation(userText: String) {
        isThinking = true
        ttsService.stop()

        Task {
            do {
                let analysis = try await stylistService.sendMessage(sessionId: sessionId, userMessage: userText)
                let options = analysis.options.map { StyleOption(id: $0.id, title: $0.title, description: $0.description) }
                let message = ConversationMessage(role: .stylist, text: analysis.message, options: options)
                messages.append(message)
                isThinking = false
                logger.info("Stylist response received")
                await ttsService.speak(analysis.message)
            } catch {
                logger.error("Conversation failed: \(error.localizedDescription)")
                isThinking = false
                let errorMsg = ConversationMessage(role: .stylist, text: "I lost my train of thought. Could you say that again?")
                messages.append(errorMsg)
            }
        }
    }
}
#endif
