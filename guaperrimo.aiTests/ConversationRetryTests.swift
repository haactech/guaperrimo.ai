//
//  ConversationRetryTests.swift
//  guaperrimo.aiTests
//

import Foundation
import os
import Testing
@testable import guaperrimo_ai

@MainActor
private final class InstantTTS: TTSService {
    func speak(_ text: String) async {}
    func stop() {}
}

/// Fails with `failure` on the first call, then answers like the stub. Records every request.
private final class FlakyStylist: StylistService {
    private let requests = OSAllocatedUnfairLock(initialState: [ChatRequest]())
    private let failure: Error
    init(failure: Error) { self.failure = failure }

    var sent: [ChatRequest] { requests.withLock { $0 } }

    func chat(sessionId: String, request: ChatRequest) async throws -> ChatResponse {
        let count = requests.withLock { list -> Int in list.append(request); return list.count }
        if count == 1 { throw failure }
        return try await StubStylistService().chat(sessionId: sessionId, request: request)
    }

    func fetchLooks(sessionId: String) async throws -> LooksResponse {
        try await StubStylistService().fetchLooks(sessionId: sessionId)
    }
}

@MainActor
struct ConversationRetryTests {
    private func wait(until condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(5)
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return condition()
    }

    @Test func retryResendsTheFailedRequestNotANewImageTurn() async {
        let service = FlakyStylist(failure: URLError(.timedOut))
        let viewModel = ConversationViewModel(
            sessionId: "t", imageUrl: "https://x/y.jpg", stylistService: service, ttsService: InstantTTS()
        )

        viewModel.selectOption(ChatOption(id: "trabajo", label: "Trabajo"))
        #expect(await wait { if case .error = viewModel.state { true } else { false } })
        #expect(viewModel.state == .error(String(localized: "error_timeout")))

        viewModel.retry()
        #expect(await wait { viewModel.state == .waitingForInput })

        let sent = service.sent
        #expect(sent.count == 2)
        #expect(sent.allSatisfy { $0.type == "button_response" && $0.optionId == "trabajo" })
    }

    @Test func mapsErrorsToSpecificMessages() {
        #expect(ConversationViewModel.errorMessage(for: URLError(.timedOut)) == String(localized: "error_timeout"))
        #expect(ConversationViewModel.errorMessage(for: APIError.serverError(statusCode: 504, message: "")) == String(localized: "error_timeout"))
        #expect(ConversationViewModel.errorMessage(for: URLError(.notConnectedToInternet)) == String(localized: "error_offline"))
        #expect(ConversationViewModel.errorMessage(for: APIError.serverError(statusCode: 502, message: "")) == String(localized: "error_server"))
        #expect(ConversationViewModel.errorMessage(for: APIError.invalidResponse) == String(localized: "error_generic"))
    }
}

@MainActor
struct ConversationHistoryTests {
    @Test func historyRecordsStylistTurnsAndUserAnswersInOrder() async {
        let viewModel = ConversationViewModel(
            sessionId: "t", imageUrl: "https://x/y.jpg", stylistService: StubStylistService(), ttsService: InstantTTS()
        )

        viewModel.selectOption(ChatOption(id: "trabajo", label: "Trabajo"))
        let deadline = ContinuousClock.now + .seconds(5)
        while viewModel.history.count < 2 && ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(25))
        }

        #expect(viewModel.history.map(\.role) == [.user, .stylist])
        #expect(viewModel.history.first?.text == "Trabajo")

        viewModel.sendUIAction(componentId: "budget", value: "2500")
        #expect(viewModel.history.last?.role == .user)
        #expect(viewModel.history.last?.text.contains("2500") == true)
    }
}
