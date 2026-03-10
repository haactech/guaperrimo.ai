# Diagramas de Arquitectura — guaperrimo.ai iOS

## 1. Diagrama de Flujo (Estado del sistema)

```mermaid
flowchart TD
    START([App Launch]) --> DEBUG{Debug mode?}
    DEBUG -->|Si| CONV_DIRECT[ConversationView<br/>sessionId + imageUrl hardcoded]
    DEBUG -->|No| CAMERA

    subgraph CAPTURE ["Fase 1: Captura"]
        CAMERA[CameraView] -->|Pose detection| POSE{Posicion OK?}
        POSE -->|noPerson / tooFar / tooClose| CAMERA
        POSE -->|aligned + stillConfirmed| COUNTDOWN[Countdown 3s]
        COUNTDOWN -->|Movimiento| CAMERA
        COUNTDOWN -->|Quieto 3s| PHOTO[Foto capturada<br/>UIImage]
        PHOTO --> PREVIEW[PhotoPreviewView]
        PREVIEW -->|Repetir| CAMERA
        PREVIEW -->|Guardar| UPLOAD[ImageUploadService<br/>POST /session/id/image]
        UPLOAD -->|Error| PREVIEW
        UPLOAD -->|OK| UPLOAD_RESP[UploadResponse<br/>sessionId + imageUrl]
    end

    UPLOAD_RESP --> CONV[ConversationView<br/>fullScreenCover]
    CONV_DIRECT --> CONV

    subgraph CONVERSATION ["Fase 2: Conversacion Multi-turno"]
        CONV --> INIT[startConversation<br/>ChatRequest type=image]
        INIT --> LOADING[state: .loading<br/>ThinkingIndicatorView]
        LOADING -->|POST /session/id/chat| API_CALL{Respuesta OK?}
        API_CALL -->|Error| ERROR[state: .error<br/>Mensaje + Retry]
        ERROR -->|Retry| INIT
        API_CALL -->|ChatResponse| HANDLE[handleResponse]

        HANDLE --> SPEAKING[state: .speaking<br/>TTS reproduce mensaje]
        SPEAKING -->|ElevenLabs API| TTS_PLAY[AVAudioPlayer<br/>audio MP3]
        SPEAKING -->|Fallback| TTS_FALLBACK[AVSpeechSynthesizer<br/>es-MX]
        TTS_PLAY --> TTS_DONE[Audio termina<br/>+300ms pausa]
        TTS_FALLBACK --> TTS_DONE

        TTS_DONE --> FINAL_CHECK{isFinal?}
        FINAL_CHECK -->|true| FINISHED[state: .finished<br/>PriorityActionCards]
        FINAL_CHECK -->|false| WAITING[state: .waitingForInput]

        WAITING --> INPUT_MODE{inputMode?}

        INPUT_MODE -->|.buttons| BUTTONS[Pill buttons<br/>ChatOption labels]
        INPUT_MODE -->|.voice| MIC_CHECK{Mic permission?}
        INPUT_MODE -->|.none| WAITING

        BUTTONS -->|Tap opcion| SELECT[selectOption<br/>ChatRequest type=button_response]

        MIC_CHECK -->|Denied| MIC_ERROR[Error mic<br/>Abrir Ajustes]
        MIC_CHECK -->|Granted| MIC_READY[Mic button<br/>Manten presionado]

        MIC_READY -->|Hold| RECORDING[SpeechRecognitionService<br/>AVAudioEngine + SFSpeechRecognizer]
        RECORDING -->|Partial results| LIVE_TEXT[Transcript en vivo]
        RECORDING -->|Release| STT_STOP[stopListening<br/>endAudio]
        STT_STOP -->|isFinalized| CONFIRM{Transcript vacio?}
        CONFIRM -->|Si| MIC_READY
        CONFIRM -->|No| CONFIRM_UI[Confirmar transcript<br/>Enviar / Repetir]
        CONFIRM_UI -->|Repetir| MIC_READY
        CONFIRM_UI -->|Enviar| VOICE[sendVoiceResponse<br/>ChatRequest type=voice_response]

        SELECT --> PROCESSING[state: .processing]
        VOICE --> PROCESSING
        PROCESSING --> LOADING
    end

    FINISHED --> END([Fin de conversacion])

    style CAPTURE fill:#1a1a2e,stroke:#16213e,color:#e6e6e6
    style CONVERSATION fill:#0f3460,stroke:#533483,color:#e6e6e6
```

## 2. Diagrama de Secuencia (Interaccion entre modulos)

```mermaid
sequenceDiagram
    actor User
    participant CV as ConversationView
    participant VM as ConversationViewModel
    participant SS as StylistService
    participant API as APIClient
    participant TTS as TTSService
    participant 11L as ElevenLabs API
    participant STT as SpeechRecognitionService
    participant SR as SFSpeechRecognizer

    Note over CV,SR: Fase 1 — Inicio de conversacion

    CV->>VM: startConversation()
    VM->>VM: state = .loading
    VM->>SS: chat(sessionId, ChatRequest{type:"image", imageUrl})
    SS->>API: postJSON("/session/{id}/chat", body)
    API->>API: POST http://server:8080/session/{id}/chat
    API-->>SS: ChatResponse
    SS-->>VM: ChatResponse{message, inputMode, options, isFinal}
    VM->>VM: state = .speaking
    VM->>TTS: speak(message)
    TTS->>11L: POST /v1/text-to-speech/{voiceId}
    11L-->>TTS: audio MP3 (bytes)
    TTS->>TTS: AVAudioPlayer.play()
    Note over TTS: Bloquea con CheckedContinuation<br/>hasta que el audio termina
    TTS->>TTS: setActive(false)
    TTS-->>VM: return (audio terminado)
    VM->>VM: sleep(300ms)
    VM->>VM: state = .waitingForInput

    Note over CV,SR: Fase 2a — Respuesta con botones

    CV-->>User: Muestra pill buttons (ChatOption.label)
    User->>CV: Tap boton "Casual elevado"
    CV->>VM: selectOption(option)
    VM->>VM: state = .processing
    VM->>SS: chat(sessionId, ChatRequest{type:"button_response", optionId})
    SS->>API: postJSON(...)
    API-->>SS: ChatResponse{inputMode:.voice}
    SS-->>VM: ChatResponse
    VM->>TTS: speak(message)
    Note over TTS: Mismo flujo TTS...
    TTS-->>VM: return
    VM->>VM: state = .waitingForInput

    Note over CV,SR: Fase 2b — Respuesta con voz (Push-to-talk)

    CV-->>User: Muestra mic button + "Manten presionado"
    User->>CV: Hold mic button (DragGesture.onChanged)
    CV->>CV: isHoldingMic = true
    CV->>STT: startListening()
    STT->>STT: Check recordPermission
    STT->>STT: setCategory(.playAndRecord)
    STT->>STT: AVAudioEngine.start()
    STT->>SR: recognitionTask(with: request)

    loop Mientras el usuario habla
        SR-->>STT: partial result (transcript)
        STT-->>CV: transcript actualizado (live)
        CV-->>User: Muestra transcript en vivo
    end

    User->>CV: Release mic (DragGesture.onEnded)
    CV->>CV: isHoldingMic = false
    CV->>STT: stopListening()
    STT->>STT: audioEngine.stop()
    STT->>STT: request.endAudio()
    SR-->>STT: final result o timeout 3s
    STT->>STT: isFinalized = true
    STT-->>CV: onChange(isFinalized)
    CV->>CV: pendingTranscript = transcript

    CV-->>User: Muestra transcript + [Enviar] [Repetir]
    User->>CV: Tap "Enviar"
    CV->>VM: sendVoiceResponse(transcript)
    VM->>VM: state = .processing
    VM->>SS: chat(sessionId, ChatRequest{type:"voice_response", transcript})
    SS->>API: postJSON(...)
    API-->>SS: ChatResponse{isFinal:true, priorityActions:[...]}
    SS-->>VM: ChatResponse
    VM->>TTS: speak(message)
    TTS-->>VM: return
    VM->>VM: state = .finished

    Note over CV,SR: Fase 3 — Recomendaciones finales

    CV-->>User: Muestra PriorityActionCards<br/>(titulo, descripcion, impacto, esfuerzo)
```

## 3. Diagrama de Modulos y Dependencias

```mermaid
graph TB
    subgraph Views ["Views (SwiftUI)"]
        CV[ConversationView]
        PPV[PhotoPreviewView]
        CAM[CameraView]
        PAC[PriorityActionCardView]
        TIV[ThinkingIndicatorView]
    end

    subgraph ViewModels ["ViewModels"]
        CVM[ConversationViewModel<br/>state: ConversationState]
    end

    subgraph Services ["Services"]
        SS[StylistService<br/>protocol]
        LSS[LiveStylistService]
        STBS[StubStylistService]
        TTS[TTSService<br/>protocol]
        E11[ElevenLabsTTSService]
        STBT[StubTTSService]
        STT[SpeechRecognitionService]
        IUS[ImageUploadService]
        APIC[APIClient]
    end

    subgraph Models ["Models"]
        CR[ChatRequest]
        CRSP[ChatResponse]
        CO[ChatOption]
        PA[PriorityAction]
        IM[InputMode]
        UR[UploadResponse]
    end

    subgraph External ["APIs Externas"]
        BE[Backend Server<br/>POST /session/id/chat]
        EL[ElevenLabs API<br/>POST /v1/text-to-speech]
        ASR[Apple SFSpeechRecognizer<br/>on-device]
    end

    %% View → ViewModel
    CV --> CVM
    CV --> STT
    CV --> PAC
    CV --> TIV

    %% ViewModel → Services
    CVM --> SS
    CVM --> TTS
    CVM --> STT

    %% Service implementations
    SS -.->|Live| LSS
    SS -.->|Stub| STBS
    TTS -.->|Live| E11
    TTS -.->|Stub| STBT

    %% Services → APIClient
    LSS --> APIC
    IUS --> APIC

    %% Services → External
    APIC --> BE
    E11 --> EL
    STT --> ASR

    %% Views → Services
    PPV --> IUS

    %% Models usage
    LSS --> CR
    LSS --> CRSP
    CVM --> CO
    CVM --> PA
    CVM --> IM
    IUS --> UR

    style Views fill:#1e3a5f,stroke:#4a90d9,color:#fff
    style ViewModels fill:#2d1b4e,stroke:#7b5ea7,color:#fff
    style Services fill:#1b4332,stroke:#52b788,color:#fff
    style Models fill:#3d2b1f,stroke:#c49a6c,color:#fff
    style External fill:#4a1524,stroke:#d44d5c,color:#fff
```

## 4. Estado compartido entre modulos

| Dato | Origen | Consumidores | Tipo |
|------|--------|-------------|------|
| `sessionId` | PhotoPreviewView (UUID) | ConversationViewModel → StylistService | `String` |
| `imageUrl` | UploadResponse.url | ConversationViewModel → ChatRequest | `String` |
| `state` | ConversationViewModel | ConversationView (switch UI) | `ConversationState` |
| `currentMessage` | ChatResponse.message | ConversationView (texto), TTSService (audio) | `String` |
| `currentOptions` | ChatResponse.options | ConversationView (pill buttons) | `[ChatOption]` |
| `currentInputMode` | ChatResponse.inputMode | ConversationView (buttons/voice/none) | `InputMode` |
| `priorityActions` | ChatResponse.priorityActions | ConversationView → PriorityActionCardView | `[PriorityAction]` |
| `isSpeaking` | ConversationViewModel | ConversationView (deshabilita input) | `Bool` |
| `transcript` | SpeechRecognitionService | ConversationView (live text + confirm) | `String` |
| `isFinalized` | SpeechRecognitionService | ConversationView (onChange → pendingTranscript) | `Bool` |
| `isListening` | SpeechRecognitionService | ConversationView (UI mic button) | `Bool` |
| `isHoldingMic` | ConversationView (local) | ConversationView (gesture + UI) | `Bool` |
| `pendingTranscript` | ConversationView (local) | ConversationView (confirm UI) | `String?` |

## 5. Ciclo de vida del Audio Session

```mermaid
stateDiagram-v2
    [*] --> Inactive: App launch

    Inactive --> Playback: TTS speak()<br/>setCategory(.playback)
    Playback --> Inactive: Audio termina<br/>setActive(false)

    Inactive --> PlayAndRecord: STT startListening()<br/>setCategory(.playAndRecord)
    PlayAndRecord --> Inactive: STT finalize()<br/>setActive(false)

    Playback --> PlayAndRecord: Usuario presiona mic<br/>(TTS ya termino)

    note right of Playback
        ElevenLabs MP3 via AVAudioPlayer
        o AVSpeechSynthesizer fallback
    end note

    note right of PlayAndRecord
        AVAudioEngine captura mic
        SFSpeechRecognizer transcribe
    end note
```
