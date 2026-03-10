//
//  ConversationMessage.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

nonisolated enum MessageRole: Sendable, Equatable {
    case stylist
    case user
}

nonisolated struct ConversationMessage: Sendable, Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    let text: String
    let options: [ChatOption]
    let inputMode: InputMode
    let priorityActions: [PriorityAction]
    let isFinal: Bool
    let timestamp: Date

    init(
        id: UUID = UUID(),
        role: MessageRole,
        text: String,
        options: [ChatOption] = [],
        inputMode: InputMode = .none,
        priorityActions: [PriorityAction] = [],
        isFinal: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.options = options
        self.inputMode = inputMode
        self.priorityActions = priorityActions
        self.isFinal = isFinal
        self.timestamp = timestamp
    }
}
#endif
