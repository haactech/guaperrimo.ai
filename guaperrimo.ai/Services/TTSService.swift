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

final class ElevenLabsTTSService: NSObject, TTSService, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    private let apiKey: String
    private let voiceId: String
    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Never>?
    private var isStopped = false

    // Fallback: AVSpeechSynthesizer directly (no StubTTSService wrapper)
    private lazy var fallbackSynthesizer: AVSpeechSynthesizer = {
        let s = AVSpeechSynthesizer()
        s.delegate = self
        return s
    }()

    override init() {
        let configPath = Bundle.main.path(forResource: "Config", ofType: "plist")
        logger.info("🔧 Config.plist path: \(configPath ?? "NOT FOUND")")

        guard let configPath,
              let config = NSDictionary(contentsOfFile: configPath),
              let key = config["ElevenLabsAPIKey"] as? String,
              let voice = config["ElevenLabsVoiceID"] as? String else {
            logger.error("❌ Config.plist missing or incomplete — ElevenLabs TTS disabled")
            self.apiKey = ""
            self.voiceId = ""
            super.init()
            return
        }
        logger.info("🔧 ElevenLabs configured — voiceId: \(voice), apiKey: \(key.prefix(8))...")
        self.apiKey = key
        self.voiceId = voice
        super.init()
    }

    func speak(_ text: String) async {
        logger.info("🔊 speak() called — text length: \(text.count) chars")
        stop()
        isStopped = false

        guard !apiKey.isEmpty, apiKey != "YOUR_API_KEY_HERE" else {
            logger.warning("⚠️ ElevenLabs API key not configured — using fallback")
            await fallbackSpeak(text)
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
            logger.error("❌ Failed to encode TTS request body: \(error.localizedDescription)")
            return
        }

        logger.info("⬆️ ElevenLabs POST /v1/text-to-speech/\(self.voiceId)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard !isStopped else {
                logger.info("⏹️ TTS stopped before playback — discarding audio")
                return
            }

            let httpResponse = response as! HTTPURLResponse
            logger.info("⬇️ ElevenLabs HTTP \(httpResponse.statusCode) — \(data.count) bytes")

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "<no body>"
                logger.error("❌ ElevenLabs error: \(errorBody)")
                logger.info("🔄 Falling back to AVSpeechSynthesizer")
                await fallbackSpeak(text)
                return
            }

            logger.info("🎵 Audio data: \(data.count) bytes")

            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)

            let audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer.delegate = self
            audioPlayer.volume = 1.0
            self.player = audioPlayer
            audioPlayer.prepareToPlay()

            logger.info("🎵 AVAudioPlayer — duration: \(audioPlayer.duration)s")

            await withCheckedContinuation { continuation in
                self.continuation = continuation
                let playing = audioPlayer.play()
                logger.info("▶️ AVAudioPlayer.play() → \(playing)")
                if !playing {
                    self.continuation?.resume()
                    self.continuation = nil
                }
            }
        } catch {
            guard !isStopped else { return }
            logger.error("❌ ElevenLabs network failed: \(error.localizedDescription)")
            logger.info("🔄 Falling back to AVSpeechSynthesizer")
            await fallbackSpeak(text)
        }
    }

    // Fallback: use AVSpeechSynthesizer directly, no nested service
    private func fallbackSpeak(_ text: String) async {
        guard !isStopped else { return }
        logger.info("🗣️ AVSpeechSynthesizer fallback — speaking \(text.count) chars")

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-MX")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.continuation = cont
            self.fallbackSynthesizer.speak(utterance)
        }
    }

    func stop() {
        isStopped = true
        // Stop ElevenLabs audio
        player?.stop()
        player = nil
        // Stop fallback speech
        if fallbackSynthesizer.isSpeaking {
            fallbackSynthesizer.stopSpeaking(at: .immediate)
        }
        // Resume any pending continuation
        continuation?.resume()
        continuation = nil
    }

    // MARK: - AVAudioPlayerDelegate (ElevenLabs playback)

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.continuation?.resume()
            self.continuation = nil
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor in
            self.player = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.continuation?.resume()
            self.continuation = nil
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate (fallback playback)

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.continuation?.resume()
            self.continuation = nil
        }
    }
}

// MARK: - Stub implementation (AVSpeechSynthesizer only)

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

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            self.continuation?.resume()
            self.continuation = nil
        }
    }
}
#endif
