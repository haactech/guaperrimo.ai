//
//  StylistService.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation
import os
import OSLog

private let logger = Logger(subsystem: "ai.guaperrimo", category: "StylistService")

// MARK: - Protocol

protocol StylistService: Sendable {
    func chat(sessionId: String, request: ChatRequest) async throws -> ChatResponse
    func fetchLooks(sessionId: String) async throws -> LooksResponse
    /// Same as `chat`, but reports what the stylist is doing while the turn is prepared.
    func chatStream(sessionId: String, request: ChatRequest, onStatus: @Sendable @escaping (ChatProgress) -> Void) async throws -> ChatResponse
}

extension StylistService {
    func chatStream(sessionId: String, request: ChatRequest, onStatus: @Sendable @escaping (ChatProgress) -> Void) async throws -> ChatResponse {
        try await chat(sessionId: sessionId, request: request)
    }
}

nonisolated private struct StreamFailure: Decodable, Sendable {
    let status: Int?
    let message: String?
}

// MARK: - Live implementation

struct LiveStylistService: StylistService {
    private let apiClient = APIClient()

    func chat(sessionId: String, request: ChatRequest) async throws -> ChatResponse {
        logger.info("⬆️ POST /session/\(sessionId)/chat — type: \(request.type)")
        let response: ChatResponse = try await apiClient.postJSON(
            path: "/session/\(sessionId)/chat",
            body: request,
            timeout: 180
        )
        logger.info("⬇️ Chat response — phase: \(response.phase), turn: \(response.turn), isFinal: \(response.isFinal)")
        return response
    }

    /// POST /chat/stream (SSE). An old backend answers 404/405 and we fall back to POST /chat.
    /// An `error` event or a stream that ends without a `turn` throws; nothing is retried here.
    func chatStream(sessionId: String, request: ChatRequest, onStatus: @Sendable @escaping (ChatProgress) -> Void) async throws -> ChatResponse {
        let path = "/session/\(sessionId)/chat/stream"
        guard let url = URL(string: "\(APIClient.baseURL)\(path)") else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        urlRequest.timeoutInterval = 180
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        urlRequest.httpBody = try encoder.encode(request)

        logger.info("⬆️ POST \(url.absoluteString, privacy: .public) (stream) — type: \(request.type, privacy: .public)")

        let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        logger.info("⬇️ HTTP \(http.statusCode, privacy: .public) (stream)")

        if http.statusCode == 404 || http.statusCode == 405 {
            logger.warning("Stream endpoint unavailable (\(http.statusCode, privacy: .public)) — falling back to /chat")
            return try await chat(sessionId: sessionId, request: request)
        }
        guard (200...299).contains(http.statusCode) else {
            var body = Data()
            for try await byte in bytes { body.append(byte); if body.count > 4096 { break } }
            throw APIError.serverError(statusCode: http.statusCode, message: String(decoding: body, as: UTF8.self))
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        func handle(_ event: SSEEvent) throws -> ChatResponse? {
            logger.info("SSE event: \(event.event, privacy: .public) — \(event.data, privacy: .public)")
            let data = Data(event.data.utf8)
            switch event.event {
            case "status":
                if let progress = try? decoder.decode(ChatProgress.self, from: data) { onStatus(progress) }
                return nil
            case "turn":
                do {
                    return try decoder.decode(ChatResponse.self, from: data)
                } catch {
                    logger.error("❌ Decode error: \(String(describing: error), privacy: .public)")
                    throw APIError.decodingFailed(underlying: error, body: event.data)
                }
            case "error":
                let failure = try? decoder.decode(StreamFailure.self, from: data)
                throw APIError.serverError(statusCode: failure?.status ?? 500, message: failure?.message ?? event.data)
            default:
                return nil
            }
        }

        // `bytes.lines` drops blank lines, which are the event delimiters, so split by hand.
        var parser = SSEParser()
        var buffer: [UInt8] = []
        for try await byte in bytes {
            guard byte == 0x0A else { buffer.append(byte); continue }
            let line = String(decoding: buffer, as: UTF8.self)
            buffer.removeAll(keepingCapacity: true)
            if let event = parser.push(line: line), let turn = try handle(event) { return turn }
        }
        if !buffer.isEmpty, let event = parser.push(line: String(decoding: buffer, as: UTF8.self)), let turn = try handle(event) { return turn }
        if let event = parser.finish(), let turn = try handle(event) { return turn }

        throw APIError.invalidResponse // stream closed without a turn
    }

    func fetchLooks(sessionId: String) async throws -> LooksResponse {
        logger.info("⬆️ GET /session/\(sessionId)/looks")
        let response: LooksResponse = try await apiClient.getJSON(
            path: "/session/\(sessionId)/looks",
            timeout: 15
        )
        logger.info("⬇️ Looks response — ready: \(response.readyCount)/\(response.totalCount), allReady: \(response.allReady)")
        return response
    }
}

// MARK: - Stub implementation

struct StubStylistService: StylistService {
    private var turnCounter: Int = 0
    private static let lookPollCount = OSAllocatedUnfairLock(initialState: 0)

    func fetchLooks(sessionId: String) async throws -> LooksResponse {
        try await Task.sleep(for: .milliseconds(500))

        let callNumber = Self.lookPollCount.withLock { count -> Int in
            count += 1
            return count
        }

        let lookDTOs: [LookDTO] = [
            LookDTO(
                id: "look_1", name: "Casual Elevado",
                description: "Look urbano con equilibrio entre comodidad y estilo",
                vibe: "casual elevado",
                pieces: [
                    LookPieceDTO(slot: "upper_body", description: "Camisa de lino azul marino", category: "upper_body"),
                    LookPieceDTO(slot: "lower_body", description: "Pantalon chino slim beige", category: "lower_body")
                ]
            ),
            LookDTO(
                id: "look_2", name: "Smart Casual",
                description: "Combinacion inteligente con camisa y pantalon para versatilidad",
                vibe: "smart casual",
                pieces: [
                    LookPieceDTO(slot: "upper_body", description: "Polo de punto gris", category: "upper_body"),
                    LookPieceDTO(slot: "lower_body", description: "Pantalon de vestir azul", category: "lower_body")
                ]
            ),
            LookDTO(
                id: "look_3", name: "Urbano Moderno",
                description: "Look relajado con sneakers premium y overshirt de franela",
                vibe: "urbano moderno",
                pieces: [
                    LookPieceDTO(slot: "upper_body", description: "Overshirt de franela verde", category: "upper_body"),
                    LookPieceDTO(slot: "lower_body", description: "Jeans slim negro", category: "lower_body")
                ]
            )
        ]

        let lookResults: [LookResultDTO]
        switch callNumber {
        case 1:
            lookResults = stubResults(readyUpTo: 0)
        case 2:
            lookResults = stubResults(readyUpTo: 1)
        default:
            lookResults = stubResults(readyUpTo: 3)
        }

        let readyCount = lookResults.filter { $0.status == "ready" }.count
        let allDone = lookResults.allSatisfy { $0.status == "ready" || $0.status == "failed" }

        return LooksResponse(
            sessionId: sessionId,
            status: allDone ? "ready" : "partial",
            allReady: allDone,
            readyCount: readyCount,
            totalCount: lookDTOs.count,
            looks: lookDTOs,
            lookResults: lookResults
        )
    }

    private func stubResults(readyUpTo count: Int) -> [LookResultDTO] {
        let lookIds = ["look_1", "look_2", "look_3"]
        return lookIds.enumerated().map { index, lookId in
            if index < count {
                return LookResultDTO(
                    lookId: lookId,
                    status: "ready",
                    pieces: [
                        PieceResultDTO(
                            slot: "upper_body",
                            productId: "prod_\(index)_1",
                            productName: index == 0 ? "Blue Linen Shirt" : index == 1 ? "Grey Knit Polo" : "Green Flannel Overshirt",
                            productImageUrl: "https://picsum.photos/72/72?random=\(index)0",
                            tryonImageUrl: "https://picsum.photos/400/600?random=\(index)a",
                            category: "upper_body",
                            generationTimeMs: 12400
                        ),
                        PieceResultDTO(
                            slot: "lower_body",
                            productId: "prod_\(index)_2",
                            productName: index == 0 ? "Beige Chino Pants" : index == 1 ? "Blue Dress Pants" : "Black Slim Jeans",
                            productImageUrl: "https://picsum.photos/72/72?random=\(index)1",
                            tryonImageUrl: "https://picsum.photos/400/600?random=\(index)b",
                            category: "lower_body",
                            generationTimeMs: 11800
                        )
                    ],
                    finalImageUrl: "https://picsum.photos/400/600?random=\(index)",
                    errorMessage: nil,
                    generationTimeMs: 24200
                )
            } else if count >= 3 && index == 2 {
                return LookResultDTO(
                    lookId: lookId, status: "failed", pieces: [],
                    finalImageUrl: nil, errorMessage: "VTON generation timed out",
                    generationTimeMs: 0
                )
            } else {
                return LookResultDTO(
                    lookId: lookId, status: "generating", pieces: [],
                    finalImageUrl: nil, errorMessage: nil,
                    generationTimeMs: 0
                )
            }
        }
    }

    /// Emits two fake statuses so the progress line can be seen in previews.
    func chatStream(sessionId: String, request: ChatRequest, onStatus: @Sendable @escaping (ChatProgress) -> Void) async throws -> ChatResponse {
        onStatus(ChatProgress(stage: request.type == "image" ? "analyzing_photo" : "thinking", detail: nil))
        try await Task.sleep(for: .milliseconds(600))
        onStatus(ChatProgress(stage: "searching_products", detail: "botas chelsea"))
        return try await chat(sessionId: sessionId, request: request)
    }

    func chat(sessionId: String, request: ChatRequest) async throws -> ChatResponse {
        try await Task.sleep(for: .seconds(1.5))

        // First turn (image): discovery with buttons
        if request.type == "image" {
            return ChatResponse(
                sessionId: sessionId,
                phase: "discovery",
                turn: 1,
                message: "Veo un look casual con buenas proporciones. Para qué ocasión te vistes?",
                inputMode: .buttons,
                options: Self.occasionOptions, // the server mirrors chips into options
                isFinal: false,
                priorityActions: nil,
                looksGenerating: nil,
                uiVersion: 1,
                speech: "Veo un look casual con buenas proporciones. Para qué ocasión te estás vistiendo?",
                ui: [
                    .text(TextComponent(role: .stylist, text: "Veo un look casual con buenas proporciones. Para qué ocasión te vistes?")),
                    .chips(ChipsComponent(id: "occasion", select: "single", allowVoice: true, options: Self.occasionOptions))
                ]
            )
        }

        // Second turn: the budget slider (waits for its confirm)
        if request.type == "button_response" {
            return ChatResponse(
                sessionId: sessionId,
                phase: "discovery",
                turn: 2,
                message: "Buena eleccion! Cuanto quieres gastar en total?",
                inputMode: .ui,
                options: nil,
                isFinal: false,
                priorityActions: nil,
                looksGenerating: nil,
                uiVersion: 1,
                speech: "Buena elección. Cuánto quieres gastar en total?",
                ui: [
                    .text(TextComponent(role: .stylist, text: "Buena elección. Cuánto quieres gastar en total?")),
                    .slider(SliderComponent(
                        id: "budget", label: "Presupuesto", min: 500, max: 10000, step: 100,
                        defaultValue: 2500, unit: "MXN", profileField: "budget_mxn"
                    ))
                ]
            )
        }

        // Third turn: palette, then a voice question
        if request.type == "ui_action" {
            return ChatResponse(
                sessionId: sessionId,
                phase: "discovery",
                turn: 3,
                message: "Con ese presupuesto, estos colores te quedan muy bien. Cuentame, que te preocupa de tu look actual?",
                inputMode: .voice,
                options: nil,
                isFinal: false,
                priorityActions: nil,
                looksGenerating: nil,
                uiVersion: 1,
                speech: "Con ese presupuesto, estos colores te quedan muy bien. Cuéntame, qué te preocupa de tu look actual?",
                ui: [
                    .text(TextComponent(role: .heading, text: "Tu paleta")),
                    .palette(PaletteComponent(
                        swatches: [
                            PaletteSwatch(hex: "#1F2A44", name: "Azul marino"),
                            PaletteSwatch(hex: "#D8C3A5", name: "Beige"),
                            PaletteSwatch(hex: "#6B7B5E", name: "Verde olivo"),
                            PaletteSwatch(hex: "#F2F2F2", name: "Blanco roto")
                        ],
                        avoid: [PaletteSwatch(hex: "#000000", name: "Negro total")],
                        note: "El azul marino y el beige se llevan con todo lo que ya tienes."
                    )),
                    .text(TextComponent(role: .stylist, text: "Cuéntame, qué te preocupa de tu look actual?"))
                ]
            )
        }

        // Final turn: recommendations
        return ChatResponse(
            sessionId: sessionId,
            phase: "recommendation",
            turn: 3,
            message: "Perfecto! Basandome en tu estilo y ocasion, aqui van mis recomendaciones prioritarias:",
            inputMode: .none,
            options: nil,
            isFinal: true,
            priorityActions: [
                PriorityAction(
                    id: "swap_shoes",
                    title: "Cambia los tenis por botas Chelsea",
                    description: "Unas botas Chelsea en negro o cafe oscuro elevan cualquier outfit casual al instante. Busca unas con suela delgada para mantener la linea limpia.",
                    impact: "alto",
                    effort: "bajo"
                ),
                PriorityAction(
                    id: "add_layer",
                    title: "Agrega una capa intermedia",
                    description: "Un overshirt de franela o una chaqueta ligera tipo bomber anade dimension y estructura a tu look.",
                    impact: "alto",
                    effort: "medio"
                ),
                PriorityAction(
                    id: "accessories",
                    title: "Suma un accesorio clave",
                    description: "Un reloj minimalista o una cadena sutil pueden hacer toda la diferencia sin complicar el outfit.",
                    impact: "medio",
                    effort: "bajo"
                ),
            ],
            looksGenerating: true,
            uiVersion: 1,
            speech: "Perfecto! Basándome en tu estilo y ocasión, estas son mis recomendaciones prioritarias.",
            ui: [
                .text(TextComponent(role: .stylist, text: "Perfecto! Basandome en tu estilo y ocasion, aqui van mis recomendaciones prioritarias:")),
                .steps(StepsComponent(items: [
                    StepItem(title: "Cambia los tenis por botas Chelsea",
                             detail: "Unas botas Chelsea en negro o cafe oscuro elevan cualquier outfit casual al instante.",
                             productIds: ["p_boots"]),
                    StepItem(title: "Agrega una capa intermedia",
                             detail: "Un overshirt de franela o una chaqueta ligera tipo bomber anade dimension y estructura.",
                             productIds: ["p_overshirt"]),
                    StepItem(title: "Suma un accesorio clave",
                             detail: "Un reloj minimalista o una cadena sutil hacen la diferencia sin complicar el outfit.",
                             productIds: nil)
                ])),
                .budgetBar(BudgetBarComponent(totalMxn: 2247, budgetMxn: 2500, label: "Total aproximado")),
                .productCard(ProductCardComponent(
                    productId: "p_boots", title: "Botas Chelsea piel café", priceMxn: 1299, store: "Mercado Libre",
                    imageUrl: "https://picsum.photos/128/128?random=41", link: nil, nearby: nil
                )),
                .productCard(ProductCardComponent(
                    productId: "p_overshirt", title: "Overshirt de franela verde", priceMxn: 948, store: "H&M",
                    imageUrl: "https://picsum.photos/128/128?random=42", link: nil,
                    nearby: NearbyStore(name: "H&M Reforma", distanceM: 450)
                ))
            ]
        )
    }

    private static let occasionOptions = [
        ChatOption(id: "boda_dia", label: "Boda de día"),
        ChatOption(id: "trabajo", label: "Trabajo"),
        ChatOption(id: "cita", label: "Una cita"),
        ChatOption(id: "casual", label: "Casual elevado"),
        ChatOption(id: "streetwear", label: "Streetwear")
    ]
}
#endif
