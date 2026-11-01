//
//  ConversationEntry.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

/// One line of the running conversation, kept so the user can scroll back to what was said.
nonisolated struct ConversationEntry: Identifiable, Equatable, Sendable {
    enum Role: Sendable { case stylist, user }

    let id = UUID()
    let role: Role
    let text: String
}
#endif
