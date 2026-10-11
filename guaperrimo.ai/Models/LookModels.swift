//
//  LookModels.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

// MARK: - API DTOs (match server JSON)

nonisolated struct LooksResponse: Codable, Sendable {
    let sessionId: String
    let status: String          // "none", "pending", "generating", "partial", "ready"
    let allReady: Bool
    let readyCount: Int
    let totalCount: Int
    let looks: [LookDTO]
    let lookResults: [LookResultDTO]
}

nonisolated struct LookDTO: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let description: String
    let vibe: String
    let pieces: [LookPieceDTO]
}

nonisolated struct LookPieceDTO: Codable, Sendable {
    let slot: String
    let description: String
    let category: String
}

nonisolated struct LookResultDTO: Codable, Sendable {
    let lookId: String
    let status: String          // "pending", "generating", "ready", "failed"
    let pieces: [PieceResultDTO]
    let finalImageUrl: String?
    let errorMessage: String?
    let generationTimeMs: Int64
}

nonisolated struct PieceResultDTO: Codable, Sendable {
    let slot: String
    let productId: String?
    let productName: String?
    let productImageUrl: String?
    let tryonImageUrl: String?
    let category: String
    let generationTimeMs: Int64?
}

// MARK: - Merged view model (look + result joined for UI)

struct LookItem: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let vibe: String
    let status: String              // from lookResult
    let finalImageUrl: String?
    let errorMessage: String?
    let pieces: [LookPieceItem]

    static func == (lhs: LookItem, rhs: LookItem) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.finalImageUrl == rhs.finalImageUrl
    }
}

struct LookPieceItem: Identifiable, Equatable {
    var id: String { slot }
    let slot: String
    let slotDescription: String     // from LookDTO.pieces
    let category: String
    let productId: String?
    let productName: String?
    let productImageUrl: String?
    let tryonImageUrl: String?
}

// MARK: - Style Mirror Item

enum StyleMirrorItem: Identifiable, Equatable {
    case original(imageUrl: String)
    case look(LookItem)

    var id: String {
        switch self {
        case .original: return "original"
        case .look(let item): return item.id
        }
    }

    var imageUrl: String? {
        switch self {
        case .original(let url): return url
        case .look(let item): return item.finalImageUrl
        }
    }

    var name: String {
        switch self {
        case .original: return String(localized: "mirror_original")
        case .look(let item): return item.name
        }
    }

    var isOriginal: Bool {
        if case .original = self { return true }
        return false
    }
}

// MARK: - UI State

enum LookCarouselState: Equatable {
    case hidden       // No looks yet / not started
    case teaser       // Polling, some may still be generating
    case ready        // At least one look is ready
    case viewing      // Carousel is open
}
#endif
