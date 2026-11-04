//
//  PollDecodingTests.swift
//  guaperrimo.aiTests
//
//  Decodes GET /session/{id}/polls as the backend writes it (Go time stamps,
//  fields the app ignores) and the request that creates a poll.

import Foundation
import Testing

@testable import guaperrimo_ai

@Suite struct PollDecodingTests {

    static let serverResponse = #"""
{"polls":[{"id":"h9jaIIuhLfIIUIcmd_MGmw","url":"http://192.168.100.39:8080/v/h9jaIIuhLfIIUIcmd_MGmw","open":true,
"created_at":"2026-11-04T13:38:55.123456-06:00","expires_at":"2026-11-07T13:38:55.123456-06:00","total_votes":3,
"options":[
 {"look_id":"look_1","name":"Clásico de lino","image_url":"http://192.168.100.39:8080/images/sessions/s/a.jpg?exp=1&sig=x","vote_count":2,
  "reasons":[{"id":"color","label":"El color le queda mejor","count":2}]},
 {"look_id":"look_2","name":"Mezclilla relajado","image_url":"http://192.168.100.39:8080/images/sessions/s/b.jpg?exp=1&sig=y","vote_count":1,"reasons":[]}],
"votes":[
 {"choice":1,"reasons":[],"created_at":"2026-11-04T13:40:00Z"},
 {"choice":0,"voter_name":"Mariana","comment":"El verde te queda increíble","reasons":["El color le queda mejor"],"created_at":"2026-11-04T13:39:00Z"}]}]}
"""#

    @Test func decodesTheServerList() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let list = try decoder.decode(PollListResponse.self, from: Data(Self.serverResponse.utf8))
        let poll = try #require(list.polls.first)
        #expect(poll.open && poll.totalVotes == 3)
        #expect(poll.options.map(\.voteCount) == [2, 1])
        #expect(poll.options[0].reasons.first?.label == "El color le queda mejor")
        #expect(poll.votes[0].voterName == nil && poll.votes[0].comment == nil)
        #expect(poll.votes[1].voterName == "Mariana")
        #expect(poll.leader == 0)
    }

    @Test func tieHasNoLeader() {
        let option = { (n: Int) in LookPollOption(lookId: "l\(n)", name: "", imageUrl: "", voteCount: 1, reasons: []) }
        let poll = LookPoll(id: "p", url: "", open: true, totalVotes: 2, options: [option(1), option(2)], votes: [])
        #expect(poll.leader == nil)
    }

    @Test func createRequestUsesSnakeCase() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let json = String(decoding: try encoder.encode(CreatePollRequest(lookIds: ["look_1", "look_2"])), as: UTF8.self)
        #expect(json == #"{"look_ids":["look_1","look_2"]}"#)
    }
}
