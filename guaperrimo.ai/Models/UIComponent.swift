//
//  UIComponent.swift
//  guaperrimo.ai
//
//  Generative UI contract (ui_version 1): the backend sends a closed catalog of
//  components per turn and the app renders each with the design system.
//

#if os(iOS)
import Foundation

// MARK: - Payloads

nonisolated struct TextComponent: Decodable, Sendable {
    enum Role: String, Sendable {
        case stylist, heading, body
    }

    let role: Role
    let text: String

    private enum CodingKeys: String, CodingKey { case role, text }

    init(role: Role, text: String) {
        self.role = role
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try c.decodeIfPresent(String.self, forKey: .role)
        role = raw.flatMap(Role.init(rawValue:)) ?? .body
        text = try c.decode(String.self, forKey: .text)
    }
}

nonisolated struct ChipsComponent: Decodable, Sendable {
    let id: String
    let select: String?
    let allowVoice: Bool?
    let options: [ChatOption]
}

nonisolated struct SliderComponent: Decodable, Sendable {
    let id: String
    let label: String
    let min: Double
    let max: Double
    let step: Double?
    let defaultValue: Double?
    let unit: String?
    let profileField: String?

    private enum CodingKeys: String, CodingKey {
        case id, label, min, max, step, unit, profileField
        case defaultValue = "default"
    }
}

nonisolated struct PaletteSwatch: Decodable, Sendable {
    let hex: String
    let name: String?
}

nonisolated struct PaletteComponent: Decodable, Sendable {
    let swatches: [PaletteSwatch]
    let avoid: [PaletteSwatch]?
    let note: String?
}

nonisolated struct StepItem: Decodable, Sendable {
    let title: String
    let detail: String?
    let productIds: [String]?
}

nonisolated struct StepsComponent: Decodable, Sendable {
    let items: [StepItem]
}

nonisolated struct NearbyStore: Decodable, Sendable {
    let name: String
    let distanceM: Double?
}

nonisolated struct ProductCardComponent: Decodable, Sendable {
    let productId: String?
    let title: String
    let priceMxn: Double?
    let store: String?
    let imageUrl: String?
    let link: String?
    let nearby: NearbyStore?
}

nonisolated struct BudgetBarComponent: Decodable, Sendable {
    let totalMxn: Double
    let budgetMxn: Double?
    let label: String?
}

// MARK: - Component

nonisolated enum UIComponent: Decodable, Sendable, Identifiable {
    case text(TextComponent)
    case chips(ChipsComponent)
    case slider(SliderComponent)
    case palette(PaletteComponent)
    case steps(StepsComponent)
    case productCard(ProductCardComponent)
    case budgetBar(BudgetBarComponent)
    case unknown(type: String)

    private enum CodingKeys: String, CodingKey { case type }

    init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .type)
        switch type {
        case "text": self = .text(try TextComponent(from: decoder))
        case "chips": self = .chips(try ChipsComponent(from: decoder))
        case "slider": self = .slider(try SliderComponent(from: decoder))
        case "palette": self = .palette(try PaletteComponent(from: decoder))
        case "steps": self = .steps(try StepsComponent(from: decoder))
        case "product_card": self = .productCard(try ProductCardComponent(from: decoder))
        case "budget_bar": self = .budgetBar(try BudgetBarComponent(from: decoder))
        default: self = .unknown(type: type)
        }
    }

    /// The component's own id when it has one; otherwise derived from its content
    /// (the canvas lays out by position, so this is only an identity hint).
    var id: String {
        switch self {
        case .text(let c): "text:\(c.role.rawValue):\(c.text)"
        case .chips(let c): "chips:\(c.id)"
        case .slider(let c): "slider:\(c.id)"
        case .palette(let c): "palette:\(c.swatches.map(\.hex).joined(separator: ","))"
        case .steps(let c): "steps:\(c.items.map(\.title).joined(separator: "|"))"
        case .productCard(let c): "product:\(c.productId ?? c.title)"
        case .budgetBar(let c): "budget:\(c.totalMxn)"
        case .unknown(let type): "unknown:\(type)"
        }
    }

    var isChipsWithVoice: Bool {
        if case .chips(let c) = self { return c.allowVoice == true }
        return false
    }
}

// MARK: - Lossy decoding

/// Decodes an array element by element: a malformed or unreadable element is
/// skipped instead of failing the whole response.
nonisolated struct LossyArray<Element: Decodable & Sendable>: Decodable, Sendable {
    let elements: [Element]

    private struct Discard: Decodable {}

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                result.append(element)
            } else {
                // A failed decode does not advance the cursor; consume the element.
                _ = try? container.decode(Discard.self)
            }
        }
        elements = result
    }
}
#endif
