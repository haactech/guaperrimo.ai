//
//  SpeechRecognitionService.swift
//  guaperrimo.ai
//

#if os(iOS)
import AVFoundation
import OSLog
import Speech

private let logger = Logger(subsystem: "ai.guaperrimo", category: "SpeechRecognition")

@Observable
@MainActor
final class SpeechRecognitionService {
    var transcript = ""
    var isListening = false
    var isAuthorized = false
    var isMicGranted = false
    var errorMessage: String?
    /// Set to true once STT delivers the final transcript (or fails/times out)
    var isFinalized = false

    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var audioEngine: AVAudioEngine?
    private let speechRecognizer = SFSpeechRecognizer()
    private var sessionId = 0

    func requestAuthorization() {
        // 1. Speech recognition permission
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.isAuthorized = true
                    logger.info("✅ Speech recognition: authorized")
                case .denied:
                    self.isAuthorized = false
                    logger.error("❌ Speech recognition: denied")
                case .restricted:
                    self.isAuthorized = false
                    logger.error("❌ Speech recognition: restricted")
                case .notDetermined:
                    self.isAuthorized = false
                    logger.warning("⚠️ Speech recognition: not determined")
                @unknown default:
                    self.isAuthorized = false
                }
            }
        }

        // 2. Microphone permission (separate from speech recognition!)
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                self.isMicGranted = granted
                logger.info("🎤 Microphone permission: \(granted ? "GRANTED" : "DENIED")")
            }
        }
    }

    func startListening() {
        guard !isListening else { return }

        // Check microphone permission FIRST — this is the most likely failure
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        logger.info("🎤 Mic permission at start: \(micStatus.rawValue) (granted=\(micStatus == .granted))")

        if micStatus == .denied {
            errorMessage = String(localized: "mic_denied")
            logger.error("❌ Microphone permission DENIED — iOS feeds silent buffers. User must enable in Settings.")
            return
        }

        if micStatus == .undetermined {
            logger.info("🎤 Mic permission undetermined — requesting...")
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    self.isMicGranted = granted
                    if granted {
                        logger.info("🎤 Mic permission granted — retrying startListening")
                        self.startListening()
                    } else {
                        self.errorMessage = String(localized: "mic_denied")
                        logger.error("❌ User denied microphone permission")
                    }
                }
            }
            return
        }

        // Check speech recognition authorization
        guard isAuthorized else {
            errorMessage = String(localized: "voice_error")
            logger.error("❌ Speech recognition not authorized")
            return
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = String(localized: "voice_error")
            logger.error("❌ Speech recognizer not available")
            return
        }

        logger.info("🔧 Recognizer locale: \(speechRecognizer.locale.identifier), onDevice: \(speechRecognizer.supportsOnDeviceRecognition)")

        transcript = ""
        errorMessage = nil
        isFinalized = false
        sessionId += 1

        // Configure audio session for recording
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let inputs = audioSession.currentRoute.inputs
            let outputs = audioSession.currentRoute.outputs
            logger.info("🔊 Audio session — inputs: \(inputs.map { "\($0.portName)(\($0.portType.rawValue))" }), outputs: \(outputs.map { "\($0.portName)(\($0.portType.rawValue))" })")
        } catch {
            logger.error("❌ Audio session setup failed: \(error.localizedDescription)")
            errorMessage = "Microphone setup failed"
            return
        }

        // Fresh audio engine
        let engine = AVAudioEngine()
        self.audioEngine = engine

        // Recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        recognitionRequest = request

        // Install tap on input node
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        logger.info("🎤 Input format: sampleRate=\(recordingFormat.sampleRate), channels=\(recordingFormat.channelCount), interleaved=\(recordingFormat.isInterleaved)")

        var bufferCount = 0
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { buffer, _ in
            request.append(buffer)
            bufferCount += 1

            // Log audio levels every ~1s
            if bufferCount % 12 == 1 {
                if let channelData = buffer.floatChannelData?[0] {
                    let frames = Int(buffer.frameLength)
                    var maxVal: Float = 0
                    var rms: Float = 0
                    for i in 0..<frames {
                        let val = abs(channelData[i])
                        if val > maxVal { maxVal = val }
                        rms += val * val
                    }
                    rms = sqrt(rms / Float(frames))
                    logger.info("🔈 Buffer #\(bufferCount) — peak: \(maxVal), rms: \(rms), frames: \(frames)")
                } else {
                    logger.warning("⚠️ Buffer #\(bufferCount) — floatChannelData is nil!")
                }
            }
        }

        // Start engine
        engine.prepare()
        do {
            try engine.start()
            isListening = true
            logger.info("🎙️ Recording started (session \(self.sessionId))")
        } catch {
            logger.error("❌ Audio engine start failed: \(error.localizedDescription)")
            errorMessage = "Could not start recording"
            return
        }

        // Start recognition
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    logger.info("📝 Partial: \(self.transcript.prefix(80))")

                    if result.isFinal {
                        logger.info("🏁 Final transcript: \(self.transcript.prefix(80))")
                        self.finalize()
                    }
                }
                if let error {
                    let nsError = error as NSError
                    logger.error("STT error: domain=\(nsError.domain) code=\(nsError.code) — \(error.localizedDescription)")
                    self.finalize()
                }
            }
        }
    }

    func stopListening() {
        guard isListening else { return }
        let stoppedSession = sessionId

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        isListening = false

        logger.info("🛑 Recording stopped (session \(stoppedSession))")

        // Safety timeout
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard self.sessionId == stoppedSession && !self.isFinalized else { return }
            logger.warning("⏰ STT timeout (session \(stoppedSession))")
            self.recognitionTask?.cancel()
            self.finalize()
        }
    }

    private func finalize() {
        recognitionTask = nil
        isFinalized = true
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        logger.info("✅ STT finalized — transcript: \"\(self.transcript.prefix(80))\"")
    }
}
#endif
