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
    case locationConsent  // explain why we want the device location, before the first turn
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
    /// Generative UI components of the current turn; empty means the legacy message + options layout.
    var currentUI: [UIComponent] = []
    var isSpeaking: Bool = false
    /// What the stylist is doing right now (from the stream); nil falls back to the generic text.
    var progressText: String? = nil
    /// Everything said so far, oldest first (stylist messages and the user's answers).
    var history: [ConversationEntry] = []

    // Shopping list (final turn)
    var shoppingList: [ShoppingItemDTO] = []
    var stores: [StoreDTO] = []
    var totalMxn: Double = 0
    var listSaved: Bool = false
    var showShoppingList: Bool = false
    var showShoppingListInMirror: Bool = false // the mirror is a full-screen cover, so it owns its own sheet

    // Style preview (input_mode "preview"): brief + garment ideas the user picks from
    var direction: StyleDirectionDTO? = nil
    var selectedIdeaIds: Set<String> = []
    var previewComment: String = ""
    var showStylePreview: Bool = false
    var isSendingSelection: Bool = false
    var previewError: String? = nil

    /// Selected ids in the order the stylist proposed them.
    var orderedSelectedIdeaIds: [String] {
        (direction?.ideas ?? []).map(\.id).filter { selectedIdeaIds.contains($0) }
    }

    var canSendIdeaSelection: Bool {
        !isSendingSelection
            && (!selectedIdeaIds.isEmpty || !previewComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // Try-on overlay state
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
    let locationService = LocationService()
    private let stylistService: StylistService
    private let ttsService: TTSService
    private let sessionId: String
    private let imageUrl: String
    private var lookPollingTask: Task<Void, Never>?
    private var lookAutoOpenTask: Task<Void, Never>?
    private var pollingElapsed: TimeInterval = 0
    /// The last request sent, kept so `retry()` repeats it instead of restarting the session.
    private var lastRequest: ChatRequest?

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
        if locationService.canAsk {
            state = .locationConsent
            return
        }
        beginSession()
    }

    /// Takes a quick device fix when permission was already granted, then opens the session.
    private func beginSession() {
        Task {
            if locationService.isAuthorized {
                _ = await locationService.requestFix()
            }
            sendFirstTurn()
        }
    }

    private func sendFirstTurn() {
        sendRequest(ChatRequest(type: "image", imageUrl: imageUrl, optionId: nil, transcript: nil))
    }

    // MARK: - Location consent

    /// The user agreed on our screen; the system alert follows and we wait (briefly) for a fix.
    func allowLocation() {
        state = .loading
        Task {
            _ = await locationService.requestFix()
            sendFirstTurn()
        }
    }

    /// Cuts the stylist's voice short. `speak` returns once TTS stops, and
    /// `handleResponse` then moves on to the next state on its own.
    func skipSpeaking() {
        ttsService.stop()
    }

    /// Without a device location the server asks for the area in the conversation.
    func skipLocation() {
        sendFirstTurn()
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
        history.append(ConversationEntry(role: .user, text: option.label))
        let request = ChatRequest(type: "button_response", imageUrl: nil, optionId: option.id, transcript: nil)
        sendRequest(request)
    }

    /// Answers a generative UI component that needs an explicit confirm (the slider).
    /// Chips are answered through `selectOption`, the existing button path.
    func sendUIAction(componentId: String, value: String) {
        state = .processing
        let answer = componentId == "budget"
            ? String(format: String(localized: "history_budget"), value)
            : "\(componentId): \(value)"
        history.append(ConversationEntry(role: .user, text: answer))
        let request = ChatRequest(
            type: "ui_action", imageUrl: nil, optionId: nil, transcript: nil,
            componentId: componentId, value: value
        )
        sendRequest(request)
    }

    func sendVoiceResponse(_ transcript: String) {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        state = .processing
        history.append(ConversationEntry(role: .user, text: transcript.trimmingCharacters(in: .whitespacesAndNewlines)))
        let request = ChatRequest(type: "voice_response", imageUrl: nil, optionId: nil, transcript: transcript)
        sendRequest(request)
    }

    // MARK: - Style preview

    func toggleIdea(_ id: String) {
        guard !isSendingSelection else { return }
        if selectedIdeaIds.contains(id) {
            selectedIdeaIds.remove(id)
        } else {
            selectedIdeaIds.insert(id)
        }
    }

    func openStylePreview() {
        guard direction != nil else { return }
        showStylePreview = true
    }

    /// Closes the preview and silences the stylist's voice, which would
    /// otherwise keep reading the message of a screen that is gone.
    func closeStylePreview() {
        showStylePreview = false
        skipSpeaking()
    }

    /// Sends the ideas the user liked (and/or a comment) as an `idea_selection` turn.
    /// The response is a normal chat turn handled by `handleResponse`.
    func sendIdeaSelection(ids: [String], comment: String) {
        let text = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ids.isEmpty || !text.isEmpty, !isSendingSelection else { return }

        let rejected = (direction?.ideas ?? []).map(\.id).filter { !ids.contains($0) }
        logger.info("Idea selection — round: \(self.direction?.round ?? 0, privacy: .public), selected: \(ids.joined(separator: ","), privacy: .public), rejected: \(rejected.joined(separator: ","), privacy: .public), comment: \(!text.isEmpty, privacy: .public)")

        isSendingSelection = true
        previewError = nil
        state = .processing
        var answer = ids.isEmpty ? "" : String(format: String(localized: "history_ideas"), ids.count)
        if !text.isEmpty { answer += (answer.isEmpty ? "" : "\n") + text }
        history.append(ConversationEntry(role: .user, text: answer))
        let request = ChatRequest(
            type: "idea_selection", imageUrl: nil, optionId: nil, transcript: nil,
            selectedIdeas: ids.isEmpty ? nil : ids,
            text: text.isEmpty ? nil : text
        )
        sendRequest(request)
    }

    /// Re-sends the request that failed (not a new image turn); a first-turn failure
    /// before any request existed restarts the conversation.
    func retry() {
        guard let request = lastRequest else {
            startConversation()
            return
        }
        state = request.type == "image" ? .loading : .processing
        sendRequest(request)
    }

    /// Maps a transport or server failure to a specific, actionable message.
    static func errorMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return String(localized: "error_timeout")
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                return String(localized: "error_offline")
            default:
                break
            }
        }
        if case APIError.serverError(let status, _) = error {
            if status == 504 { return String(localized: "error_timeout") }
            if (500...599).contains(status) { return String(localized: "error_server") }
        }
        return String(localized: "error_generic")
    }

    private func sendRequest(_ request: ChatRequest) {
        var request = request
        // Every turn carries the device location (when granted) so the server
        // knows where to look for stores and never has to ask.
        request.location = locationService.fix
        lastRequest = request
        if state != .processing {
            state = .loading
        }
        ttsService.stop()

        Task {
            do {
                let response = try await stylistService.chatStream(sessionId: sessionId, request: request) { [weak self] progress in
                    Task { @MainActor in self?.progressText = Self.progressText(for: progress) }
                }
                await handleResponse(response)
            } catch {
                logger.error("Chat failed: \(String(describing: error), privacy: .public)")
                progressText = nil
                if isSendingSelection {
                    // Keep the preview open so the user can retry without losing his picks.
                    isSendingSelection = false
                    previewError = String(localized: "preview_send_error")
                    state = .waitingForInput
                } else {
                    state = .error(Self.errorMessage(for: error))
                }
            }
        }
    }

    /// Spanish line for a stream stage; unknown stages keep the generic text.
    static func progressText(for progress: ChatProgress) -> String? {
        switch progress.stage {
        case "analyzing_photo": return String(localized: "progress_analyzing_photo")
        case "finding_stores": return String(localized: "progress_finding_stores")
        case "geocoding": return String(localized: "progress_geocoding")
        case "thinking": return String(localized: "progress_thinking")
        case "searching_products":
            let detail = progress.detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return detail.isEmpty
                ? String(localized: "progress_searching_generic")
                : String(format: String(localized: "progress_searching_products"), detail)
        case "proposing_preview": return String(localized: "progress_proposing_preview")
        case "composing": return String(localized: "progress_composing")
        default: return nil
        }
    }

    private func handleResponse(_ response: ChatResponse) async {
        progressText = nil
        logger.info("Handling response — phase: \(response.phase), turn: \(response.turn), isFinal: \(response.isFinal)")

        currentMessage = response.message
        let stylistLine = response.message.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stylistLine.isEmpty {
            history.append(ConversationEntry(role: .stylist, text: stylistLine))
        }
        currentOptions = response.options ?? []
        currentInputMode = response.inputMode
        currentUI = response.ui ?? []
        shoppingList = response.shoppingList ?? []
        stores = response.stores ?? []
        totalMxn = response.totalMxn ?? 0
        listSaved = false

        isSendingSelection = false
        previewError = nil
        if response.inputMode == .preview {
            let direction = response.direction ?? StyleDirectionDTO(brief: nil, ideas: [])
            if direction.ideas.isEmpty {
                logger.warning("Preview response has no ideas — round: \(direction.round, privacy: .public)")
            }
            self.direction = direction
            selectedIdeaIds = []
            previewComment = ""
            showStylePreview = true
            logger.info("Showing style preview — round: \(direction.round, privacy: .public), ideas: \(direction.ideas.map(\.id).joined(separator: ","), privacy: .public)")
        } else {
            direction = nil
            selectedIdeaIds = []
            showStylePreview = false
        }

        if response.isFinal {
            if shoppingList.isEmpty {
                logger.warning("Final response has no shopping list")
            } else {
                saveShoppingList()
                logger.info("Auto-saved shopping list — items: \(self.shoppingList.count, privacy: .public), stores: \(self.stores.count, privacy: .public)")
            }
        }

        // Speak the message
        state = .speaking
        isSpeaking = true
        // `speech` is written to be heard; `message` is the fallback for turns without it.
        let spoken = response.speech?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        await ttsService.speak(spoken.isEmpty ? response.message : spoken)
        isSpeaking = false

        // Brief pause after TTS
        try? await Task.sleep(for: .milliseconds(300))

        // The user may have answered while the message was still being spoken
        // (the preview stays interactive during TTS); don't clobber that state.
        guard state == .speaking else { return }

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

    /// Keeps the stylist's whole plan in "Mis looks", with the user's own photo as its image.
    func saveShoppingList() {
        guard !shoppingList.isEmpty else { return }
        let look = SavedLook.fromRecommendation(
            sessionId: sessionId,
            summary: currentMessage,
            items: shoppingList,
            stores: stores,
            totalMxn: totalMxn,
            originalImageUrl: userImageUrl
        )
        SavedLooksStore.shared.add(look)
        listSaved = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Whether this Style Mirror look is already in "Mis looks".
    func isSaved(_ look: LookItem) -> Bool {
        SavedLooksStore.shared.isSaved(sessionId: sessionId, name: look.name)
    }

    /// Saves the look on screen (image, products and nearby stores) to "Mis looks".
    /// Returns false when there is nothing to save.
    @discardableResult
    func saveCurrentLook() -> Bool {
        guard let look = currentLook, look.status == "ready" else { return false }
        return saveLook(look)
    }

    @discardableResult
    func saveLook(_ look: LookItem) -> Bool {
        var products: [ProductDTO] = []
        for piece in look.pieces {
            guard let productId = piece.productId else { continue }
            let product = shoppingList.lazy.flatMap(\.products).first { $0.id == productId }
                ?? ProductDTO(
                    id: productId,
                    title: piece.productName ?? piece.slotDescription,
                    store: piece.store ?? "",
                    price: piece.price ?? 0,
                    currency: "MXN",
                    link: piece.productLink,
                    thumbnail: piece.productImageUrl,
                    largeImage: nil,
                    delivery: nil,
                    availability: nil,
                    nearbyStore: nil
                )
            products.append(product)
        }
        let saved = SavedLook(
            sessionId: sessionId,
            name: look.name,
            description: cleanStylistCopy(look.description),
            finalImageUrl: look.finalImageUrl,
            originalImageUrl: userImageUrl,
            pieces: look.pieces.map {
                SavedLookPiece(slot: $0.slot, slotDescription: $0.slotDescription, productName: $0.productName)
            },
            products: products,
            stores: stores,
            totalMxn: products.reduce(0) { $0 + $1.price },
            source: .look
        )
        SavedLooksStore.shared.add(saved)
        listSaved = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        logger.info("Saved look \(look.id, privacy: .public) — products: \(products.count, privacy: .public)")
        return true
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
                    productId: lookPiece.productId ?? resultPiece?.productId,
                    productName: lookPiece.productName ?? resultPiece?.productName,
                    productImageUrl: lookPiece.productImageUrl ?? resultPiece?.productImageUrl,
                    tryonImageUrl: resultPiece?.tryonImageUrl,
                    productLink: lookPiece.productLink,
                    price: lookPiece.price,
                    store: lookPiece.store
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
            if !showLookCarousel && !showStylePreview {
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
}
#endif
