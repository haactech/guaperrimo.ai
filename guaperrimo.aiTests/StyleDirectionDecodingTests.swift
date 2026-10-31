//
//  StyleDirectionDecodingTests.swift
//  guaperrimo.aiTests
//
//  Decodes a real preview chat response captured from the backend so the
//  style preview (brief + garment ideas) never breaks the chat.

import Foundation
import Testing

@testable import guaperrimo_ai

@Suite struct StyleDirectionDecodingTests {

    static let realPreviewResponse = #"""
{
 "session_id": "prev_37a9503f3fe5",
 "phase": "preview",
 "turn": 3,
 "message": "Con $2,000, te propongo prendas clave que te harán ver elegante pero fresco, sin perder comodidad. Elige las ideas que más te gusten o dime si quieres ajustar algo.",
 "input_mode": "preview",
 "options": [],
 "is_final": false,
 "location_known": false,
 "direction": {
  "brief": {
   "summary": "Por tu silueta natural y tu tono Deep Autumn, los cortes fluidos y las telas con textura te van a dar ese equilibrio entre elegante y fresco que buscas. El negro puro no es tu mejor aliado (puede apagar tu tono de piel), pero lo puedes reemplazar con tonos profundos y cálidos que harán que tu piel y tatuaje destaquen sin esfuerzo.",
   "palette": [
    {
     "name": "Verde botella",
     "hex": "#3E5641"
    },
    {
     "name": "Caramelo",
     "hex": "#B87D4F"
    },
    {
     "name": "Mostaza oscuro",
     "hex": "#D4A017"
    },
    {
     "name": "Terracota",
     "hex": "#CC6B49"
    },
    {
     "name": "Beige cálido",
     "hex": "#D4C4A6"
    }
   ],
   "avoid": [
    {
     "name": "Negro puro",
     "hex": "#000000",
     "why": "Apaga tu tono cálido y profundo"
    },
    {
     "name": "Blanco frío",
     "hex": "#FFFFFF",
     "why": "Puede verse demasiado contrastante con tu piel"
    }
   ],
   "silhouette": "Cortes rectos o ligeramente estructurados, pero nunca ajustados. Las telas con caída (como lino o algodón grueso) te dan movimiento y comodidad."
  },
  "ideas": [
   {
    "id": "idea_1",
    "slot": "upper_body",
    "garment": "Camisa de lino manga larga",
    "colors": [
     {
      "name": "Verde botella",
      "hex": "#3E5641"
     }
    ],
    "textures": [
     "lino"
    ],
    "fit": "recta, sin ajustar",
    "why": "El lino es fresco, elegante y tiene textura, ideal para una boda de día. Este color profundo resalta tu tono de piel.",
    "price_min_mxn": 700,
    "price_max_mxn": 1200,
    "reference": {
     "id": "p_61b3d6ea8c87",
     "title": "Camisa de lino verde botella de hombre hecha a medida, camisa de manga corta, camisa de lino natural, camiseta casual para hombres, camisa de lino",
     "store": "Etsy",
     "price": 1172.73,
     "currency": "MXN",
     "link": "https://www.google.com/search?ibp=oshop&q=Camisa de lino manga larga Verde botella hombre&prds=productid:5891231585818357234,headlineOfferDocid:5891231585818357234,imageDocid:14217987276535661443,rds:LO_5891231585818357234|PROD_LO_5891231585818357234,pvt:a&hl=es&gl=mx&udm=28",
     "thumbnail": "https://encrypted-tbn3.gstatic.com/shopping?q=tbn:ANd9GcRNzY_7Uie7wF3NTSjhwn1RRplbrmc2ImLzv3wRWvkzgk02UWcUsd8lckaDTAKNSZsI9o0jSAOfF0MBqWH5NFz1HduCCZXBYGWxQ7fv0h0nR4C1lX_piQjx",
     "source_id": "5891231585818357234",
     "rating": 4.6,
     "reviews": 1
    }
   },
   {
    "id": "idea_2",
    "slot": "upper_body",
    "garment": "Polo de algodón orgánico",
    "colors": [
     {
      "name": "Terracota",
      "hex": "#CC6B49"
     },
     {
      "name": "Mostaza oscuro",
      "hex": "#D4A017"
     }
    ],
    "textures": [
     "algodón orgánico"
    ],
    "fit": "slim sin ajustar",
    "why": "Un polo en estos tonos cálidos te da un look arreglado pero relajado, perfecto para no verte rígido.",
    "price_min_mxn": 500,
    "price_max_mxn": 900,
    "reference": {
     "id": "p_da1c73b817c8",
     "title": "Playera Polo Hombre Rojo Ladrillo Tipo Polo de Algodón Peinado con Elastano | Fired Brick TheSigSag Cómoda para Uso Diario Tallas S a 3XL",
     "store": "TheSigSag",
     "price": 599,
     "currency": "MXN",
     "link": "https://www.google.com/search?ibp=oshop&q=Polo de algodón orgánico Terracota hombre&prds=catalogid:9592771713222227291,productid:10632232406246652505,headlineOfferDocid:2284960040440030216,imageDocid:4566168936488967056,pvt:a&hl=es&gl=mx&udm=28",
     "thumbnail": "https://encrypted-tbn0.gstatic.com/shopping?q=tbn:ANd9GcT6GaZ6f7hsb9br160F6KsxraSWiLNH37qIK39MOJV2vK3elotkP0g7hhzPcCjv2mG6fm-zIwwXXE77EmAJvFL3UNC5J6gM20L4Tb56lr1T-xSFECN6ALhmKrQ",
     "source_id": "9592771713222227291"
    }
   },
   {
    "id": "idea_3",
    "slot": "lower_body",
    "garment": "Chinos de algodón",
    "colors": [
     {
      "name": "Beige cálido",
      "hex": "#D4C4A6"
     }
    ],
    "textures": [
     "algodón grueso"
    ],
    "fit": "recto",
    "why": "Los chinos en beige son versátiles, frescos y combinan con todo. El corte recto alarga tu silueta.",
    "price_min_mxn": 600,
    "price_max_mxn": 1000,
    "reference": {
     "id": "p_4b8302f1d1b0",
     "title": "JOHN LEOPARD Pantalon con Dobladillo para Hombre Estilo Bahamas Trouser",
     "store": "Mercado Libre",
     "price": 599,
     "currency": "MXN",
     "link": "https://www.google.com/search?ibp=oshop&q=Chinos de algodón Beige cálido hombre&prds=catalogid:8914981988399242615,productid:13546355528168091428,headlineOfferDocid:5170840573915929869,imageDocid:5622338080916016806,gpcid:16440030730243836449,mid:576462845520771131,pvt:a&hl=es&gl=mx&udm=28",
     "thumbnail": "https://encrypted-tbn2.gstatic.com/shopping?q=tbn:ANd9GcRlZffNRAtELE0kyRB4O3LvwAKtk6ULx7_Yau7C_bXaqh_O0xd7TGYYUuGNfA",
     "source_id": "8914981988399242615"
    }
   },
   {
    "id": "idea_4",
    "slot": "accessory",
    "garment": "Cinturón de cuero",
    "colors": [
     {
      "name": "Caramelo",
      "hex": "#B87D4F"
     }
    ],
    "textures": [
     "cuero liso"
    ],
    "fit": "estándar",
    "why": "Un cinturón en tono caramelo le da un toque pulido a tu outfit sin romper la armonía.",
    "price_min_mxn": 300,
    "price_max_mxn": 600,
    "reference": {
     "id": "p_2108ef0ebc57",
     "title": "Cinturón Jbe de piel para hombre Talla 32 Negro",
     "store": "Liverpool",
     "price": 313.65,
     "currency": "MXN",
     "link": "https://www.google.com/search?ibp=oshop&q=Cinturón de cuero Caramelo hombre&prds=productid:17381281973635845685,headlineOfferDocid:17381281973635845685,imageDocid:6007327693633791912,pvt:a&hl=es&gl=mx&udm=28",
     "thumbnail": "https://encrypted-tbn0.gstatic.com/shopping?q=tbn:ANd9GcTisZkdABepP_5yObPAWY_ULsdJeaHmnz-T6XaYNQabhxMETR1ArUONU481ITAaJnEvG8C63ZL4gq5fM93bCFUk477D0xfP0s-hopXxdvKiG0_m4Oorr-9CEQ",
     "source_id": "17381281973635845685"
    }
   },
   {
    "id": "idea_5",
    "slot": "accessory",
    "garment": "Reloj minimalista",
    "colors": [
     {
      "name": "Plateado",
      "hex": "#A8A9AD"
     }
    ],
    "textures": [
     "metal"
    ],
    "fit": "estándar",
    "why": "Un reloj con correa de cuero o malla en tono neutro complementa tu look sin llamar demasiado la atención.",
    "price_min_mxn": 500,
    "price_max_mxn": 1000
   }
  ],
  "round": 1,
  "created_at": "2026-10-12T19:54:25.201833-06:00"
 }
}
"""#

    private func decode(_ json: String) throws -> ChatResponse {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ChatResponse.self, from: Data(json.utf8))
    }

    @Test func decodesRealPreviewResponse() throws {
        let response = try decode(Self.realPreviewResponse)

        #expect(response.inputMode == .preview)
        #expect(response.phase == "preview")
        #expect(!response.isFinal)

        let direction = try #require(response.direction)
        #expect(direction.round == 1)
        #expect(direction.createdAt != nil)

        let brief = try #require(direction.brief)
        #expect(!brief.summary.isEmpty)
        #expect(brief.colorSeason == nil)
        #expect(brief.palette.count == 5)
        #expect(brief.palette.first?.name == "Verde botella")
        #expect(brief.avoid.count == 2)
        #expect(brief.avoid.first?.why?.isEmpty == false)
        #expect(brief.silhouette?.isEmpty == false)

        #expect(direction.ideas.map(\.id) == ["idea_1", "idea_2", "idea_3", "idea_4", "idea_5"])
        let first = direction.ideas[0]
        #expect(first.slot == "upper_body")
        #expect(first.textures == ["lino"])
        #expect(first.fit == "recta, sin ajustar")
        #expect(first.priceMinMxn == 700)
        #expect(first.priceMaxMxn == 1200)
        let reference = try #require(first.reference)
        #expect(reference.store == "Etsy")
        #expect(reference.thumbnail?.hasPrefix("https://") == true)

        // The last idea has no reference photo.
        #expect(direction.ideas[4].reference == nil)
    }

    @Test func ideasAreGroupedBySlot() throws {
        let direction = try #require(try decode(Self.realPreviewResponse).direction)
        let groups = direction.ideasBySlot
        #expect(groups.map(\.slot) == ["upper_body", "lower_body", "accessory"])
        #expect(groups[0].ideas.map(\.id) == ["idea_1", "idea_2"])
        #expect(groups[2].ideas.map(\.id) == ["idea_4", "idea_5"])
    }

    @Test func partialPayloadNeverBreaksTheChat() throws {
        let json = #"""
        {"session_id":"s","phase":"preview","turn":1,"message":"Hola","input_mode":"preview","is_final":false,
         "direction":{
           "brief":{"palette":[{"name":"Azul"},{"name":"Gris","hex":""}]},
           "ideas":[
             {"id":"idea_1","slot":"outerwear","garment":"Chamarra"},
             {"slot":"lower_body"},
             {"id":"idea_2","slot":"upper_body","garment":"Playera","colors":[{"name":"Blanco"}],
              "price_min_mxn":"barato","reference":{"title":"sin precio"}}
           ]
         }}
        """#
        let response = try decode(json)
        let direction = try #require(response.direction)
        #expect(direction.round == 1)
        #expect(direction.brief?.summary == "")
        #expect(direction.brief?.palette.allSatisfy { $0.rgb == nil } == true)
        // The malformed idea is dropped; the rest survive.
        #expect(direction.ideas.map(\.id) == ["idea_1", "idea_2"])
        #expect(direction.ideas[1].priceMinMxn == nil)
        #expect(direction.ideas[1].reference == nil)
        #expect(direction.ideasBySlot.map(\.slot) == ["upper_body", "outerwear"])
    }

    @Test func swatchHexParsing() {
        let rgb = ColorSwatchDTO(name: "Caramelo", hex: "#B87D4F").rgb
        #expect(rgb != nil)
        #expect(abs((rgb?.red ?? 0) - 184.0 / 255) < 0.0001)
        #expect(ColorSwatchDTO(name: "x", hex: "FFFFFF").rgb != nil)
        #expect(ColorSwatchDTO(name: "x", hex: "#zzzzzz").rgb == nil)
        #expect(ColorSwatchDTO(name: "x").rgb == nil)
    }

    @Test func priceRangeIsInPesos() {
        #expect(mxnRangeLabel(min: 700, max: 1200) == "$700–1,200 MXN")
        #expect(mxnRangeLabel(min: 500, max: 500) == "$500 MXN")
        #expect(mxnRangeLabel(min: nil, max: nil) == nil)
        #expect(mxnRangeLabel(min: 300, max: nil)?.hasSuffix("$300 MXN") == true)
        #expect(mxnRangeLabel(min: nil, max: 1000)?.hasSuffix("$1,000 MXN") == true)
    }

    @Test func ideaSelectionRequestEncodesSnakeCase() throws {
        let request = ChatRequest(
            type: "idea_selection", imageUrl: nil, optionId: nil, transcript: nil,
            selectedIdeas: ["idea_1", "idea_3"], text: "más casual"
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let object = try #require(JSONSerialization.jsonObject(with: encoder.encode(request)) as? [String: Any])
        #expect(object["type"] as? String == "idea_selection")
        #expect(object["selected_ideas"] as? [String] == ["idea_1", "idea_3"])
        #expect(object["text"] as? String == "más casual")
        #expect(object["image_url"] == nil)
    }
}
