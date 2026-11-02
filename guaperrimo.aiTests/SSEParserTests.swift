//
//  SSEParserTests.swift
//  guaperrimo.aiTests
//

import Foundation
import Testing
@testable import guaperrimo_ai

struct SSEParserTests {
    @Test func parsesPingsStatusSplitDataAndTurn() {
        let fixture = """
        : ping

        event: status
        data: {"stage":"finding_stores"}

        : keep-alive
        event: status
        data: {"stage":"searching_products",
        data: "detail":"botas chelsea"}

        event: turn
        data: {"phase":"discovery"}\r

        """
        var parser = SSEParser()
        var events: [SSEEvent] = []
        for line in fixture.components(separatedBy: "\n") {
            if let event = parser.push(line: line) { events.append(event) }
        }
        if let tail = parser.finish() { events.append(tail) }

        #expect(events.count == 3)
        #expect(events[0] == SSEEvent(event: "status", data: #"{"stage":"finding_stores"}"#))
        #expect(events[1].event == "status")
        #expect(events[1].data == "{\"stage\":\"searching_products\",\n\"detail\":\"botas chelsea\"}")
        #expect(events[2] == SSEEvent(event: "turn", data: #"{"phase":"discovery"}"#))
    }

    @Test func finishFlushesEventWithoutTrailingBlankLine() {
        var parser = SSEParser()
        #expect(parser.push(line: "event: error") == nil)
        #expect(parser.push(line: #"data: {"status":504}"#) == nil)
        #expect(parser.finish() == SSEEvent(event: "error", data: #"{"status":504}"#))
        #expect(parser.finish() == nil)
    }
}
