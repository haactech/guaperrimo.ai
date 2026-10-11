//
//  ShoppingListStore.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation
import OSLog

private let logger = Logger(subsystem: "ai.guaperrimo", category: "ShoppingList")

/// Keeps the user's saved shopping list on the device so it survives app
/// launches and does not depend on the server session still being alive.
@Observable
@MainActor
final class ShoppingListStore {
    static let shared = ShoppingListStore()

    private(set) var current: SavedShoppingList?
    private let fileURL: URL

    var hasList: Bool { current != nil }

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("shopping_list.json")
        load()
    }

    func save(_ list: SavedShoppingList) {
        current = list
        persist()
        logger.info("💾 Shopping list saved — items: \(list.items.count, privacy: .public), stores: \(list.stores.count, privacy: .public)")
    }

    func togglePurchased(_ productId: String) {
        guard var list = current else { return }
        if list.purchased.contains(productId) {
            list.purchased.remove(productId)
        } else {
            list.purchased.insert(productId)
        }
        current = list
        persist()
    }

    func clear() {
        current = nil
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            current = try decoder.decode(SavedShoppingList.self, from: data)
        } catch {
            logger.error("❌ Could not read saved list: \(String(describing: error), privacy: .public)")
        }
    }

    private func persist() {
        guard let list = current else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            try encoder.encode(list).write(to: fileURL, options: .atomic)
        } catch {
            logger.error("❌ Could not write saved list: \(String(describing: error), privacy: .public)")
        }
    }
}
#endif
