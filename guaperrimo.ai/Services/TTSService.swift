//
//  TTSService.swift
//  guaperrimo.ai
//

#if os(iOS)
import AVFoundation
import OSLog

private let logger = Logger(subsystem: "ai.guaperrimo", category: "TTS")

// MARK: - Protocol

protocol TTSService {
    func speak(_ text: String) async
    func stop()
}

// MARK: - ElevenLabs implementation

final class ElevenLabsTTSService: NSObject, TTSService, AVAudioPlayerDelegate {
    private let apiKey: String
    private let voiceId: String
    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Never>?
    private var isStopped = false

    override init() {
        // Read config from Config.plist
        guard let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: configPath),
              let key = config["ElevenLabsAPIKey"] as? String,
              let voice = config["ElevenLabsVoiceID"] as? String else {
            logger.warning("Config.plist missing or incomplete — ElevenLabs TTS disabled")
            self.apiKey = ""
            self.voiceId = ""
            super.init()
            return
        }
        self.apiKey = key
        self.voiceId = voice
        super.init()
    }

    func speak(_ text: String) async {
        stop()
        isStopped = false

        guard !apiKey.isEmpty, apiKey != "YOUR_API_KEY_HERE" else {
            logger.warning("ElevenLabs API key not configured — skipping TTS")
            return
        }

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

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            logger.error("Failed to encode TTS request: \(error.localizedDescription)")
            return
        }

        logger.info("⬆️ ElevenLabs TTS — \(text.prefix(60))...")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard !isStopped else { return }

            let httpResponse = response as! HTTPURLResponse
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? ""
                logger.error("⬇️ ElevenLabs HTTP \(httpResponse.statusCode) — \(errorBody)")
                return
            }

            logger.info("⬇️ ElevenLabs audio received — \(data.count) bytes")

            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            let audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer.delegate = self
            self.player = audioPlayer

            await withCheckedContinuation { continuation in
                self.continuation = continuation
                audioPlayer.play()
            }
        } catch {
            guard !isStopped else { return }
            logger.error("ElevenLabs TTS failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        isStopped = true
        player?.stop()
        player = nil
        continuation?.resume()
        continuation = nil
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.continuation?.resume()
            self.continuation = nil
        }
    }
}

// MARK: - Stub implementation (AVSpeechSynthesizer fallback)

final class StubTTSService: NSObject, TTSService, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) async {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-MX")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        continuation?.resume()
        continuation = nil
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.continuation?.resume()
            self.continuation = nil
        }
    }
}
#endif
