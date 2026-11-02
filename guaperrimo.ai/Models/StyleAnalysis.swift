//
//  StyleAnalysis.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

// MARK: - Request

nonisolated struct ChatRequest: Codable, Sendable {
    let type: String           // "image" | "button_response" | "voice_response" | "idea_selection" | "ui_action"
    let imageUrl: String?      // solo type=image
    let optionId: String?      // solo type=button_response
    let transcript: String?    // solo type=voice_response
    var selectedIdeas: [String]? = nil // solo type=idea_selection
    var text: String? = nil            // solo type=idea_selection (comentario opcional)
    var location: DeviceLocation? = nil // cualquier turno: ubicación del dispositivo, si el usuario la permitió
    var componentId: String? = nil     // solo type=ui_action: id del componente (p. ej. "budget")
    var value: String? = nil           // solo type=ui_action: valor confirmado como texto
}

// MARK: - Response

nonisolated enum InputMode: String, Codable, Sendable {
    case buttons
    case voice
    case preview   // style preview: brief + garment ideas to pick from
    case ui        // generative UI: the turn waits for a component's confirm (slider)
    case none
}

nonisolated struct ChatOption: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let label: String
}

nonisolated struct PriorityAction: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let impact: String   // "alto", "medio", "bajo"
    let effort: String   // "alto", "medio", "bajo"
}

nonisolated struct ChatResponse: Decodable, Sendable {
    let sessionId: String
    let phase: String          // "discovery", "recommendation"
    let turn: Int
    let message: String
    let inputMode: InputMode
    let options: [ChatOption]?
    let isFinal: Bool
    let priorityActions: [PriorityAction]?
    let looksGenerating: Bool?

    // Final turn: the shopping list with real products and nearby stores
    var shoppingList: [ShoppingItemDTO]? = nil
    var stores: [StoreDTO]? = nil
    var totalMxn: Double? = nil
    var locationKnown: Bool? = nil
    var matrixAvailable: Bool? = nil

    // Preview turn (input_mode "preview"): style brief + garment ideas
    var direction: StyleDirectionDTO? = nil

    // Generative UI (ui_version 1). `ui` missing or empty → legacy layout.
    var uiVersion: Int? = nil
    var speech: String? = nil   // text to read aloud; falls back to `message`
    var ui: [UIComponent]? = nil

    /// Memberwise initializer (the custom decoder below suppresses the synthesized one).
    init(
        sessionId: String, phase: String, turn: Int, message: String, inputMode: InputMode,
        options: [ChatOption]?, isFinal: Bool, priorityActions: [PriorityAction]?, looksGenerating: Bool?,
        shoppingList: [ShoppingItemDTO]? = nil, stores: [StoreDTO]? = nil, totalMxn: Double? = nil,
        locationKnown: Bool? = nil, matrixAvailable: Bool? = nil, direction: StyleDirectionDTO? = nil,
        uiVersion: Int? = nil, speech: String? = nil, ui: [UIComponent]? = nil
    ) {
        self.sessionId = sessionId; self.phase = phase; self.turn = turn; self.message = message
        self.inputMode = inputMode; self.options = options; self.isFinal = isFinal
        self.priorityActions = priorityActions; self.looksGenerating = looksGenerating
        self.shoppingList = shoppingList; self.stores = stores; self.totalMxn = totalMxn
        self.locationKnown = locationKnown; self.matrixAvailable = matrixAvailable
        self.direction = direction; self.uiVersion = uiVersion; self.speech = speech; self.ui = ui
    }

    private enum CodingKeys: String, CodingKey {
        case sessionId, phase, turn, message, inputMode, options, isFinal, priorityActions, looksGenerating
        case shoppingList, stores, totalMxn, locationKnown, matrixAvailable, direction
        case uiVersion, speech, ui
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try c.decode(String.self, forKey: .sessionId)
        phase = try c.decode(String.self, forKey: .phase)
        turn = try c.decode(Int.self, forKey: .turn)
        message = try c.decode(String.self, forKey: .message)
        inputMode = try c.decode(InputMode.self, forKey: .inputMode)
        options = try c.decodeIfPresent([ChatOption].self, forKey: .options)
        isFinal = try c.decode(Bool.self, forKey: .isFinal)
        priorityActions = try c.decodeIfPresent([PriorityAction].self, forKey: .priorityActions)
        looksGenerating = try c.decodeIfPresent(Bool.self, forKey: .looksGenerating)
        shoppingList = try c.decodeIfPresent([ShoppingItemDTO].self, forKey: .shoppingList)
        stores = try c.decodeIfPresent([StoreDTO].self, forKey: .stores)
        totalMxn = try c.decodeIfPresent(Double.self, forKey: .totalMxn)
        locationKnown = try c.decodeIfPresent(Bool.self, forKey: .locationKnown)
        matrixAvailable = try c.decodeIfPresent(Bool.self, forKey: .matrixAvailable)
        direction = try c.decodeIfPresent(StyleDirectionDTO.self, forKey: .direction)
        uiVersion = try? c.decodeIfPresent(Int.self, forKey: .uiVersion)
        speech = try? c.decodeIfPresent(String.self, forKey: .speech)
        // A bad `ui` block must never cost the turn: elements decode one by one.
        ui = (try? c.decodeIfPresent(LossyArray<UIComponent>.self, forKey: .ui))?.elements
    }
}
#endif
