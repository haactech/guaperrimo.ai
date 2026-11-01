//
//  UIComponentDecodingTests.swift
//  guaperrimo.aiTests
//
//  One fixture per component of the generative UI contract (ui_version 1).

import Foundation
import Testing

@testable import guaperrimo_ai

@Suite struct UIComponentDecodingTests {

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private static func response(ui: String, inputMode: String = "buttons") -> Data {
        Data(#"""
        {"session_id":"s1","phase":"discovery","turn":1,"message":"Hola","input_mode":"\#(inputMode)",
         "options":[],"is_final":false,"ui_version":1,"speech":"Hola en voz alta","ui":\#(ui)}
        """#.utf8)
    }

    private static func decodeUI(_ ui: String) throws -> [UIComponent] {
        let r = try decoder().decode(ChatResponse.self, from: response(ui: ui))
        return try #require(r.ui)
    }

    @Test func decodesEnvelope() throws {
        let r = try Self.decoder().decode(ChatResponse.self, from: Self.response(ui: "[]", inputMode: "ui"))
        #expect(r.uiVersion == 1)
        #expect(r.speech == "Hola en voz alta")
        #expect(r.inputMode == .ui)
        #expect(r.ui?.isEmpty == true)
    }

    @Test func missingUIIsNil() throws {
        let json = #"{"session_id":"s","phase":"p","turn":1,"message":"m","input_mode":"none","is_final":false}"#
        let r = try Self.decoder().decode(ChatResponse.self, from: Data(json.utf8))
        #expect(r.ui == nil)
        #expect(r.speech == nil)
    }

    @Test func decodesText() throws {
        let ui = try Self.decodeUI(#"[{"type":"text","role":"stylist","text":"Hola"},{"type":"text","role":"weird","text":"x"}]"#)
        guard case .text(let a) = ui[0], case .text(let b) = ui[1] else { Issue.record("not text"); return }
        #expect(a.role == .stylist && a.text == "Hola")
        #expect(b.role == .body)
    }

    @Test func decodesChips() throws {
        let ui = try Self.decodeUI(#"[{"type":"chips","id":"occasion","select":"single","allow_voice":true,"options":[{"id":"boda_dia","label":"Boda de día"}]}]"#)
        guard case .chips(let c) = ui[0] else { Issue.record("not chips"); return }
        #expect(c.id == "occasion" && c.allowVoice == true)
        #expect(c.options.first?.id == "boda_dia")
        #expect(ui[0].id == "chips:occasion")
    }

    @Test func decodesSlider() throws {
        let ui = try Self.decodeUI(#"[{"type":"slider","id":"budget","label":"Presupuesto","min":500,"max":10000,"step":100,"default":2500,"unit":"MXN","profile_field":"budget_mxn"}]"#)
        guard case .slider(let s) = ui[0] else { Issue.record("not slider"); return }
        #expect(s.min == 500 && s.max == 10000 && s.step == 100 && s.defaultValue == 2500)
        #expect(s.unit == "MXN" && s.profileField == "budget_mxn")
    }

    @Test func decodesPalette() throws {
        let ui = try Self.decodeUI(##"[{"type":"palette","swatches":[{"hex":"#1F2A44","name":"Azul marino"}],"avoid":[{"hex":"#000000","name":"Negro"}],"note":"Nota"}]"##)
        guard case .palette(let p) = ui[0] else { Issue.record("not palette"); return }
        #expect(p.swatches.first?.hex == "#1F2A44")
        #expect(p.avoid?.first?.name == "Negro")
        #expect(p.note == "Nota")
    }

    @Test func decodesSteps() throws {
        let ui = try Self.decodeUI(#"[{"type":"steps","items":[{"title":"Saco","detail":"Azul","product_ids":["p_1"]},{"title":"Cinturón"}]}]"#)
        guard case .steps(let s) = ui[0] else { Issue.record("not steps"); return }
        #expect(s.items.count == 2)
        #expect(s.items[0].productIds == ["p_1"])
        #expect(s.items[1].detail == nil)
    }

    @Test func decodesProductCard() throws {
        let ui = try Self.decodeUI(#"[{"type":"product_card","product_id":"p_1","title":"Camisa","price_mxn":740,"store":"H&M","image_url":"https://x/y.jpg","link":"https://x","nearby":{"name":"H&M Reforma","distance_m":450}}]"#)
        guard case .productCard(let p) = ui[0] else { Issue.record("not product"); return }
        #expect(p.productId == "p_1" && p.priceMxn == 740 && p.store == "H&M")
        #expect(p.nearby?.name == "H&M Reforma" && p.nearby?.distanceM == 450)
    }

    @Test func decodesBudgetBar() throws {
        let ui = try Self.decodeUI(#"[{"type":"budget_bar","total_mxn":2247,"budget_mxn":2500,"label":"Total aproximado"}]"#)
        guard case .budgetBar(let b) = ui[0] else { Issue.record("not budget"); return }
        #expect(b.totalMxn == 2247 && b.budgetMxn == 2500 && b.label == "Total aproximado")
    }

    @Test func unknownTypeIsTolerated() throws {
        let ui = try Self.decodeUI(#"[{"type":"hologram","foo":1},{"type":"text","role":"body","text":"ok"}]"#)
        #expect(ui.count == 2)
        guard case .unknown(let type) = ui[0] else { Issue.record("not unknown"); return }
        #expect(type == "hologram")
    }

    @Test func malformedElementDoesNotDropTheOthers() throws {
        let ui = try Self.decodeUI(#"""
        [{"type":"text","role":"body","text":"a"},
         {"type":"slider","id":"budget"},
         "garbage",
         {"no_type":true},
         {"type":"budget_bar","total_mxn":10}]
        """#)
        #expect(ui.count == 2)
        guard case .text = ui[0], case .budgetBar = ui[1] else { Issue.record("wrong survivors"); return }
    }

    @Test func uiActionRequestEncodesSnakeCase() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let request = ChatRequest(type: "ui_action", imageUrl: nil, optionId: nil, transcript: nil,
                                  componentId: "budget", value: "2500")
        let object = try #require(JSONSerialization.jsonObject(with: encoder.encode(request)) as? [String: Any])
        #expect(object["type"] as? String == "ui_action")
        #expect(object["component_id"] as? String == "budget")
        #expect(object["value"] as? String == "2500")
    }
}
