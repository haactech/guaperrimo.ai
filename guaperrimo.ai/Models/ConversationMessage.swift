//
//  ConversationMessage.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

enum MessageRole: Sendable, Equatable {
    case stylist
    case user
}

struct StyleOption: Sendable, Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
}

struct ConversationMessage: Sendable, Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    let text: String
    let options: [StyleOption]
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: MessageRole,
        text: String,
        options: [StyleOption] = [],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.options = options
        self.timestamp = timestamp
    }
}
#endif
