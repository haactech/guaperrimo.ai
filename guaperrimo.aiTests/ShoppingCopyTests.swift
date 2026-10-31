//
//  ShoppingCopyTests.swift
//  guaperrimo.aiTests
//
//  The backend writes product descriptions for the LLM ("**Precio: $539**");
//  "Mi lista" must show them clean.

import Foundation
import Testing

@testable import guaperrimo_ai

@Suite struct ShoppingCopyTests {

    @Test func stripsTrailingPriceNoteAndEmphasis() {
        let raw = "Saco azul marino slim (talla M o L según tu complexión). **Precio: $539**"
        #expect(cleanStylistCopy(raw) == "Saco azul marino slim (talla M o L según tu complexión).")
    }

    @Test func stripsPriceNoteWithCurrencyAndInlineEmphasis() {
        let raw = "Camisa **beige** de lino. Precio: $740 MXN."
        #expect(cleanStylistCopy(raw) == "Camisa beige de lino.")
    }

    @Test func leavesPlainCopyUntouched() {
        let raw = "Cinturón café de piel (talla ajustable)."
        #expect(cleanStylistCopy(raw) == raw)
    }

    @Test func priceAndStoreLabelSkipsEmptyStore() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ChatResponse.self, from: Data(ShoppingListDecodingTests.realFinalResponse.utf8))
        let products = try #require(response.shoppingList).flatMap(\.products)
        let noStore = try #require(products.first { $0.store.isEmpty })
        #expect(noStore.priceAndStoreLabel == noStore.priceLabel)
        let withStore = try #require(products.first { !$0.store.isEmpty })
        #expect(withStore.priceAndStoreLabel == "\(withStore.priceLabel) · \(withStore.store)")
    }

    @Test func displayDescriptionOfRealPayloadHasNoMarkdown() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ChatResponse.self, from: Data(ShoppingListDecodingTests.realFinalResponse.utf8))
        let items = try #require(response.shoppingList)
        #expect(!items.isEmpty)
        for item in items {
            #expect(!item.displayDescription.contains("**"))
            #expect(!item.displayDescription.contains("Precio:"))
            #expect(!item.displayDescription.isEmpty)
        }
    }
}
