# Conversacion de Estilo Post-Foto

Funcionalidad de conversacion interactiva con un "estilista AI" despues de capturar y subir la foto del outfit. El estilista analiza la foto, conversa con el usuario sobre preferencias de estilo, y ofrece opciones interactivas. El usuario puede responder por voz (Apple Speech) o tocando opciones en pantalla.

---

## Arquitectura

```
guaperrimo_aiApp.swift
    └── CameraView
            └── fullScreenCover → PhotoPreviewView
                    └── fullScreenCover → ConversationView (NUEVO)
                            ├── ScrollView de mensajes
                            │     ├── MessageBubbleView (estilista)
                            │     │     └── StyleOptionCardView x4
                            │     └── MessageBubbleView (usuario)
                            ├── ThinkingIndicatorView
                            └── ConversationInputBar (mic + texto)

ConversationViewModel (@Observable)
    ├── messages: [ConversationMessage]
    ├── isThinking: Bool
    ├── speechService: SpeechRecognitionService
    ├── stylistService: StylistService (protocolo)
    └── ttsService: TTSService (protocolo)

Servicios (protocolos + stubs)
    ├── StylistService → StubStylistService (delays simulados)
    ├── TTSService → StubTTSService (AVSpeechSynthesizer)
    └── SpeechRecognitionService (Apple Speech framework)
```

---

## Flujo Principal

```
┌──────────────────────────────────────────────────────────────┐
│                    CAPTURA DE FOTO                           │
│                                                              │
│  CameraView → auto-captura → PhotoPreviewView               │
│                                                              │
│  Usuario toca "Guardar"                                      │
│       │                                                      │
│       ▼                                                      │
│  uploadImage() → ImageUploadService → R2                     │
│       │                                                      │
│       ├── Exito: uploadedSessionId = response.sessionId      │
│       │          showConversation = true                      │
│       │                                                      │
│       └── Error: muestra errorMessage                        │
└──────┬───────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────┐
│               CONVERSACION (ConversationView)                │
│                                                              │
│  .onAppear                                                   │
│       │                                                      │
│       ├── speechService.requestAuthorization()               │
│       └── viewModel.startAnalysis()                          │
│               │                                              │
│               ▼                                              │
│       isThinking = true                                      │
│       ThinkingIndicatorView ("Analizando tu estilo...")       │
│               │                                              │
│               ▼                                              │
│       stylistService.analyzePhoto(sessionId:)                │
│       (stub: 2s delay)                                       │
│               │                                              │
│               ▼                                              │
│       Mensaje del estilista aparece en scroll                │
│       + 4 opciones de estilo como cards                      │
│       + TTS reproduce el mensaje (AVSpeechSynthesizer)       │
│               │                                              │
│               ▼                                              │
│  ┌─── USUARIO RESPONDE ──────────────────────────┐           │
│  │                                                │           │
│  │  Opcion A: Toca una StyleOptionCard            │           │
│  │       → selectOption() → mensaje de usuario    │           │
│  │                                                │           │
│  │  Opcion B: Escribe texto + Send                │           │
│  │       → sendMessage() → mensaje de usuario     │           │
│  │                                                │           │
│  │  Opcion C: Mic → habla → transcript → Send     │           │
│  │       → sendMessage() → mensaje de usuario     │           │
│  │                                                │           │
│  └────────────────┬───────────────────────────────┘           │
│                   │                                           │
│                   ▼                                           │
│           continueConversation()                             │
│                   │                                           │
│                   ├── ttsService.stop()                       │
│                   ├── isThinking = true                       │
│                   ├── stylistService.sendMessage()            │
│                   │   (stub: 1.5s delay)                     │
│                   ├── Nuevo mensaje estilista + opciones      │
│                   ├── isThinking = false                      │
│                   └── ttsService.speak() (reproduce TTS)      │
│                   │                                           │
│                   ▼                                           │
│           (ciclo se repite)                                   │
│                                                              │
│  Boton X → dismiss() → vuelve a PhotoPreviewView            │
└──────────────────────────────────────────────────────────────┘
```

---

## Flujo de Voz (Speech-to-Text)

```
Usuario toca mic
       │
       ▼
speechService.isListening == false?
       │
       ├── SI → startListening()
       │         │
       │         ├── AVAudioSession → .record mode
       │         ├── audioEngine.inputNode → instala tap
       │         ├── SFSpeechRecognitionTask inicia
       │         ├── transcript se actualiza en tiempo real
       │         └── mic se pone rojo + "Listening..."
       │
       └── NO → stopListening()
                 │
                 ├── audioEngine.stop()
                 ├── recognitionTask.cancel()
                 └── transcript final → inputText
                       │
                       ▼
                 Usuario toca Send → sendMessage(inputText)
```

---

## Flujo de TTS (Text-to-Speech)

```
Mensaje del estilista recibido
       │
       ▼
ttsService.speak(message)
       │
       ├── AVSpeechUtterance (en-US)
       ├── AVSpeechSynthesizer.speak()
       ├── async/await via CheckedContinuation
       └── Cuando termina → continuation.resume()

Si usuario envia nuevo mensaje:
       │
       ▼
ttsService.stop()
       │
       └── synthesizer.stopSpeaking(.immediate)
           continuation?.resume()
```

---

## Archivos

### Nuevos (11)

| Archivo | Responsabilidad |
|---------|----------------|
| `Models/ConversationMessage.swift` | `ConversationMessage`, `MessageRole`, `StyleOption` |
| `Models/StyleAnalysis.swift` | `StyleAnalysis`, `StyleAnalysisOption` (response backend) |
| `Services/StylistService.swift` | Protocolo `StylistService` + `StubStylistService` |
| `Services/TTSService.swift` | Protocolo `TTSService` + `StubTTSService` (AVSpeechSynthesizer) |
| `Services/SpeechRecognitionService.swift` | `@Observable` wrapper de Apple Speech |
| `ViewModels/ConversationViewModel.swift` | Estado de conversacion, orquesta servicios |
| `Views/ConversationView.swift` | Pantalla principal de chat post-foto |
| `Views/MessageBubbleView.swift` | Burbuja de mensaje (estilista/usuario) |
| `Views/StyleOptionCardView.swift` | Card tappable de opcion de estilo |
| `Views/ThinkingIndicatorView.swift` | Dots animados + "Analizando tu estilo..." |
| `Views/ConversationInputBar.swift` | Barra inferior: mic + text field + send |

### Modificados (4)

| Archivo | Cambio |
|---------|--------|
| `Views/PhotoPreviewView.swift` | Eliminado `onSave`, agregado `showConversation` + `uploadedSessionId`, presenta `ConversationView` via `fullScreenCover` |
| `Views/CameraView.swift` | Eliminado parametro `onSave` del init de `PhotoPreviewView` |
| `en.lproj/Localizable.strings` | Strings de conversacion (thinking, voice, send, type) |
| `es.lproj/Localizable.strings` | Strings de conversacion en espanol |
| `InfoAdditions.plist` | Permisos de mic + speech recognition |

---

## Navegacion (fullScreenCover apilados)

```
CameraView
    │
    │  $cameraManager.isPhotoTaken
    ▼
┌─────────────────────────────┐
│     PhotoPreviewView        │
│                             │
│  [Repetir]    [Guardar]     │
│                    │        │
│        upload exitoso       │
│                    │        │
│     $showConversation       │
│            ▼                │
│  ┌───────────────────────┐  │
│  │   ConversationView    │  │
│  │                       │  │
│  │  [X] ← dismiss()     │  │
│  │                       │  │
│  │  Messages scroll      │  │
│  │  ThinkingIndicator    │  │
│  │  InputBar             │  │
│  └───────────────────────┘  │
└─────────────────────────────┘
```

---

## Modelos de Datos

### ConversationMessage

```
ConversationMessage
    ├── id: UUID
    ├── role: MessageRole (.stylist | .user)
    ├── text: String
    ├── options: [StyleOption]  (solo mensajes del estilista)
    └── timestamp: Date
```

### StyleOption

```
StyleOption (Identifiable)
    ├── id: String        (e.g. "casual_elevated")
    ├── title: String     (e.g. "Casual Elevated")
    └── description: String (e.g. "Keep it comfy but add polish")
```

### StyleAnalysis (response del backend)

```
StyleAnalysis (Codable)
    ├── message: String
    └── options: [StyleAnalysisOption]
          ├── id: String
          ├── title: String
          └── description: String
```

---

## Protocolos (seams para swap futuro)

### StylistService

```swift
protocol StylistService: Sendable {
    func analyzePhoto(sessionId: String) async throws -> StyleAnalysis
    func sendMessage(sessionId: String, userMessage: String) async throws -> StyleAnalysis
}
```

Implementacion actual: `StubStylistService` con delays simulados y respuestas hardcoded.
Futuro: `LiveStylistService` conectado al backend Go con vision + LLM.

### TTSService

```swift
protocol TTSService {
    func speak(_ text: String) async
    func stop()
}
```

Implementacion actual: `StubTTSService` con `AVSpeechSynthesizer`.
Futuro: `ElevenLabsTTSService` con voz mas natural.

---

## UI Components

### ConversationView

- Fondo negro, pantalla completa
- Header: boton X (dismiss) + titulo "guaperrimo.ai"
- ScrollView con auto-scroll al ultimo mensaje
- Keyboard dismiss interactivo

### MessageBubbleView

- Estilista: burbuja oscura (white 15%), alineada a la izquierda
- Usuario: burbuja verde (green 60%), alineada a la derecha
- Opciones: se renderizan debajo del mensaje del estilista como `StyleOptionCardView`

### StyleOptionCardView

- Card con borde semi-transparente
- Titulo en bold + descripcion en caption
- Tappable → `viewModel.selectOption()`

### ThinkingIndicatorView

- 3 dots con animacion de escala escalonada (0.2s delay entre dots)
- Texto "Analizando tu estilo..." al lado
- Se muestra cuando `viewModel.isThinking == true`

### ConversationInputBar

- Boton mic (blanco normal, rojo cuando escucha)
- TextField con placeholder "Escribe un mensaje..."
- Boton send (circulo con flecha, deshabilitado si vacio)
- Fondo `.ultraThinMaterial`

---

## Permisos Agregados

| Permiso | Descripcion |
|---------|-------------|
| `NSSpeechRecognitionUsageDescription` | guaperrimo.ai usa reconocimiento de voz para conversar con tu estilista AI. |
| `NSMicrophoneUsageDescription` | guaperrimo.ai necesita el microfono para entrada de voz. |

---

## Localizacion Agregada

| Key | EN | ES |
|-----|----|----|
| `thinking` | Analyzing your style... | Analizando tu estilo... |
| `voice_input_hint` | Tap to speak | Toca para hablar |
| `voice_listening` | Listening... | Escuchando... |
| `send_message` | Send | Enviar |
| `type_message` | Type a message... | Escribe un mensaje... |

---

## Proximos Pasos

1. **Backend Go**: Implementar endpoints de analisis de foto (vision) y chat (LLM)
2. **LiveStylistService**: Conectar al backend real, reemplazar stub
3. **ElevenLabsTTSService**: Integrar TTS con voces naturales via API
4. **Imagenes de productos**: Agregar soporte para mostrar imagenes de ropa sugerida en el chat
5. **Persistencia**: Guardar historial de conversaciones
