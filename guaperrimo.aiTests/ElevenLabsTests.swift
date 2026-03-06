//
//  ElevenLabsTests.swift
//  guaperrimo.aiTests
//

import Foundation
import Testing

// These tests hit the real ElevenLabs API to discover what works on the free tier.
// Run with: xcodebuild test -scheme guaperrimo.ai -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:guaperrimo.aiTests/ElevenLabsTests

private let apiKey = "sk_e61b803c049dd8e737b0b56f6550703c668ddb87e91a2430"
private let outputFile = "/tmp/elevenlabs_test_results.txt"

private func log(_ msg: String) {
    let line = msg + "\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: outputFile) {
            let handle = FileHandle(forWritingAtPath: outputFile)!
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: outputFile, contents: data)
        }
    }
}

// MARK: - Voice discovery

@Suite(.serialized)
struct ElevenLabsTests {

    @Test func listAvailableVoices() async throws {
        let url = URL(string: "https://api.elevenlabs.io/v1/voices")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse
        #expect(httpResponse.statusCode == 200, "GET /v1/voices returned \(httpResponse.statusCode)")

        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let voices = json["voices"] as! [[String: Any]]

        log("━━━ Available voices (\(voices.count)) ━━━")
        for voice in voices {
            let id = voice["voice_id"] as? String ?? "?"
            let name = voice["name"] as? String ?? "?"
            let category = voice["category"] as? String ?? "?"
            let labels = voice["labels"] as? [String: String] ?? [:]
            let lang = labels["language"] ?? labels["accent"] ?? "?"
            log("  \(category) | \(name) | \(id) | \(lang)")
        }
        log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        #expect(voices.count > 0, "Should have at least one voice")
    }

    @Test func synthesizeWithPremadeVoice() async throws {
        // First, find premade voices
        let voicesURL = URL(string: "https://api.elevenlabs.io/v1/voices")!
        var voicesRequest = URLRequest(url: voicesURL)
        voicesRequest.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let (voicesData, _) = try await URLSession.shared.data(for: voicesRequest)
        let json = try JSONSerialization.jsonObject(with: voicesData) as! [String: Any]
        let voices = json["voices"] as! [[String: Any]]

        // Filter premade voices
        let premade = voices.filter { ($0["category"] as? String) == "premade" }
        log("━━━ Premade voices (\(premade.count)) ━━━")
        for voice in premade {
            let id = voice["voice_id"] as? String ?? "?"
            let name = voice["name"] as? String ?? "?"
            let labels = voice["labels"] as? [String: String] ?? [:]
            log("  \(name) | \(id) | \(labels)")
        }

        #expect(!premade.isEmpty, "Should have premade voices available")

        // Try TTS with first premade voice
        let testVoice = premade[0]
        let voiceId = testVoice["voice_id"] as! String
        let voiceName = testVoice["name"] as? String ?? "?"

        log("━━━ Testing TTS with: \(voiceName) (\(voiceId)) ━━━")

        let audioData = try await callTTS(
            voiceId: voiceId,
            text: "Hola, soy tu estilista de guaperrimo. Me encanta tu look."
        )

        #expect(audioData.count > 1000, "Audio should be more than 1KB, got \(audioData.count) bytes")

        // Verify it's MP3 (starts with FF FB or ID3)
        let isMP3 = (audioData[0] == 0xFF && (audioData[1] & 0xE0) == 0xE0) ||
                     (audioData[0] == 0x49 && audioData[1] == 0x44 && audioData[2] == 0x33) // "ID3"
        #expect(isMP3, "Should be valid MP3 data, first bytes: \(audioData.prefix(4).map { String(format: "%02X", $0) }.joined())")

        log("✅ TTS success — \(audioData.count) bytes of audio")
    }

    @Test func tryMultiplePremadeVoices() async throws {
        // Find all premade voices and try each one
        let voicesURL = URL(string: "https://api.elevenlabs.io/v1/voices")!
        var voicesRequest = URLRequest(url: voicesURL)
        voicesRequest.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let (voicesData, _) = try await URLSession.shared.data(for: voicesRequest)
        let json = try JSONSerialization.jsonObject(with: voicesData) as! [String: Any]
        let voices = json["voices"] as! [[String: Any]]

        let premade = voices.filter { ($0["category"] as? String) == "premade" }

        log("━━━ Testing all premade voices ━━━")
        var working: [(name: String, id: String, bytes: Int)] = []
        var failed: [(name: String, id: String, error: String)] = []

        for voice in premade {
            let id = voice["voice_id"] as! String
            let name = voice["name"] as? String ?? "?"

            do {
                let data = try await callTTS(voiceId: id, text: "Prueba rápida.")
                working.append((name: name, id: id, bytes: data.count))
                log("  ✅ \(name) (\(id)) — \(data.count) bytes")
            } catch {
                failed.append((name: name, id: id, error: error.localizedDescription))
                log("  ❌ \(name) (\(id)) — \(error.localizedDescription)")
            }
        }

        log("━━━ Results ━━━")
        log("Working: \(working.count)")
        log("Failed:  \(failed.count)")

        for v in working {
            log("  ✅ \(v.name) | \(v.id) | \(v.bytes) bytes")
        }

        #expect(!working.isEmpty, "At least one premade voice should work on free tier")
    }

    @Test func checkCurrentConfiguredVoice() async throws {
        // Test the currently configured voice ID
        let currentVoiceId = "ajOR9IDAaubDK5qtLUqQ"

        log("━━━ Testing currently configured voice: \(currentVoiceId) ━━━")

        do {
            let data = try await callTTS(
                voiceId: currentVoiceId,
                text: "Esta es una prueba de la voz configurada."
            )
            log("✅ Current voice works — \(data.count) bytes")
        } catch let error as TTSTestError {
            log("❌ Current voice FAILED — \(error.statusCode): \(error.body)")
            log("💡 Need to switch to a premade voice (see tryMultiplePremadeVoices test)")
            #expect(Bool(false), "Current voice doesn't work: \(error.body)")
        }
    }

    // MARK: - Helpers

    private func callTTS(voiceId: String, text: String) async throws -> Data {
        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75,
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw TTSTestError(statusCode: httpResponse.statusCode, body: errorBody)
        }

        return data
    }
}

private struct TTSTestError: Error, LocalizedError {
    let statusCode: Int
    let body: String
    var errorDescription: String? { "HTTP \(statusCode): \(body)" }
}
