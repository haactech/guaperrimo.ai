//
//  StyleAnalysis.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

// MARK: - Request

nonisolated struct ChatRequest: Codable, Sendable {
    let type: String           // "image" | "button_response" | "voice_response"
    let imageUrl: String?      // solo type=image
    let optionId: String?      // solo type=button_response
    let transcript: String?    // solo type=voice_response
}

// MARK: - Response

nonisolated enum InputMode: String, Codable, Sendable {
    case buttons
    case voice
    case none
}

nonisolated struct ChatOption: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let label: String
}

nonisolated struct PriorityAction: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let impact: String   // "alto", "medio", "bajo"
    let effort: String   // "alto", "medio", "bajo"
}

nonisolated struct ChatResponse: Codable, Sendable {
    let sessionId: String
    let phase: String          // "discovery", "recommendation"
    let turn: Int
    let message: String
    let inputMode: InputMode
    let options: [ChatOption]?
    let isFinal: Bool
    let priorityActions: [PriorityAction]?
}
#endif
