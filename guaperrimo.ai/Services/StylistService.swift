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
    func tryOn(sessionId: String, request: TryOnRequest) async throws -> TryOnResponse
    func fetchLooks(sessionId: String) async throws -> LooksResponse
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

    func tryOn(sessionId: String, request: TryOnRequest) async throws -> TryOnResponse {
        logger.info("⬆️ POST /session/\(sessionId)/tryon — action: \(request.actionId)")
        let response: TryOnResponse = try await apiClient.postJSON(
            path: "/session/\(sessionId)/tryon",
            body: request,
            timeout: 30
        )
        logger.info("⬇️ TryOn response — garment: \(response.garmentUsed)")
        return response
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

    func tryOn(sessionId: String, request: TryOnRequest) async throws -> TryOnResponse {
        try await Task.sleep(for: .seconds(8))
        return TryOnResponse(
            tryonImageUrl: "https://picsum.photos/400/600",
            garmentUsed: request.garmentDescription
        )
    }

    func chat(sessionId: String, request: ChatRequest) async throws -> ChatResponse {
        try await Task.sleep(for: .seconds(1.5))

        // First turn (image): discovery with buttons
        if request.type == "image" {
            return ChatResponse(
                sessionId: sessionId,
                phase: "discovery",
                turn: 1,
                message: "Veo un look casual con buenas proporciones. Para darte las mejores recomendaciones, necesito conocerte mejor. Que estilo te representa mas?",
                inputMode: .buttons,
                options: [
                    ChatOption(id: "casual", label: "Casual elevado"),
                    ChatOption(id: "streetwear", label: "Streetwear"),
                    ChatOption(id: "minimalist", label: "Minimalista"),
                    ChatOption(id: "smart_casual", label: "Smart casual"),
                ],
                isFinal: false,
                priorityActions: nil,
                looksGenerating: nil
            )
        }

        // Second turn: voice question
        if request.type == "button_response" {
            return ChatResponse(
                sessionId: sessionId,
                phase: "discovery",
                turn: 2,
                message: "Buena eleccion! Ahora cuentame, para que ocasion te estas vistiendo hoy?",
                inputMode: .voice,
                options: nil,
                isFinal: false,
                priorityActions: nil,
                looksGenerating: nil
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
            looksGenerating: true
        )
    }
}
#endif
