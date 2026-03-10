//
//  StylistService.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation
import OSLog

private let logger = Logger(subsystem: "ai.guaperrimo", category: "StylistService")

// MARK: - Protocol

protocol StylistService: Sendable {
    func chat(sessionId: String, request: ChatRequest) async throws -> ChatResponse
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
}

// MARK: - Stub implementation

struct StubStylistService: StylistService {
    private var turnCounter: Int = 0

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
                priorityActions: nil
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
                priorityActions: nil
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
            ]
        )
    }
}
#endif
