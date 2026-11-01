//
//  SavedLookModels.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

/// A piece of a saved look, kept as the stylist described it.
nonisolated struct SavedLookPiece: Codable, Sendable, Equatable, Hashable {
    let slot: String
    let slotDescription: String
    let productName: String?
}

/// A look the user kept with its image, products and the stores that were near when it was made.
nonisolated struct SavedLook: Codable, Sendable, Identifiable, Equatable {
    enum Source: String, Codable, Sendable {
        case recommendation
        case look
    }

    let id: String
    let sessionId: String
    let savedAt: Date
    let name: String
    let description: String
    let finalImageUrl: String?
    let originalImageUrl: String?
    let pieces: [SavedLookPiece]
    /// The primary product of each piece.
    let products: [ProductDTO]
    let stores: [StoreDTO]
    let totalMxn: Double
    var purchased: Set<String>
    let source: Source

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        savedAt: Date = Date(),
        name: String,
        description: String,
        finalImageUrl: String?,
        originalImageUrl: String?,
        pieces: [SavedLookPiece],
        products: [ProductDTO],
        stores: [StoreDTO],
        totalMxn: Double,
        purchased: Set<String> = [],
        source: Source
    ) {
        self.id = id
        self.sessionId = sessionId
        self.savedAt = savedAt
        self.name = name
        self.description = description
        self.finalImageUrl = finalImageUrl
        self.originalImageUrl = originalImageUrl
        self.pieces = pieces
        self.products = products
        self.stores = stores
        self.totalMxn = totalMxn
        self.purchased = purchased
        self.source = source
    }

    /// The image that represents the look: the rendered look, else the user's own photo.
    var coverImageUrl: String? { finalImageUrl ?? originalImageUrl }

    func store(for product: ProductDTO) -> StoreDTO? {
        guard let ref = product.nearbyStore else { return nil }
        return stores.first { $0.placeId == ref.placeId }
    }

    /// Number of distinct stores that actually carry one of this look's products.
    var nearbyStoreCount: Int {
        Set(products.compactMap { $0.nearbyStore?.placeId }).count
    }

    /// "$2,247 MXN · 2 tiendas cerca", or just the price when no store is near.
    var summaryLine: String {
        let price = "$\(Int(totalMxn.rounded()).formatted(.number.grouping(.automatic))) MXN"
        guard totalMxn > 0 else { return nearbyStoreCount > 0 ? storesPhrase : "" }
        return nearbyStoreCount > 0 ? "\(price) · \(storesPhrase)" : price
    }

    private var storesPhrase: String {
        nearbyStoreCount == 1
            ? String(localized: "mylooks_store_near_one")
            : String(format: String(localized: "mylooks_stores_near"), nearbyStoreCount)
    }

    /// Builds a look from a final-turn recommendation (the stylist's whole plan).
    static func fromRecommendation(
        sessionId: String,
        summary: String,
        items: [ShoppingItemDTO],
        stores: [StoreDTO],
        totalMxn: Double,
        originalImageUrl: String?
    ) -> SavedLook {
        let pieces = items.map {
            SavedLookPiece(slot: $0.slot, slotDescription: $0.displayDescription, productName: $0.products.first?.title)
        }
        return SavedLook(
            sessionId: sessionId,
            name: planName(from: summary),
            description: cleanStylistCopy(summary),
            finalImageUrl: nil,
            originalImageUrl: originalImageUrl,
            pieces: pieces,
            products: items.compactMap { $0.products.first },
            stores: stores,
            totalMxn: totalMxn,
            source: .recommendation
        )
    }

    /// The first sentence of the summary when it is short enough to be a title.
    static func planName(from summary: String, maxLength: Int = 40) -> String {
        let cleaned = cleanStylistCopy(summary)
        let sentence = cleaned
            .split(whereSeparator: { ".!?\n".contains($0) })
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        if sentence.isEmpty || sentence.count > maxLength {
            return String(localized: "mylooks_default_plan_name")
        }
        return sentence
    }

    /// Imports the single-list format used before "Mis looks".
    init(migrating old: SavedShoppingList) {
        self.init(
            sessionId: old.sessionId,
            savedAt: old.savedAt,
            name: Self.planName(from: old.summary),
            description: cleanStylistCopy(old.summary),
            finalImageUrl: nil,
            originalImageUrl: nil,
            pieces: old.items.map {
                SavedLookPiece(slot: $0.slot, slotDescription: $0.displayDescription, productName: $0.products.first?.title)
            },
            products: old.items.compactMap { $0.products.first },
            stores: old.stores,
            totalMxn: old.totalMxn,
            purchased: old.purchased,
            source: .recommendation
        )
    }
}
#endif
