# Extraccion de Style Fashion User

Funcionalidad de captura guiada de foto de cuerpo completo para analisis de estilo. El usuario coloca el telefono a ~105 cm del suelo, se aleja 120 cm y la app lo guia hasta una posicion optima usando deteccion de pose corporal en tiempo real (Vision framework). Cuando el usuario esta alineado y quieto, la foto se captura automaticamente.

---

## Arquitectura

```
guaperrimo_aiApp.swift
    └── CameraView (Vista principal)
            ├── CameraPreview (AVCaptureVideoPreviewLayer)
            ├── BodySilhouetteOverlay (Guia visual)
            ├── SetupInstructionView (Onboarding)
            ├── PhotoPreviewView (Preview + guardar)
            └── CameraPermissionView (Permisos denegados)

CameraManager (Sesion AVFoundation)
    ├── AVCaptureSession (front camera, .high preset)
    ├── AVCapturePhotoOutput
    ├── AVCaptureVideoDataOutput → BodyPoseDetector
    └── Debug overlay compositing

BodyPoseDetector (Deteccion de pose + maquina de estados)
    ├── VNDetectHumanBodyPoseRequest (~15 fps)
    ├── State evaluation (priority chain)
    ├── Hysteresis (anti-oscillation)
    └── Stillness buffer (circular)

PositioningConfig (Constantes de configuracion)
```

---

## Archivos

| Archivo | Responsabilidad |
|---------|----------------|
| `Camera/CameraManager.swift` | Sesion AVFoundation, captura de foto, debug overlay |
| `Camera/BodyPoseDetector.swift` | Deteccion de pose Vision, maquina de estados, stillness |
| `Camera/CameraPreview.swift` | UIViewRepresentable para AVCaptureVideoPreviewLayer |
| `Camera/PositioningConfig.swift` | Constantes de configuracion (thresholds, tiempos) |
| `Views/CameraView.swift` | Vista principal, countdown, estado UI, debug panel |
| `Views/BodySilhouetteOverlay.swift` | Shape de silueta humana + overlay animado |
| `Views/PhotoPreviewView.swift` | Preview de foto capturada, guardar en Photos |
| `Views/CameraPermissionView.swift` | Vista de permisos denegados |
| `en.lproj/Localizable.strings` | Textos en ingles |
| `es.lproj/Localizable.strings` | Textos en espanol |

---

## Pipeline de Deteccion

### 1. Captura de frames

`CameraManager` configura un `AVCaptureSession` con la camara frontal (`.builtInWideAngleCamera`, posicion `.front`). Los frames se entregan via `AVCaptureVideoDataOutput` al `BodyPoseDetector`.

**Orientacion critica:** Los frames se rotan a portrait antes de entrega:

```swift
if let videoConnection = videoDataOutput.connection(with: .video) {
    videoConnection.videoRotationAngle = 90
}
```

Sin esta rotacion, Vision procesa frames en landscape y todas las coordenadas de joints quedan rotadas 90 grados (la nariz aparece en el antebrazo, el ancho de hombros mide 3px, etc).

El preview layer deshabilita el mirror automatico para mostrar la imagen real (no espejada):

```swift
connection.automaticallyAdjustsVideoMirroring = false
connection.isVideoMirrored = false
```

### 2. Deteccion de pose (BodyPoseDetector)

Procesa 1 de cada 2 frames (~15 fps) usando `VNDetectHumanBodyPoseRequest`. Cada frame pasa por la cadena de evaluacion de estado.

### 3. Evaluacion de estado (cadena de prioridad)

| Prioridad | Condicion | Estado resultante |
|-----------|-----------|-------------------|
| 1 | Hombros no detectados (conf < 0.2) | `noPerson` |
| 2 | Ningun hip visible (conf < 0.2) | `tooClose` |
| 3 | Cuello Y < 0.40 (Vision coords, 0=abajo) | `tooFar` |
| 4 | Punto medio hombros fuera de 40-60% | `offCenter(.left/.right)` |
| 5 | Todo OK, pero moviendose | `aligned` |
| 6 | Todo OK + quieto 30 frames | `stillConfirmed` |

### 4. Hysteresis (anti-oscillation)

Para evitar flickering en la UI, el estado solo se publica despues de **8 frames consecutivos** con el mismo estado (`stateConfirmationFrames = 8`).

```
Frame 1-7: candidateState = .tooClose, candidateFrameCount incrementando
Frame 8:   candidateFrameCount >= 8 → confirmedState = .tooClose → se publica
```

El buffer de stillness solo se resetea cuando el estado **confirmado** sale de `aligned`/`stillConfirmed`, no en cada frame raw.

### 5. Deteccion de stillness

Buffer circular de posiciones de 6 joints (nose, neck, L/R shoulder, L/R hip) a lo largo de 30 frames. Calcula el desplazamiento promedio entre frames consecutivos. Si el desplazamiento promedio < 8.0 px → `stillConfirmed`.

---

## Maquina de Estados (UI)

```
noPerson ──→ tooClose ──→ tooFar ──→ offCenter ──→ aligned ──→ stillConfirmed
    ↑                                                              │
    └──────────────────── (cualquier interrupcion) ────────────────┘
                                                                   │
                                                            countdown 3s
                                                                   │
                                                            auto-capture
```

### Comportamiento por estado

| Estado | Silueta | Texto | Accion |
|--------|---------|-------|--------|
| `noPerson` | Blanca, parpadea | "Colocate frente a la camara" | - |
| `tooClose` | Blanca 25% | "Alejate un poco" | - |
| `tooFar` | Blanca 25% | "Acercate un poco" | - |
| `offCenter(.left)` | Blanca 25% | "Muevete a la derecha" | - |
| `offCenter(.right)` | Blanca 25% | "Muevete a la izquierda" | - |
| `aligned` | Verde 70% | "Quedatquieto..." | - |
| `stillConfirmed` | Verde 100%, pulsa | "No te muevas..." | Inicia countdown 3s |

### Countdown y captura

- `stillConfirmed` inicia countdown de 3 segundos con progreso circular
- Si el desplazamiento supera 15 px durante countdown → se cancela
- Si el estado sale de `aligned`/`stillConfirmed` → se cancela
- Al llegar a 0 → `capturePhoto()` + flash visual

---

## Constantes de Configuracion (PositioningConfig)

| Constante | Valor | Descripcion |
|-----------|-------|-------------|
| `stillnessWindowFrames` | 30 | Frames en buffer de stillness (~2s a 15fps) |
| `stillnessThresholdPx` | 8.0 | Desplazamiento maximo para considerar "quieto" |
| `movementCancelThresholdPx` | 15.0 | Umbral para cancelar countdown |
| `centerTolerance` | 0.10 | Tolerancia horizontal (40-60% del frame) |
| `neckYMin` | 0.40 | Posicion minima del cuello (Vision Y, 0=abajo) |
| `jointConfidenceMin` | 0.2 | Confianza minima de joint para considerarlo valido |
| `stateConfirmationFrames` | 8 | Frames consecutivos para confirmar cambio de estado |
| `countdownSeconds` | 3 | Duracion del countdown pre-captura |
| `trackedJointCount` | 6 | Joints rastreados para stillness |

---

## Silueta (BodySilhouetteOverlay)

Forma vectorial (`Shape`) de silueta humana de cabeza a rodillas. Proporciones:

- Altura: 70% de la pantalla
- Aspect ratio: 0.45 (ancho = altura * 0.45)
- Margen inferior: 12% de la pantalla
- Incluye: cabeza (elipse), cuello, hombros, brazos hasta munecas, torso, caderas, muslos hasta rodillas

Animaciones:
- **Parpadeo**: opacidad 0.1-1.0, cuando `noPerson`
- **Pulso**: escala 1.0-1.02, durante countdown

---

## Preview y Guardado (PhotoPreviewView)

Despues de la captura, se presenta como `fullScreenCover`:
- Muestra la foto a tamano completo
- Boton "Repetir": descarta la foto y vuelve a la camara
- Boton "Guardar": guarda en Photos via `PHPhotoLibrary` (JPEG, calidad 0.95)
- Feedback visual de "Foto guardada" con animacion

---

## Debug Tools (solo en DEBUG builds)

### Debug Panel (CameraView)

Panel overlay en esquina superior derecha (toggle con shake del dispositivo):
- Estado confirmado y raw
- Desplazamiento promedio (px)
- Ancho de hombros (px)
- Centro X (normalizado)
- Cuello Y (normalizado)
- Progreso de stillness (%)
- Lista de joints con indicador de confianza (verde/rojo)

### Timer 5s (Debug capture)

Boton de timer que captura despues de 5 segundos ignorando la deteccion de pose. La foto resultante incluye overlay de debug:
- Puntos de joints (verde=confianza OK, rojo=baja)
- Nombres de joints + valor de confianza
- Lineas de esqueleto (cyan) conectando joints
- Panel de texto con todos los valores de debug
- Contorno de silueta (rojo, linea discontinua)
- Cruz en el centro del area visible
- Borde del area visible (amarillo)

### Console Logging

Logger con subsystem `ai.guaperrimo`, categoria `BodyPoseDetector`. Logea en cada frame:
- Estado raw con metricas relevantes (confianzas, neckY, midX, displacement, stillness %)
- Transiciones de estado confirmado

---

## Localizacion

Soporta ingles y espanol via `Localizable.strings`. Textos clave:

| Key | EN | ES |
|-----|----|----|
| `onboarding_instruction` | Place your phone on a surface at ~105 cm... | Apoya el telefono en una superficie a ~105 cm... |
| `no_person` | Step in front of the camera | Colocate frente a la camara |
| `too_close` | Step back a little | Alejate un poco |
| `too_far` | Move a bit closer | Acercate un poco |
| `stay_still` | Stay still... | Quedate quieto... |
| `hold_still` | Hold still... | No te muevas... |

---

## Permisos

| Permiso | Uso |
|---------|-----|
| `NSCameraUsageDescription` | Captura de fotos de outfit |
| `NSPhotoLibraryAddUsageDescription` | Guardar fotos en biblioteca |

App bloqueada a orientacion portrait (`UIInterfaceOrientationPortrait`).

---

## Bugs Criticos Resueltos

### 1. Orientacion de camara (ROOT CAUSE)

**Problema:** La camara frontal entrega frames en landscape por defecto. Vision procesaba estos frames sin rotacion, resultando en coordenadas de joints rotadas 90 grados. La nariz aparecia en la posicion del antebrazo, el ancho de hombros media ~3px (joints apilados verticalmente), y las rodillas quedaban fuera del frame hacia la derecha.

**Solucion:** Rotar frames a portrait antes de entregarlos:

```swift
videoConnection.videoRotationAngle = 90  // en videoDataOutput
photoConnection.videoRotationAngle = 90  // en photoOutput
```

### 2. Reset de buffer en cada frame

**Problema:** El buffer de stillness se reseteaba en cada frame raw que no era `aligned`, haciendo imposible alcanzar `stillConfirmed` porque cualquier fluctuacion momentanea (pre-hysteresis) vaciaba el buffer.

**Solucion:** Solo resetear el buffer cuando el estado **confirmado** (post-hysteresis) sale de `aligned`/`stillConfirmed`.

### 3. Threshold de confianza demasiado alto

**Problema:** A ~120cm de distancia con camara frontal, la confianza de joints fluctuaba entre 0.10-0.39, por debajo del threshold inicial de 0.4.

**Solucion:** Bajar `jointConfidenceMin` de 0.4 a 0.2.

### 4. Deteccion de rodillas imposible

**Problema:** Con el telefono apoyado en una superficie a 105cm, las rodillas quedan fuera del campo de vision de la camara frontal (confianza 0.00).

**Solucion:** Cambiar la verificacion de "demasiado cerca" de requerir ambas rodillas a requerir al menos un hip.

### 5. Threshold de cuello demasiado estricto

**Problema:** Con el telefono en una superficie mirando ligeramente hacia arriba, el cuello aparecia en Vision Y ~0.47-0.57, por debajo del threshold de 0.65.

**Solucion:** Bajar `neckYMin` de 0.65 a 0.40.
