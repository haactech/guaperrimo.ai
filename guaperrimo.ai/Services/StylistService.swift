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
    func createPoll(sessionId: String, lookIds: [String]) async throws -> LookPoll
    func fetchPolls(sessionId: String) async throws -> [LookPoll]
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

    func fetchLooks(sessionId: String) async throws -> LooksResponse {
        logger.info("⬆️ GET /session/\(sessionId)/looks")
        let response: LooksResponse = try await apiClient.getJSON(
            path: "/session/\(sessionId)/looks",
            timeout: 15
        )
        logger.info("⬇️ Looks response — ready: \(response.readyCount)/\(response.totalCount), allReady: \(response.allReady)")
        return response
    }

    func createPoll(sessionId: String, lookIds: [String]) async throws -> LookPoll {
        try await apiClient.postJSON(
            path: "/session/\(sessionId)/polls",
            body: CreatePollRequest(lookIds: lookIds),
            timeout: 15
        )
    }

    func fetchPolls(sessionId: String) async throws -> [LookPoll] {
        let response: PollListResponse = try await apiClient.getJSON(
            path: "/session/\(sessionId)/polls",
            timeout: 15
        )
        return response.polls
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

    func createPoll(sessionId: String, lookIds: [String]) async throws -> LookPoll {
        try await Task.sleep(for: .milliseconds(400))
        return Self.samplePoll(lookIds: lookIds, votes: [])
    }

    func fetchPolls(sessionId: String) async throws -> [LookPoll] {
        try await Task.sleep(for: .milliseconds(300))
        return [Self.samplePoll(lookIds: ["look_1", "look_2"], votes: [
            LookPollVote(choice: 0, voterName: "Mariana", comment: "El verde te queda increíble, se ve fresco para boda de día",
                         reasons: ["El color le queda mejor", "Va mejor con la ocasión"]),
            LookPollVote(choice: 1, voterName: "Sofi", reasons: ["Se ve más actual"]),
            LookPollVote(choice: 0, comment: "El A sin duda", reasons: ["Le queda mejor el corte"]),
            LookPollVote(choice: 0, reasons: ["El color le queda mejor"])
        ])]
    }

    private static func samplePoll(lookIds: [String], votes: [LookPollVote]) -> LookPoll {
        let names = ["Casual Elevado", "Smart Casual"]
        let options = lookIds.prefix(2).enumerated().map { index, id in
            let mine = votes.filter { $0.choice == index }
            var counts: [String: Int] = [:]
            for label in mine.flatMap(\.reasons) { counts[label, default: 0] += 1 }
            return LookPollOption(
                lookId: id, name: names[index % names.count],
                imageUrl: "https://picsum.photos/400/600?random=\(index)", voteCount: mine.count,
                reasons: counts.sorted { $0.value > $1.value }.map { LookPollReason(id: $0.key, label: $0.key, count: $0.value) }
            )
        }
        return LookPoll(id: "stub_poll", url: "http://192.168.100.39:8080/v/stub_poll", open: true,
                        totalVotes: votes.count, options: options, votes: votes)
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
