//
//  ShoppingListDecodingTests.swift
//  guaperrimo.aiTests
//
//  Decodes a real final chat response captured from the backend so the
//  shopping-list fields never break the final screen.

import Foundation
import Testing

@testable import guaperrimo_ai

@Suite struct ShoppingListDecodingTests {

    static let realFinalResponse = #"""
{"session_id":"712bd6de-f590-484c-b022-ca99eccff43b","phase":"done","turn":2,"message":"Vamos a ajustar el presupuesto para que todo quede dentro de tus $2500. Lo más importante es el saco y la camisa: con eso ya tienes el 80% del look. Los zapatos y el cinturón los puedes conseguir en tiendas locales o ajustar tallas para ahorrar.","input_mode":"none","options":[],"is_final":true,"location_known":true,"priority_actions":[{"id":"comprar_saco_azul","title":"Saco azul marino","description":"Un saco azul marino slim (ajustado sin apretar) para darle estructura a tu silueta natural y un toque formal. Prioriza este artículo.","impact":"alto","effort":"bajo","product_ids":["p_064015a902c4"]},{"id":"comprar_camisa_beige","title":"Camisa beige de lino","description":"Una camisa beige de lino slim para mantener la frescura y combinar con todo. Si no encuentras lino, algodón también funciona.","impact":"alto","effort":"bajo","product_ids":["p_b37d9143831a"]},{"id":"comprar_zapatos_cafe","title":"Zapatos derby café","description":"Unos zapatos derby café (color café medio) para combinar con el saco y la camisa. Si no encuentras baratos, usa unos negros que ya tengas.","impact":"medio","effort":"bajo"},{"id":"evitar_negro_total","title":"Romper el negro","description":"Evita el negro total: el beige y el azul marino te harán ver más fresco y menos serio.","impact":"medio","effort":"bajo"}],"shopping_list":[{"slot":"outerwear","description":"Saco azul marino slim (talla M o L según tu complexión). Busca uno sin hombreras exageradas para mantener tu silueta natural. **Precio: $539**","why":"El azul marino es elegante pero no tan formal como el negro, ideal para una boda de día.","priority":1,"products":[{"id":"p_064015a902c4","title":"Saco de Gabardina Cierres Liso Caballero","store":"Mercado Libre","price":539,"currency":"MXN","link":"https://www.google.com/search?ibp=oshop\u0026q=Zara saco azul marino slim hombre\u0026prds=catalogid:8547494588729153697,productid:5713049164118440313,headlineOfferDocid:1601370568101595153,imageDocid:990097763832754238,gpcid:14806556471382909817,mid:576462834762831481,pvt:a\u0026hl=es\u0026gl=mx\u0026udm=28","thumbnail":"https://encrypted-tbn2.gstatic.com/shopping?q=tbn:ANd9GcQgAdheA7kGWb_efibJu3VC9L-9hVgAbgTdJBIapCCEdvONPw-dGpo2xUn5E_B8MAsxZJDmjHI","source_id":"8547494588729153697"}]},{"slot":"upper_body","description":"Camisa beige de lino slim (talla M o L). Si no encuentras lino, algodón también funciona. **Precio: $740**","why":"El beige contrasta con tu estilo actual y el lino te mantiene fresco.","priority":2,"products":[{"id":"p_b37d9143831a","title":"Hombres - Beige Camisa Regular Fit Easy-Care en mezcla de lino - Talla: CH - H\u0026M","store":"","price":740,"currency":"MXN","link":"","thumbnail":"https://encrypted-tbn3.gstatic.com/shopping?q=tbn:ANd9GcT38NrA3KQQfkw16TwW66m-OynPcNSC6paNJTx3ZkXKhF_pc5C-yjZACVZ_dlwIOX8bjDxRWc8oH5n7Wn7uM-BTJ3KPFzRe0M3nI8rBeOGphT-B4nI6QmYKWg","source_id":"16900517190788513946","rating":3.2,"reviews":77}]},{"slot":"lower_body","description":"Pantalón beige o gris claro slim (talla 30-34). Si ya tienes unos negros, úsalos, pero evita que sean demasiado ajustados. **Precio: $679**","why":"El beige o gris claro combinan con el saco y la camisa, manteniendo el look fresco.","priority":3,"products":[{"id":"p_d6b1eba59458","title":"Hombres H\u0026M Pantalón de traje Regular Fit","store":"H\u0026M","price":679,"currency":"MXN","link":"https://www.google.com/search?ibp=oshop\u0026q=H\u0026M pantalón de vestir beige slim hombre\u0026prds=catalogid:11087213342554730945,productid:11743377030785728207,headlineOfferDocid:10351349833869533503,imageDocid:17800477683140606873,rds:PC_2234460374103695322|PROD_PC_2234460374103695322,gpcid:3945896846375778049,mid:576462872541636110,pvt:a\u0026hl=es\u0026gl=mx\u0026udm=28","thumbnail":"https://encrypted-tbn1.gstatic.com/shopping?q=tbn:ANd9GcT-_RCCP742P9QyGviwGXejLFR8bAC4MiIBHrQrQ2mEtEWkKOR0opoyj8d89M35b-3odJ0hENdhN8fML6v6JN48Ap54lij7VssHCE7nFYIjjOYZ7pjphFkf","source_id":"11087213342554730945","rating":3.6,"reviews":1,"tags":["OFERTA"]}]},{"slot":"accessory","description":"Cinturón café de piel (talla ajustable). **Precio: $289**","why":"Un cinturón café une el look y le da un toque pulido.","priority":4,"products":[{"id":"p_2298c73463ef","title":"Señoras H\u0026M Café Cinturón","store":"H\u0026M","price":289,"currency":"MXN","link":"https://www.google.com/search?ibp=oshop\u0026q=H\u0026M cinturón café piel hombre\u0026prds=catalogid:11055011120856876116,productid:9045684364053319745,headlineOfferDocid:7127240612694630982,imageDocid:18149279604659351212,rds:PC_1148750587890713688|PROD_PC_1148750587890713688,gpcid:1148750587890713688,mid:576462567542886857,pvt:a\u0026hl=es\u0026gl=mx\u0026udm=28","thumbnail":"https://encrypted-tbn0.gstatic.com/shopping?q=tbn:ANd9GcSo7h4P5BCxqmDdwKNAG14uYFCvbzd-WkdmhOBRMqjHaDGSw1szLH5E2vWhZ7ry1HJ93f8KJSNobOpjZAUFwKBF7WqiJSQOe5CTLWwl6qx_4qFNU8meUilXEg","source_id":"11055011120856876116","rating":2.4,"reviews":3800,"tags":["PRECIO BAJO"]}]}],"products":[{"id":"p_064015a902c4","title":"Saco de Gabardina Cierres Liso Caballero","store":"Mercado Libre","price":539,"currency":"MXN","link":"https://www.google.com/search?ibp=oshop\u0026q=Zara saco azul marino slim hombre\u0026prds=catalogid:8547494588729153697,productid:5713049164118440313,headlineOfferDocid:1601370568101595153,imageDocid:990097763832754238,gpcid:14806556471382909817,mid:576462834762831481,pvt:a\u0026hl=es\u0026gl=mx\u0026udm=28","thumbnail":"https://encrypted-tbn2.gstatic.com/shopping?q=tbn:ANd9GcQgAdheA7kGWb_efibJu3VC9L-9hVgAbgTdJBIapCCEdvONPw-dGpo2xUn5E_B8MAsxZJDmjHI","source_id":"8547494588729153697"},{"id":"p_b37d9143831a","title":"Hombres - Beige Camisa Regular Fit Easy-Care en mezcla de lino - Talla: CH - H\u0026M","store":"","price":740,"currency":"MXN","link":"","thumbnail":"https://encrypted-tbn3.gstatic.com/shopping?q=tbn:ANd9GcT38NrA3KQQfkw16TwW66m-OynPcNSC6paNJTx3ZkXKhF_pc5C-yjZACVZ_dlwIOX8bjDxRWc8oH5n7Wn7uM-BTJ3KPFzRe0M3nI8rBeOGphT-B4nI6QmYKWg","source_id":"16900517190788513946","rating":3.2,"reviews":77},{"id":"p_d6b1eba59458","title":"Hombres H\u0026M Pantalón de traje Regular Fit","store":"H\u0026M","price":679,"currency":"MXN","link":"https://www.google.com/search?ibp=oshop\u0026q=H\u0026M pantalón de vestir beige slim hombre\u0026prds=catalogid:11087213342554730945,productid:11743377030785728207,headlineOfferDocid:10351349833869533503,imageDocid:17800477683140606873,rds:PC_2234460374103695322|PROD_PC_2234460374103695322,gpcid:3945896846375778049,mid:576462872541636110,pvt:a\u0026hl=es\u0026gl=mx\u0026udm=28","thumbnail":"https://encrypted-tbn1.gstatic.com/shopping?q=tbn:ANd9GcT-_RCCP742P9QyGviwGXejLFR8bAC4MiIBHrQrQ2mEtEWkKOR0opoyj8d89M35b-3odJ0hENdhN8fML6v6JN48Ap54lij7VssHCE7nFYIjjOYZ7pjphFkf","source_id":"11087213342554730945","rating":3.6,"reviews":1,"tags":["OFERTA"]},{"id":"p_2298c73463ef","title":"Señoras H\u0026M Café Cinturón","store":"H\u0026M","price":289,"currency":"MXN","link":"https://www.google.com/search?ibp=oshop\u0026q=H\u0026M cinturón café piel hombre\u0026prds=catalogid:11055011120856876116,productid:9045684364053319745,headlineOfferDocid:7127240612694630982,imageDocid:18149279604659351212,rds:PC_1148750587890713688|PROD_PC_1148750587890713688,gpcid:1148750587890713688,mid:576462567542886857,pvt:a\u0026hl=es\u0026gl=mx\u0026udm=28","thumbnail":"https://encrypted-tbn0.gstatic.com/shopping?q=tbn:ANd9GcSo7h4P5BCxqmDdwKNAG14uYFCvbzd-WkdmhOBRMqjHaDGSw1szLH5E2vWhZ7ry1HJ93f8KJSNobOpjZAUFwKBF7WqiJSQOe5CTLWwl6qx_4qFNU8meUilXEg","source_id":"11055011120856876116","rating":2.4,"reviews":3800,"tags":["PRECIO BAJO"]}],"total_mxn":2247,"looks_generating":true,"matrix_available":true}
"""#

    @Test func decodesRealFinalResponse() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ChatResponse.self, from: Data(Self.realFinalResponse.utf8))

        #expect(response.isFinal)
        let items = try #require(response.shoppingList)
        #expect(!items.isEmpty)
        let withProduct = items.first { !$0.products.isEmpty }
        let product = try #require(withProduct?.products.first)
        #expect(product.price > 0)
        #expect(!product.store.isEmpty)
        #expect(response.totalMxn ?? 0 > 0)
        #expect(response.matrixAvailable == true)
    }

    @Test func savedListRoundTripsThroughJSON() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ChatResponse.self, from: Data(Self.realFinalResponse.utf8))
        var list = SavedShoppingList(
            sessionId: response.sessionId, savedAt: Date(), summary: response.message,
            items: response.shoppingList ?? [], stores: response.stores ?? [],
            totalMxn: response.totalMxn ?? 0, purchased: []
        )
        list.purchased.insert(list.items[0].products.first?.id ?? "x")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(list)
        let back = try { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return try d.decode(SavedShoppingList.self, from: data) }()
        #expect(back.items.count == list.items.count)
        #expect(back.purchased == list.purchased)
    }

    @Test func slotLabelsAreLocalized() {
        #expect(!slotLabel("upper_body").isEmpty)
        #expect(distanceLabel(640) == "640 m")
        #expect(distanceLabel(1250) == "1.2 km" || distanceLabel(1250) == "1,2 km")
    }
}
