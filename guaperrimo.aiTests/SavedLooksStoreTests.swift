//
//  SavedLooksStoreTests.swift
//  guaperrimo.aiTests
//

import Foundation
import Testing

@testable import guaperrimo_ai

@MainActor
@Suite struct SavedLooksStoreTests {

    private func tempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("saved-looks-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func realResponse() throws -> ChatResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ChatResponse.self, from: Data(ShoppingListDecodingTests.realFinalResponse.utf8))
    }

    private func makeLook(sessionId: String = "s1", name: String = "Casual elevado", savedAt: Date = Date()) throws -> SavedLook {
        let response = try realResponse()
        let items = response.shoppingList ?? []
        return SavedLook(
            sessionId: sessionId, savedAt: savedAt, name: name, description: "Un look fácil",
            finalImageUrl: "https://example.com/look.jpg", originalImageUrl: "https://example.com/me.jpg",
            pieces: items.map { SavedLookPiece(slot: $0.slot, slotDescription: $0.displayDescription, productName: $0.products.first?.title) },
            products: items.compactMap { $0.products.first },
            stores: response.stores ?? [], totalMxn: response.totalMxn ?? 0, source: .look
        )
    }

    @Test func roundTripsThroughDisk() throws {
        let dir = tempDirectory()
        let look = try makeLook()
        SavedLooksStore(directory: dir).add(look)

        let reloaded = SavedLooksStore(directory: dir)
        #expect(reloaded.looks.count == 1)
        #expect(reloaded.looks[0].id == look.id)
        #expect(reloaded.looks[0].finalImageUrl == look.finalImageUrl)
        #expect(reloaded.looks[0].products == look.products)
        #expect(reloaded.looks[0].stores == look.stores)
        #expect(reloaded.looks[0].source == .look)
        #expect(reloaded.hasLooks)
    }

    @Test func newestFirstAndReplaceOnSameSessionAndName() throws {
        let store = SavedLooksStore(directory: tempDirectory())
        let first = try makeLook(name: "A")
        let other = try makeLook(name: "B")
        let again = try makeLook(name: "A")
        store.add(first)
        store.add(other)
        #expect(store.looks.map(\.name) == ["B", "A"])
        store.add(again)
        #expect(store.looks.count == 2)
        #expect(store.looks.map(\.name) == ["A", "B"])
        #expect(store.looks[0].id == again.id)
        #expect(store.isSaved(sessionId: "s1", name: "A"))
        #expect(!store.isSaved(sessionId: "s2", name: "A"))
    }

    @Test func replacingKeepsPurchasedMarks() throws {
        let store = SavedLooksStore(directory: tempDirectory())
        let look = try makeLook()
        store.add(look)
        let productId = try #require(look.products.first?.id)
        store.togglePurchased(lookId: look.id, productId: productId)
        store.add(try makeLook())
        #expect(store.looks.count == 1)
        #expect(store.looks[0].purchased.contains(productId))
    }

    @Test func togglePurchasedAndRemove() throws {
        let dir = tempDirectory()
        let store = SavedLooksStore(directory: dir)
        let look = try makeLook()
        store.add(look)
        let productId = try #require(look.products.first?.id)

        store.togglePurchased(lookId: look.id, productId: productId)
        #expect(store.looks[0].purchased == [productId])
        #expect(SavedLooksStore(directory: dir).looks[0].purchased == [productId])
        store.togglePurchased(lookId: look.id, productId: productId)
        #expect(store.looks[0].purchased.isEmpty)

        store.remove(id: look.id)
        #expect(!store.hasLooks)
        #expect(SavedLooksStore(directory: dir).looks.isEmpty)
    }

    @Test func migratesTheOldShoppingListOnce() throws {
        let dir = tempDirectory()
        let response = try realResponse()
        let old = SavedShoppingList(
            sessionId: response.sessionId, savedAt: Date(timeIntervalSince1970: 1_700_000_000),
            summary: "Look casual para una cena. Combina lino con tonos neutros.",
            items: response.shoppingList ?? [], stores: response.stores ?? [],
            totalMxn: response.totalMxn ?? 0, purchased: ["p1"]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let legacy = dir.appendingPathComponent("shopping_list.json")
        try encoder.encode(old).write(to: legacy)

        let store = SavedLooksStore(directory: dir)
        #expect(store.looks.count == 1)
        let look = store.looks[0]
        #expect(look.name == "Look casual para una cena")
        #expect(look.source == .recommendation)
        #expect(look.originalImageUrl == nil)
        #expect(look.purchased == ["p1"])
        #expect(look.savedAt == old.savedAt)
        #expect(look.products.count == old.items.compactMap { $0.products.first }.count)
        #expect(!FileManager.default.fileExists(atPath: legacy.path))

        // A second launch finds no legacy file and keeps the migrated look.
        #expect(SavedLooksStore(directory: dir).looks.count == 1)
    }

    @Test func planNameUsesShortFirstSentenceElseDefault() {
        #expect(SavedLook.planName(from: "Smart casual para hoy. Más texto.") == "Smart casual para hoy")
        #expect(SavedLook.planName(from: String(repeating: "palabra ", count: 20)) == String(localized: "mylooks_default_plan_name"))
        #expect(SavedLook.planName(from: "") == String(localized: "mylooks_default_plan_name"))
    }
}
