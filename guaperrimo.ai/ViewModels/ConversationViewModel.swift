//
//  ConversationViewModel.swift
//  guaperrimo.ai
//

#if os(iOS)
import OSLog

private let logger = Logger(subsystem: "ai.guaperrimo", category: "Conversation")

enum ConversationState: Equatable {
    case loading          // POST /chat in progress
    case speaking         // TTS playing
    case waitingForInput  // TTS done, show buttons or mic
    case processing       // User responded, waiting for server
    case finished         // is_final=true, show results
    case error(String)    // Error
}

@Observable
@MainActor
final class ConversationViewModel {
    var state: ConversationState = .loading
    var currentMessage: String = ""
    var currentOptions: [ChatOption] = []
    var currentInputMode: InputMode = .none
    var priorityActions: [PriorityAction] = []
    var isSpeaking: Bool = false

    let speechService = SpeechRecognitionService()
    private let stylistService: StylistService
    private let ttsService: TTSService
    private let sessionId: String
    private let imageUrl: String

    init(
        sessionId: String,
        imageUrl: String,
        stylistService: StylistService = LiveStylistService(),
        ttsService: TTSService = ElevenLabsTTSService()
    ) {
        self.sessionId = sessionId
        self.imageUrl = imageUrl
        self.stylistService = stylistService
        self.ttsService = ttsService
    }

    func startConversation() {
        let request = ChatRequest(type: "image", imageUrl: imageUrl, optionId: nil, transcript: nil)
        sendRequest(request)
    }

    func selectOption(_ option: ChatOption) {
        state = .processing
        let request = ChatRequest(type: "button_response", imageUrl: nil, optionId: option.id, transcript: nil)
        sendRequest(request)
    }

    func sendVoiceResponse(_ transcript: String) {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        state = .processing
        let request = ChatRequest(type: "voice_response", imageUrl: nil, optionId: nil, transcript: transcript)
        sendRequest(request)
    }

    func retry() {
        startConversation()
    }

    private func sendRequest(_ request: ChatRequest) {
        if state != .processing {
            state = .loading
        }
        ttsService.stop()

        Task {
            do {
                let response = try await stylistService.chat(sessionId: sessionId, request: request)
                await handleResponse(response)
            } catch {
                logger.error("Chat failed: \(error.localizedDescription)")
                state = .error(String(localized: "error_generic"))
            }
        }
    }

    private func handleResponse(_ response: ChatResponse) async {
        logger.info("Handling response — phase: \(response.phase), turn: \(response.turn), isFinal: \(response.isFinal)")

        currentMessage = response.message
        currentOptions = response.options ?? []
        currentInputMode = response.inputMode
        priorityActions = response.priorityActions ?? []

        // Speak the message
        state = .speaking
        isSpeaking = true
        await ttsService.speak(response.message)
        isSpeaking = false

        // Brief pause after TTS
        try? await Task.sleep(for: .milliseconds(300))

        // Transition to final state
        if response.isFinal {
            state = .finished
        } else {
            state = .waitingForInput
        }
    }
}
#endif
