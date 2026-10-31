//
//  StyleDirectionModels.swift
//  guaperrimo.ai
//
//  The "style preview" the stylist shows before searching products:
//  a short style brief (palette, colors to avoid, silhouette) and a few
//  garment ideas the user picks from. Decoding is deliberately lenient:
//  everything except id/slot/garment is optional so a partial payload
//  never breaks the chat.

#if os(iOS)
import Foundation

// MARK: - DTOs

nonisolated struct ColorSwatchDTO: Codable, Sendable, Equatable, Hashable {
    let name: String
    let hex: String?
    let why: String?

    init(name: String, hex: String? = nil, why: String? = nil) {
        self.name = name
        self.hex = hex
        self.why = why
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        hex = try? c.decodeIfPresent(String.self, forKey: .hex)
        why = try? c.decodeIfPresent(String.self, forKey: .why)
    }

    /// RGB components (0...1) parsed from `hex` ("#RRGGBB" or "RRGGBB"); nil when missing or invalid.
    var rgb: (red: Double, green: Double, blue: Double)? {
        guard var value = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        if value.hasPrefix("#") { value.removeFirst() }
        if value.count == 3 { value = value.map { "\($0)\($0)" }.joined() }
        guard value.count == 6, let int = UInt32(value, radix: 16) else { return nil }
        return (
            Double((int >> 16) & 0xFF) / 255,
            Double((int >> 8) & 0xFF) / 255,
            Double(int & 0xFF) / 255
        )
    }
}

nonisolated struct StyleBriefDTO: Codable, Sendable, Equatable {
    let summary: String
    let colorSeason: String?
    let palette: [ColorSwatchDTO]
    let avoid: [ColorSwatchDTO]
    let silhouette: String?

    init(summary: String, colorSeason: String? = nil, palette: [ColorSwatchDTO] = [], avoid: [ColorSwatchDTO] = [], silhouette: String? = nil) {
        self.summary = summary
        self.colorSeason = colorSeason
        self.palette = palette
        self.avoid = avoid
        self.silhouette = silhouette
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = (try? c.decodeIfPresent(String.self, forKey: .summary)) ?? ""
        colorSeason = try? c.decodeIfPresent(String.self, forKey: .colorSeason)
        palette = (try? c.decodeIfPresent([ColorSwatchDTO].self, forKey: .palette)) ?? []
        avoid = (try? c.decodeIfPresent([ColorSwatchDTO].self, forKey: .avoid)) ?? []
        silhouette = try? c.decodeIfPresent(String.self, forKey: .silhouette)
    }
}

nonisolated struct StyleIdeaDTO: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let slot: String           // upper_body | outerwear | lower_body | accessory
    let garment: String
    let colors: [ColorSwatchDTO]
    let textures: [String]
    let fit: String?
    let why: String?
    let priceMinMxn: Double?
    let priceMaxMxn: Double?
    let reference: ProductDTO?

    init(
        id: String, slot: String, garment: String, colors: [ColorSwatchDTO] = [], textures: [String] = [],
        fit: String? = nil, why: String? = nil, priceMinMxn: Double? = nil, priceMaxMxn: Double? = nil,
        reference: ProductDTO? = nil
    ) {
        self.id = id
        self.slot = slot
        self.garment = garment
        self.colors = colors
        self.textures = textures
        self.fit = fit
        self.why = why
        self.priceMinMxn = priceMinMxn
        self.priceMaxMxn = priceMaxMxn
        self.reference = reference
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        slot = try c.decode(String.self, forKey: .slot)
        garment = try c.decode(String.self, forKey: .garment)
        colors = (try? c.decodeIfPresent([ColorSwatchDTO].self, forKey: .colors)) ?? []
        textures = (try? c.decodeIfPresent([String].self, forKey: .textures)) ?? []
        fit = try? c.decodeIfPresent(String.self, forKey: .fit)
        why = try? c.decodeIfPresent(String.self, forKey: .why)
        priceMinMxn = try? c.decodeIfPresent(Double.self, forKey: .priceMinMxn)
        priceMaxMxn = try? c.decodeIfPresent(Double.self, forKey: .priceMaxMxn)
        // A malformed reference product only loses the photo, never the idea.
        reference = try? c.decodeIfPresent(ProductDTO.self, forKey: .reference)
    }

    /// "$700–1,200 MXN", "Desde $700 MXN", "Hasta $1,200 MXN" or nil.
    var priceRangeLabel: String? {
        mxnRangeLabel(min: priceMinMxn, max: priceMaxMxn)
    }
}

nonisolated struct StyleDirectionDTO: Codable, Sendable, Equatable {
    let brief: StyleBriefDTO?
    let ideas: [StyleIdeaDTO]
    let round: Int
    let selected: [String]?
    let rejected: [String]?
    let feedback: String?
    let createdAt: String?
    let chosenAt: String?

    init(
        brief: StyleBriefDTO?, ideas: [StyleIdeaDTO], round: Int = 1, selected: [String]? = nil,
        rejected: [String]? = nil, feedback: String? = nil, createdAt: String? = nil, chosenAt: String? = nil
    ) {
        self.brief = brief
        self.ideas = ideas
        self.round = round
        self.selected = selected
        self.rejected = rejected
        self.feedback = feedback
        self.createdAt = createdAt
        self.chosenAt = chosenAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        brief = try? c.decodeIfPresent(StyleBriefDTO.self, forKey: .brief)
        // Drop individual ideas that are malformed instead of failing the whole turn.
        ideas = (try? c.decodeIfPresent([LenientIdea].self, forKey: .ideas))?.compactMap(\.idea) ?? []
        round = (try? c.decodeIfPresent(Int.self, forKey: .round)) ?? 1
        selected = try? c.decodeIfPresent([String].self, forKey: .selected)
        rejected = try? c.decodeIfPresent([String].self, forKey: .rejected)
        feedback = try? c.decodeIfPresent(String.self, forKey: .feedback)
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        chosenAt = try? c.decodeIfPresent(String.self, forKey: .chosenAt)
    }

    /// Ideas ordered by slot (Arriba, Encima, Abajo, Calzado, Accesorios), stable within a slot.
    var ideasBySlot: [StyleIdeaGroup] {
        var order: [String] = []
        var groups: [String: [StyleIdeaDTO]] = [:]
        for idea in ideas {
            if groups[idea.slot] == nil { order.append(idea.slot) }
            groups[idea.slot, default: []].append(idea)
        }
        let rank = { (slot: String) -> Int in previewSlotOrder.firstIndex(of: slot) ?? previewSlotOrder.count }
        return order
            .enumerated()
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map { StyleIdeaGroup(slot: $0.element, ideas: groups[$0.element] ?? []) }
    }
}

nonisolated struct StyleIdeaGroup: Sendable, Identifiable, Equatable {
    var id: String { slot }
    let slot: String
    let ideas: [StyleIdeaDTO]
}

private nonisolated struct LenientIdea: Decodable, Sendable {
    let idea: StyleIdeaDTO?
    init(from decoder: Decoder) throws {
        idea = try? StyleIdeaDTO(from: decoder)
    }
}

// MARK: - Helpers

nonisolated let previewSlotOrder = ["upper_body", "outerwear", "lower_body", "footwear", "accessory"]

/// Section title for a slot in the preview (plural for accessories).
nonisolated func previewSlotTitle(_ slot: String) -> String {
    slot == "accessory" ? String(localized: "preview_slot_accessories") : slotLabel(slot)
}

/// Formats an MXN amount with Mexican grouping: 1200 -> "1,200".
nonisolated func mxnAmount(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "es_MX")
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value.rounded()))"
}

/// Price range in pesos: "$700–1,200 MXN"; one-sided ranges read "Desde"/"Hasta".
nonisolated func mxnRangeLabel(min: Double?, max: Double?) -> String? {
    let lo = min.flatMap { $0 > 0 ? $0 : nil }
    let hi = max.flatMap { $0 > 0 ? $0 : nil }
    switch (lo, hi) {
    case let (lo?, hi?) where lo.rounded() == hi.rounded():
        return "$\(mxnAmount(lo)) MXN"
    case let (lo?, hi?):
        return "$\(mxnAmount(Swift.min(lo, hi)))–\(mxnAmount(Swift.max(lo, hi))) MXN"
    case let (lo?, nil):
        return "\(String(localized: "preview_price_from")) $\(mxnAmount(lo)) MXN"
    case let (nil, hi?):
        return "\(String(localized: "preview_price_up_to")) $\(mxnAmount(hi)) MXN"
    default:
        return nil
    }
}
#endif
