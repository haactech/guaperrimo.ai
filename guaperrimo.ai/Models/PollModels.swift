//
//  PollModels.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

// MARK: - "Ask someone": a two-look poll shared by link (match server JSON)

nonisolated struct CreatePollRequest: Encodable, Sendable {
    let lookIds: [String]
}

nonisolated struct PollListResponse: Codable, Sendable {
    let polls: [LookPoll]
}

nonisolated struct LookPoll: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let url: String
    let open: Bool
    let totalVotes: Int
    let options: [LookPollOption]
    let votes: [LookPollVote]       // newest first

    /// Index of the look most people picked, nil on a tie or without votes.
    var leader: Int? {
        guard options.count == 2, options[0].voteCount != options[1].voteCount else { return nil }
        return options[0].voteCount > options[1].voteCount ? 0 : 1
    }
}

nonisolated struct LookPollOption: Codable, Sendable, Equatable {
    let lookId: String
    let name: String
    let imageUrl: String
    let voteCount: Int
    let reasons: [LookPollReason]   // most chosen first
}

nonisolated struct LookPollReason: Codable, Sendable, Equatable {
    let id: String
    let label: String
    let count: Int
}

nonisolated struct LookPollVote: Codable, Sendable, Equatable {
    let choice: Int
    var voterName: String? = nil
    var comment: String? = nil
    let reasons: [String]           // labels
}
#endif
