//
//  ShoppingListModels.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

// MARK: - API DTOs (match the backend's final chat response)

nonisolated struct NearbyStoreRef: Codable, Sendable, Equatable, Hashable {
    let placeId: String
    let name: String
    let distanceM: Int
}

nonisolated struct ProductDTO: Codable, Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let store: String
    let price: Double
    let currency: String
    let link: String?
    let thumbnail: String?
    let largeImage: String?
    let delivery: String?
    let availability: String?
    let nearbyStore: NearbyStoreRef?

    var imageUrl: String? { largeImage ?? thumbnail }

    var priceLabel: String {
        "$\(Int(price.rounded())) \(currency)"
    }

    /// "$539 MXN · Mercado Libre", or just the price when the store name is missing.
    var priceAndStoreLabel: String {
        [priceLabel, store].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

nonisolated struct StoreDTO: Codable, Sendable, Identifiable, Equatable, Hashable {
    var id: String { placeId }
    let placeId: String
    let name: String
    let address: String
    let lat: Double
    let lng: Double
    let distanceM: Int
    let rating: Double?
    let openState: String?
    let website: String?
    let phone: String?

    /// Apple Maps link to the store.
    var mapsUrl: URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "ll", value: "\(lat),\(lng)"),
            URLQueryItem(name: "q", value: name),
        ]
        return components?.url
    }
}

nonisolated struct ShoppingItemDTO: Codable, Sendable, Identifiable, Equatable {
    var id: String { slot + "|" + description }
    let slot: String
    let description: String
    let why: String?
    let priority: Int?
    let products: [ProductDTO]

    /// `description` without markdown emphasis or an appended "Precio: $…" note.
    var displayDescription: String { cleanStylistCopy(description) }

    /// `why` cleaned the same way; nil when there is nothing left to show.
    var displayWhy: String? {
        guard let why else { return nil }
        let cleaned = cleanStylistCopy(why)
        return cleaned.isEmpty ? nil : cleaned
    }
}

// MARK: - What the user keeps on the phone

nonisolated struct SavedShoppingList: Codable, Sendable, Equatable {
    let sessionId: String
    let savedAt: Date
    let summary: String
    let items: [ShoppingItemDTO]
    let stores: [StoreDTO]
    let totalMxn: Double
    var purchased: Set<String>
    var liked: Bool? = nil

    func store(for product: ProductDTO) -> StoreDTO? {
        guard let ref = product.nearbyStore else { return nil }
        return stores.first { $0.placeId == ref.placeId }
    }
}

// MARK: - Helpers

nonisolated func slotLabel(_ slot: String) -> String {
    switch slot {
    case "upper_body": return String(localized: "slot_upper_body")
    case "outerwear": return String(localized: "slot_outerwear")
    case "lower_body": return String(localized: "slot_lower_body")
    case "footwear": return String(localized: "slot_footwear")
    case "accessory": return String(localized: "slot_accessory")
    default: return slot.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

nonisolated func distanceLabel(_ meters: Int) -> String {
    if meters < 1000 {
        return "\(meters) m"
    }
    return String(format: "%.1f km", Double(meters) / 1000)
}

/// Strips markdown emphasis and appended price notes from copy the backend wrote for the LLM,
/// e.g. "Saco azul marino slim (talla M). **Precio: $539**" → "Saco azul marino slim (talla M)."
nonisolated func cleanStylistCopy(_ text: String) -> String {
    var cleaned = text.replacingOccurrences(
        of: #"\*{0,2}\s*Precio:\s*\$?\s*[\d.,]+\s*(MXN)?\s*\.?\s*\*{0,2}"#,
        with: "",
        options: [.regularExpression, .caseInsensitive]
    )
    cleaned = cleaned.replacingOccurrences(of: "**", with: "")
    cleaned = cleaned.replacingOccurrences(of: "__", with: "")
    cleaned = cleaned.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
}
#endif
