//
//  SavedLooksStore.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation
import OSLog

private let logger = Logger(subsystem: "ai.guaperrimo", category: "SavedLooks")

/// Keeps the user's saved looks on the device so they survive app launches and
/// do not depend on the server session still being alive.
@Observable
@MainActor
final class SavedLooksStore {
    static let shared = SavedLooksStore()

    /// Newest first.
    private(set) var looks: [SavedLook] = []
    private let fileURL: URL
    private let legacyFileURL: URL

    var hasLooks: Bool { !looks.isEmpty }

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("saved_looks.json")
        legacyFileURL = base.appendingPathComponent("shopping_list.json")
        load()
        migrateLegacyList()
    }

    func isSaved(sessionId: String, name: String) -> Bool {
        looks.contains { $0.sessionId == sessionId && $0.name == name }
    }

    /// Adds the look, replacing a previous one from the same session with the same name.
    func add(_ look: SavedLook) {
        var kept = look
        if let existing = looks.first(where: { $0.sessionId == look.sessionId && $0.name == look.name }) {
            kept.purchased = existing.purchased.union(look.purchased)
        }
        looks.removeAll { $0.sessionId == look.sessionId && $0.name == look.name }
        looks.insert(kept, at: 0)
        persist()
        logger.info("Look saved — products: \(look.products.count, privacy: .public), total: \(self.looks.count, privacy: .public)")
    }

    func remove(id: String) {
        looks.removeAll { $0.id == id }
        persist()
    }

    func togglePurchased(lookId: String, productId: String) {
        guard let index = looks.firstIndex(where: { $0.id == lookId }) else { return }
        if looks[index].purchased.contains(productId) {
            looks[index].purchased.remove(productId)
        } else {
            looks[index].purchased.insert(productId)
        }
        persist()
    }

    /// Marks (or unmarks) a product in every look that contains it; Compras shows each product once.
    func setPurchased(_ purchased: Bool, productId: String) {
        for index in looks.indices where looks[index].products.contains(where: { $0.id == productId }) {
            if purchased {
                looks[index].purchased.insert(productId)
            } else {
                looks[index].purchased.remove(productId)
            }
        }
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            looks = try decoder.decode([SavedLook].self, from: data)
        } catch {
            logger.error("Could not read saved looks: \(String(describing: error), privacy: .public)")
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            try encoder.encode(looks).write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Could not write saved looks: \(String(describing: error), privacy: .public)")
        }
    }

    /// One time: imports the old single shopping list as a look, then deletes the old file.
    private func migrateLegacyList() {
        guard let data = try? Data(contentsOf: legacyFileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let old = try? decoder.decode(SavedShoppingList.self, from: data) else {
            logger.error("Legacy shopping list unreadable; keeping the file")
            return
        }
        let migrated = SavedLook(migrating: old)
        if !looks.contains(where: { $0.sessionId == migrated.sessionId && $0.name == migrated.name }) {
            looks.append(migrated)
            looks.sort { $0.savedAt > $1.savedAt }
            persist()
        }
        try? FileManager.default.removeItem(at: legacyFileURL)
        logger.info("Migrated legacy shopping list into Mis looks")
    }
}
#endif
