//
//  ConversationViewModel.swift
//  guaperrimo.ai
//

#if os(iOS)
import OSLog
import UIKit

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

    // Shopping list (final turn)
    var shoppingList: [ShoppingItemDTO] = []
    var stores: [StoreDTO] = []
    var totalMxn: Double = 0
    var listSaved: Bool = false
    var showShoppingList: Bool = false

    // Try-on overlay state
    var tryOnState: TryOnState = .idle
    var showTryOn: Bool = false
    var userImageUrl: String { imageUrl }

    // Look carousel state
    var lookState: LookCarouselState = .hidden
    var lookItems: [LookItem] = []
    var currentLookIndex: Int = 0
    var showLookCarousel: Bool = false
    var showComparison: Bool = false
    var showPieceDetail: Bool = false
    var lookTimeoutMessage: String? = nil

    var mirrorItems: [StyleMirrorItem] {
        let readyLooks = lookItems.filter { $0.status == "ready" }
        return [.original(imageUrl: imageUrl)] + readyLooks.map { .look($0) }
    }

    var currentLook: LookItem? {
        let items = mirrorItems
        guard items.indices.contains(currentLookIndex) else { return nil }
        if case .look(let item) = items[currentLookIndex] {
            return item
        }
        return nil
    }
    var readyLooksCount: Int { lookItems.filter { $0.status == "ready" }.count }
    var totalLooksCount: Int { lookItems.count }

    /// DEBUG: Set to `true` to skip the conversation and open the Style Mirror immediately with stub looks.
    var forceStyleMirror: Bool = false

    let speechService = SpeechRecognitionService()
    private let stylistService: StylistService
    private let ttsService: TTSService
    private let sessionId: String
    private let imageUrl: String
    private var tryOnTask: Task<Void, Never>?
    private var lookPollingTask: Task<Void, Never>?
    private var lookAutoOpenTask: Task<Void, Never>?
    private var pollingElapsed: TimeInterval = 0

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
        if forceStyleMirror {
            bootstrapStyleMirror()
            return
        }
        let request = ChatRequest(type: "image", imageUrl: imageUrl, optionId: nil, transcript: nil)
        sendRequest(request)
    }

    /// Skip conversation and open the Style Mirror immediately with stub looks (DEBUG).
    /// Uses the real user imageUrl as the original photo; look images come from picsum.
    private func bootstrapStyleMirror() {
        state = .finished
        currentMessage = ""

        lookItems = [
            LookItem(
                id: "look_1", name: "Casual Elevado",
                description: "Look urbano con equilibrio entre comodidad y estilo",
                vibe: "casual elevado", status: "ready",
                finalImageUrl: "https://picsum.photos/400/600?random=10",
                errorMessage: nil,
                pieces: [
                    LookPieceItem(slot: "upper_body", slotDescription: "Camisa de lino azul marino", category: "upper_body",
                                  productId: "p1", productName: "Blue Linen Shirt",
                                  productImageUrl: "https://picsum.photos/72/72?random=10", tryonImageUrl: nil),
                    LookPieceItem(slot: "lower_body", slotDescription: "Pantalon chino slim beige", category: "lower_body",
                                  productId: "p2", productName: "Beige Chino Pants",
                                  productImageUrl: "https://picsum.photos/72/72?random=11", tryonImageUrl: nil)
                ]
            ),
            LookItem(
                id: "look_2", name: "Smart Casual",
                description: "Combinacion inteligente para versatilidad",
                vibe: "smart casual", status: "ready",
                finalImageUrl: "https://picsum.photos/400/600?random=20",
                errorMessage: nil,
                pieces: [
                    LookPieceItem(slot: "upper_body", slotDescription: "Polo de punto gris", category: "upper_body",
                                  productId: "p3", productName: "Grey Knit Polo",
                                  productImageUrl: "https://picsum.photos/72/72?random=20", tryonImageUrl: nil),
                    LookPieceItem(slot: "lower_body", slotDescription: "Pantalon de vestir azul", category: "lower_body",
                                  productId: "p4", productName: "Blue Dress Pants",
                                  productImageUrl: "https://picsum.photos/72/72?random=21", tryonImageUrl: nil)
                ]
            ),
            LookItem(
                id: "look_3", name: "Urbano Moderno",
                description: "Look relajado con sneakers premium",
                vibe: "urbano moderno", status: "ready",
                finalImageUrl: "https://picsum.photos/400/600?random=30",
                errorMessage: nil,
                pieces: [
                    LookPieceItem(slot: "upper_body", slotDescription: "Overshirt de franela verde", category: "upper_body",
                                  productId: "p5", productName: "Green Flannel Overshirt",
                                  productImageUrl: "https://picsum.photos/72/72?random=30", tryonImageUrl: nil),
                    LookPieceItem(slot: "lower_body", slotDescription: "Jeans slim negro", category: "lower_body",
                                  productId: "p6", productName: "Black Slim Jeans",
                                  productImageUrl: "https://picsum.photos/72/72?random=31", tryonImageUrl: nil)
                ]
            )
        ]

        openLookCarousel()
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
                logger.error("Chat failed: \(String(describing: error), privacy: .public)")
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
        shoppingList = response.shoppingList ?? []
        stores = response.stores ?? []
        totalMxn = response.totalMxn ?? 0
        listSaved = false

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
            if response.looksGenerating == true {
                startLookPolling()
            }
        } else {
            state = .waitingForInput
        }
    }

    // MARK: - Shopping list

    /// Keeps the recommended products on the device as the user's shopping reference.
    func saveShoppingList() {
        guard !shoppingList.isEmpty else { return }
        let list = SavedShoppingList(
            sessionId: sessionId,
            savedAt: Date(),
            summary: currentMessage,
            items: shoppingList,
            stores: stores,
            totalMxn: totalMxn,
            purchased: []
        )
        ShoppingListStore.shared.save(list)
        listSaved = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Try-on

    func requestTryOn(for action: PriorityAction) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        tryOnState = .loading(action)
        showTryOn = true

        tryOnTask?.cancel()
        tryOnTask = Task {
            do {
                let request = TryOnRequest(actionId: action.id, garmentDescription: action.description)
                let response = try await stylistService.tryOn(sessionId: sessionId, request: request)
                guard !Task.isCancelled else { return }
                guard let url = URL(string: response.tryonImageUrl) else {
                    tryOnState = .error(action, String(localized: "error_generic"))
                    return
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                tryOnState = .result(action, url)
            } catch is CancellationError {
                // Cancelled — do nothing
            } catch {
                guard !Task.isCancelled else { return }
                logger.error("TryOn failed: \(String(describing: error), privacy: .public)")
                tryOnState = .error(action, String(localized: "error_generic"))
            }
        }
    }

    func retryTryOn() {
        if case .error(let action, _) = tryOnState {
            requestTryOn(for: action)
        }
    }

    func dismissTryOn() {
        tryOnTask?.cancel()
        tryOnTask = nil
        tryOnState = .idle
        showTryOn = false
    }

    // MARK: - Looks

    func startLookPolling() {
        guard lookPollingTask == nil else { return }
        lookState = .teaser
        pollingElapsed = 0

        lookPollingTask = Task {
            var interval: Duration = .seconds(4)

            while !Task.isCancelled {
                do {
                    let response = try await stylistService.fetchLooks(sessionId: sessionId)
                    guard !Task.isCancelled else { return }

                    lookItems = Self.mergeLooks(response)
                    interval = .seconds(4)

                    let hasReady = response.lookResults.contains { $0.status == "ready" }
                    let allFailed = response.lookResults.allSatisfy { $0.status == "failed" }

                    if allFailed {
                        lookState = .hidden
                        stopLookPolling()
                        return
                    }

                    if hasReady && lookState == .teaser {
                        lookState = .ready
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        scheduleAutoOpen()
                    }

                    if response.allReady {
                        logger.info("All looks finished — allReady: true")
                        stopLookPolling()
                        return
                    }
                } catch is CancellationError {
                    return
                } catch {
                    logger.error("Look polling error: \(String(describing: error), privacy: .public)")
                    interval = .seconds(8)
                }

                pollingElapsed += Double(interval.components.seconds)

                // Timeout messages
                if pollingElapsed >= 60 {
                    lookTimeoutMessage = String(localized: "looks_timeout_retry")
                } else if pollingElapsed >= 30 {
                    lookTimeoutMessage = String(localized: "looks_timeout_slow")
                }

                try? await Task.sleep(for: interval)
            }
        }
    }

    func stopLookPolling() {
        lookPollingTask?.cancel()
        lookPollingTask = nil
    }

    /// Merge looks[] (LLM metadata) + lookResults[] (VTON results) into a single array for the UI.
    private static func mergeLooks(_ response: LooksResponse) -> [LookItem] {
        let resultsById = Dictionary(uniqueKeysWithValues: response.lookResults.map { ($0.lookId, $0) })

        return response.looks.map { look in
            let result = resultsById[look.id]
            let status = result?.status ?? "pending"

            // Merge piece info: LookDTO has slot descriptions, LookResultDTO has product info
            let piecesById = Dictionary(uniqueKeysWithValues: (result?.pieces ?? []).map { ($0.slot, $0) })
            let mergedPieces = look.pieces.map { lookPiece in
                let resultPiece = piecesById[lookPiece.slot]
                return LookPieceItem(
                    slot: lookPiece.slot,
                    slotDescription: lookPiece.description,
                    category: lookPiece.category,
                    productId: resultPiece?.productId,
                    productName: resultPiece?.productName,
                    productImageUrl: resultPiece?.productImageUrl,
                    tryonImageUrl: resultPiece?.tryonImageUrl
                )
            }

            return LookItem(
                id: look.id,
                name: look.name,
                description: look.description,
                vibe: look.vibe,
                status: status,
                finalImageUrl: result?.finalImageUrl,
                errorMessage: result?.errorMessage,
                pieces: mergedPieces
            )
        }
    }

    private func scheduleAutoOpen() {
        lookAutoOpenTask?.cancel()
        lookAutoOpenTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            if !showLookCarousel && !showTryOn {
                openLookCarousel()
            }
        }
    }

    func openLookCarousel() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        lookAutoOpenTask?.cancel()
        currentLookIndex = 0
        lookState = .viewing
        showLookCarousel = true
    }

    func closeLookCarousel() {
        showLookCarousel = false
        showComparison = false
        showPieceDetail = false
        if lookItems.contains(where: { $0.status == "generating" || $0.status == "pending" }) {
            lookState = .teaser
        } else {
            lookState = .ready
        }
    }

    func retryLook(at index: Int) {
        // Re-trigger polling if stopped
        if lookPollingTask == nil {
            startLookPolling()
        }
    }
}
#endif
