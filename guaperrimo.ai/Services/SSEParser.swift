//
//  SSEParser.swift
//  guaperrimo.ai
//

#if os(iOS)
import Foundation

/// One dispatched server-sent event.
nonisolated struct SSEEvent: Equatable, Sendable {
    let event: String
    let data: String
}

/// Progress the stylist reports while a turn is being prepared (`event: status`).
nonisolated struct ChatProgress: Decodable, Equatable, Sendable {
    let stage: String
    let detail: String?
}

/// Incremental parser for `text/event-stream`. Feed it one line at a time (without the
/// line terminator); an event is returned when the blank line that closes it arrives.
/// Comment lines (":" keep-alive pings) are ignored; several `data:` lines join with "\n".
nonisolated struct SSEParser: Sendable {
    private var eventName = ""
    private var dataLines: [String] = []

    init() {}

    mutating func push(line rawLine: String) -> SSEEvent? {
        let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine

        if line.isEmpty { return dispatch() }
        if line.hasPrefix(":") { return nil }

        let field: String
        var value: String
        if let colon = line.firstIndex(of: ":") {
            field = String(line[..<colon])
            value = String(line[line.index(after: colon)...])
            if value.hasPrefix(" ") { value.removeFirst() }
        } else {
            field = line
            value = ""
        }

        switch field {
        case "event": eventName = value
        case "data": dataLines.append(value)
        default: break // id, retry: unused
        }
        return nil
    }

    /// Flushes a trailing event when the stream ends without its closing blank line.
    mutating func finish() -> SSEEvent? { dispatch() }

    private mutating func dispatch() -> SSEEvent? {
        defer { eventName = ""; dataLines = [] }
        guard !dataLines.isEmpty else { return nil }
        return SSEEvent(event: eventName.isEmpty ? "message" : eventName, data: dataLines.joined(separator: "\n"))
    }
}
#endif
