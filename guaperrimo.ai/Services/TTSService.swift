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

// MARK: - ElevenLabs implementation (through our backend)

/// The stylist's voice. The audio comes from our backend (`POST /tts`), which
/// holds the ElevenLabs key: the app never carries it. When the backend has
/// no voice configured or the call fails, the iPhone's own voice speaks.
final class ElevenLabsTTSService: NSObject, TTSService, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Never>?
    private var isStopped = false

    // Fallback: AVSpeechSynthesizer directly (no StubTTSService wrapper)
    private lazy var fallbackSynthesizer: AVSpeechSynthesizer = {
        let s = AVSpeechSynthesizer()
        s.delegate = self
        return s
    }()

    func speak(_ text: String) async {
        logger.info("🔊 speak() called — text length: \(text.count) chars")
        stop()
        isStopped = false

        guard let url = URL(string: "\(APIClient.baseURL)/tts") else {
            await fallbackSpeak(text)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["text": text])
        } catch {
            logger.error("❌ Failed to encode TTS request body: \(error.localizedDescription)")
            await fallbackSpeak(text)
            return
        }

        logger.info("⬆️ POST /tts")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard !isStopped else {
                logger.info("⏹️ TTS stopped before playback — discarding audio")
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.info("⬇️ /tts HTTP \(status) — \(data.count) bytes")

            guard status == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "<no body>"
                logger.error("❌ /tts error \(status, privacy: .public): \(errorBody, privacy: .public)")
                logger.info("🔄 Falling back to AVSpeechSynthesizer")
                await fallbackSpeak(text)
                return
            }

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
            logger.error("❌ /tts failed: \(String(describing: error), privacy: .public)")
            logger.info("🔄 Falling back to AVSpeechSynthesizer")
            await fallbackSpeak(text)
        }
    }

    // Fallback: use AVSpeechSynthesizer directly, no nested service
    private func fallbackSpeak(_ text: String) async {
        guard !isStopped else { return }
        logger.info("🗣️ AVSpeechSynthesizer fallback — speaking \(text.count) chars")

        // Same session as the ElevenLabs path: without .playback the system
        // voice is silent when the ringer switch is off (and after the mic
        // left the session in a recording category), while the speaking pill
        // still shows.
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("❌ Could not activate audio session for fallback speech: \(String(describing: error), privacy: .public)")
        }

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
