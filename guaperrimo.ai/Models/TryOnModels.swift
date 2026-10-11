//
//  TryOnModels.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

// MARK: - Request

nonisolated struct TryOnRequest: Codable, Sendable {
    let actionId: String
    let garmentDescription: String
}

// MARK: - Response

nonisolated struct TryOnResponse: Codable, Sendable {
    let tryonImageUrl: String
    let garmentUsed: String
}

// MARK: - State

enum TryOnState: Equatable {
    case idle
    case loading(PriorityAction)
    case result(PriorityAction, URL)
    case error(PriorityAction, String)
}
#endif
