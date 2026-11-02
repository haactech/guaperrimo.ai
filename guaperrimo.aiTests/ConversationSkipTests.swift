//
//  ConversationSkipTests.swift
//  guaperrimo.aiTests
//

import Testing
@testable import guaperrimo_ai

/// TTS fake: `speak` suspends until `stop()` is called, like the real player does.
@MainActor
private final class FakeTTSService: TTSService {
    private(set) var stopCount = 0
    private var continuation: CheckedContinuation<Void, Never>?

    func speak(_ text: String) async {
        await withCheckedContinuation { continuation = $0 }
    }

    func stop() {
        stopCount += 1
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
struct ConversationSkipTests {
    private func wait(timeout: Duration, until condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return condition()
    }

    @Test func skipSpeakingStopsTTSAndAdvancesToInput() async {
        let tts = FakeTTSService()
        let viewModel = ConversationViewModel(
            sessionId: "t",
            imageUrl: "https://x/y.jpg",
            stylistService: StubStylistService(),
            ttsService: tts
        )

        // Bypasses startConversation so the CLLocationManager state does not matter.
        viewModel.skipLocation()

        #expect(await wait(timeout: .seconds(5)) { viewModel.state == .speaking })
        #expect(viewModel.isSpeaking)

        viewModel.skipSpeaking()

        #expect(await wait(timeout: .seconds(2)) { viewModel.state == .waitingForInput })
        #expect(tts.stopCount >= 1)
        #expect(!viewModel.isSpeaking)
    }
}
