//
//  ShoppingBasket.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

/// The "Compras" tab: the products of every saved look, once each, grouped by nearby store.
nonisolated struct ShoppingBasket: Equatable {
    struct Entry: Identifiable, Equatable {
        var id: String { product.id }
        let product: ProductDTO
        let store: StoreDTO?
        let purchased: Bool
    }

    struct Group: Identifiable, Equatable {
        /// nil for the "En línea" group.
        let store: StoreDTO?
        let entries: [Entry]
        var id: String { store?.placeId ?? "online" }
    }

    /// Nearby stores by distance, then online.
    let pending: [Group]
    let purchased: [Entry]

    var pendingEntries: [Entry] { pending.flatMap(\.entries) }
    var totalMxn: Double { pendingEntries.reduce(0) { $0 + $1.product.price } }
    var itemCount: Int { pendingEntries.count }
    var nearbyStoreCount: Int { pending.filter { $0.store != nil }.count }
    var isEmpty: Bool { pendingEntries.isEmpty && purchased.isEmpty }

    /// `looks` newest first; the newest look wins when a product is in several.
    init(looks: [SavedLook]) {
        var seen = Set<String>()
        var entries: [Entry] = []
        for look in looks {
            for product in look.products where !seen.contains(product.id) {
                seen.insert(product.id)
                let isPurchased = looks.contains { $0.purchased.contains(product.id) }
                entries.append(Entry(product: product, store: look.store(for: product), purchased: isPurchased))
            }
        }

        let open = entries.filter { !$0.purchased }
        var byStore: [String: [Entry]] = [:]
        var stores: [String: StoreDTO] = [:]
        var online: [Entry] = []
        for entry in open {
            if let store = entry.store {
                byStore[store.placeId, default: []].append(entry)
                stores[store.placeId] = store
            } else {
                online.append(entry)
            }
        }
        var groups = stores.values
            .sorted { ($0.distanceM, $0.name) < ($1.distanceM, $1.name) }
            .map { Group(store: $0, entries: byStore[$0.placeId] ?? []) }
        if !online.isEmpty { groups.append(Group(store: nil, entries: online)) }
        pending = groups
        purchased = entries.filter(\.purchased)
    }
}

/// Google Shopping links are searches, not a store page: they say "Ver producto", not "Comprar" (G-5).
nonisolated func isDirectStoreLink(_ link: String) -> Bool {
    guard let host = URL(string: link)?.host?.lowercased() else { return false }
    return !(host == "google.com" || host.hasSuffix(".google.com"))
}
#endif
