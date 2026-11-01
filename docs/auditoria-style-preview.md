# Auditoría UX — `StylePreviewView` ("Tu estilo")

**Fecha:** 1 de noviembre de 2026
**Método:** lectura estática de `StylePreviewView.swift` (611 líneas), `StyleDirectionModels.swift`, la parte de preview de `ConversationViewModel.swift` y `ConversationView.swift`, los strings es/en y el payload real de `StyleDirectionDecodingTests.swift`; en el backend, `docs/API.md` e `internal/agent/prompt.go` (solo lectura). No se ejecutó la app (§6).
**Base:** `main` en `46f97ca` (la pantalla llegó en `cf0f71f` y `b821bca`, "outfit-first preview").
**Documentos hermanos:** [`auditoria-ux-flujo-ios.md`](auditoria-ux-flujo-ios.md) (IDs S-, T-…) y [`reporte-mejoras-ux-ios.md`](reporte-mejoras-ux-ios.md) (§5 sistema de diseño, §9 UI generativa). Escala: 🔴 bloquea o corrompe la tarea principal · 🟠 fricción clara · 🟡 pulido. IDs de esta auditoría: `SP-n`.

---

## 1. Resumen en 5 líneas

1. `StylePreviewView` es un `fullScreenCover` que aparece cuando el estilista ya sabe ocasión y presupuesto: muestra un brief (paleta, colores a evitar, silueta) y 9 ideas de prenda (3 camisas, 3 pantalones, 3 chamarras) con foto de referencia real, más un comentario libre.
2. Importa porque es el **único momento en que el usuario expresa gusto con algo que ve**: lo que toca (y lo que no) decide qué busca el backend y qué se renderiza sobre su foto. La señal `rejected` se calcula con todo lo no elegido.
3. La base es buena: decodificación tolerante, selección que sobrevive a un error, hápticos, estado `.isSelected`, ronda nueva reinicia el scroll.
4. Pero la pantalla es larga (≈ 2,5 pantallas estimadas), la jerarquía pone el brief antes que las ideas, las filas horizontales ocultan la tercera tarjeta de cada fila, y la foto de referencia puede **contradecir** el texto de la idea (payload real).
5. **Veredicto: 🟠 funcional pero no lista.** Tres arreglos de bajo costo (indicador de fila, foto/texto coherentes, mic o aviso de que no hay mic) suben la calidad del dato y de la experiencia más que cualquier cambio visual.

---

## 2. Qué ve el usuario

### 2.1 Layout de arriba abajo (`StylePreviewView.swift:33-69`)

| Zona | Contenido | Líneas |
|------|-----------|--------|
| Header | X (36×36, `white 0.1`), "Tu estilo" (`.headline`), hueco simétrico | 73-97 |
| Mensaje del estilista | `message` en `.title3`, sin límite de líneas (≈ 170 caracteres en el payload real: "Con $2,000, te propongo prendas clave… dime si quieres ajustar algo.") | 42-47 |
| Brief (`briefCard`) | etiqueta "Colorimetría: …" (opcional), `summary` (`.subheadline`, ≈ 330 caracteres reales), "TU PALETA" (carrusel horizontal de círculos de 36 pt con nombre a 2 líneas, 64 pt de ancho), "EVITA" (círculos tachados de 22 pt + nombre + `why`), silueta con ícono `figure.stand` | 101-176 |
| Ideas | "Ideas para ti" + hint, y **una fila horizontal por parte del outfit** ("Camisas y playeras", "Pantalones", "Chamarras y sacos"), tarjetas de **180 pt** de ancho | 187-224 |
| Comentario | "¿Algo que quieras ajustar?" + `TextField` de 1 a 4 líneas | 228-254 |
| Barra inferior (`safeAreaInset`) | error (naranja, `.caption`), y botón blanco en cápsula **o** `ThinkingIndicatorView` | 258-293 |

**Tarjeta de idea** (`IdeaCardView`, 305-442): foto 190 pt de alto (`aspectRatio(.fill)`, recortada), círculo de selección arriba a la derecha (24 pt), `garment` (máx. 2 líneas), colores (círculo 14 pt + nombre), chips de textura y "Corte: …", rango de precio ("$700–1,200 MXN"), `why` (máx. 2 líneas) y "Foto de referencia: <tienda>" (1 línea). Alto estimado de una tarjeta: ≈ 400 pt (190 de foto + ≈ 210 de texto y paddings). Con 3 filas, las ideas ocupan ≈ 1.300 pt.

**Estimación de pantalla** (iPhone de 6,1", ≈ 390×844 pt): header 60 + mensaje ≈ 100 + brief ≈ 420 → la primera fila de ideas empieza hacia el pt 620, es decir, **al borde del primer pliegue**. En una fila caben 1,9 tarjetas de 180 pt (350 pt útiles).

### 2.2 Estados

| Estado | Qué pasa | Evidencia |
|--------|----------|-----------|
| Cargando / esperando referencias | **No existe en el cliente.** El servidor agrega la foto real a cada idea antes de responder (`prompt.go:103`), así que la espera ocurre en la pantalla de conversación ("Analizando tu estilo…") antes de que aparezca el preview. Dentro del preview solo hay un gris `white 0.08` por imagen mientras `AsyncImage` descarga. | `StylePreviewView.swift:421-423` |
| Lista | Brief + filas + comentario; botón deshabilitado al 40 % hasta que haya una idea o un comentario. | `:29-31`, `:282-283` |
| Enviando | La barra inferior cambia el botón por `ThinkingIndicatorView` (mensaje genérico "thinking"); tarjetas y campo deshabilitados; **la X sigue activa**. | `:267-269`, `:215`, `:251` |
| Error | `previewError` ("No pudimos enviar tu selección. Intenta de nuevo.") en naranja `.caption` sobre el botón, que reaparece. La selección y el comentario se conservan. | `ConversationViewModel.swift:239-243` |
| Sin ideas | `direction.ideas` vacío → se oculta la sección y quedan mensaje, brief (si hay) y comentario. Solo se escribe un `logger.warning`. | `ConversationViewModel.swift:266-268`, `StylePreviewView.swift:53` |
| Sin brief | `brief == nil` → no se dibuja la tarjeta, sin placeholder. | `:49` |

### 2.3 Interacciones

- **Seleccionar:** tap en toda la tarjeta (`contentShape`, `:377`) → háptico ligero + `toggleIdea`. Marca visual: borde verde 2 pt, fondo verde 12 %, círculo ✓ verde. Sin mínimo ni máximo; el contador solo vive en el texto del botón: "Armar mis outfits (3)" (`es.lproj/Localizable.strings:104`).
- **Comentar:** campo de texto con teclado; `scrollDismissesKeyboard(.interactively)`. Si no hay ideas elegidas pero sí comentario, el botón cambia a "Enviar a tu estilista" (`:295-300`).
- **Enviar:** `sendIdeaSelection` → `{type: "idea_selection", selected_ideas, text}`; todo lo no elegido viaja como `rejected` en el log y, en el backend, como señal de rechazo (`API.md:111-114`).
- **Cerrar con X:** `showStylePreview = false` (`ConversationView.swift:56`). **La selección y el comentario no se pierden** (viven en el view model), la conversación queda en `currentInputMode == .preview` y el botón blanco "Ver mis ideas ✦" reabre la pantalla (`ConversationView.swift:239-252`). No hay indicador de que hay una selección pendiente.
- **Nueva ronda** (`input_mode: preview` otra vez): selección y comentario se reinician (`ConversationViewModel.swift:270-271`) y el scroll vuelve arriba (`.id(direction.round)`, `:62`).

### 2.4 Convivencia con el TTS

`handleResponse` abre el preview **antes** de hablar (`ConversationViewModel.swift:272` y luego `speak`, `:291`). El usuario ve la pantalla mientras el estilista lee el mismo `message` que está en pantalla (≈ 10-12 s). Puede tocar ideas durante la lectura; el guard `state == .speaking` (`:300`) evita que el fin del TTS pise el estado si ya envió. `sendRequest` llama `ttsService.stop()` (`:224`), pero **cerrar con X no detiene la voz** y alternar ideas tampoco. Cuando el TTS termina el estado pasa a `waitingForInput` sin ningún cambio visible en el preview.

---

## 3. Hallazgos

| ID | Sev. | Hallazgo | Evidencia |
|----|------|----------|-----------|
| SP-1 | 🔴 | **La foto de referencia puede contradecir la idea.** En el payload real: "Camisa de lino manga **larga**" muestra una camisa Etsy "**manga corta**… hecha a medida"; "Cinturón… **Caramelo**" muestra un "Cinturón Jbe… **Negro**" (negro es justo un color de `avoid`); "Chinos de algodón" muestra "Pantalon con Dobladillo Estilo Bahamas". El usuario decide mirando la foto, y el backend usa esa referencia como producto candidato (`prompt.go:104`). El rótulo "Foto de referencia: Etsy" no avisa de que color, manga o corte pueden diferir. | `StyleDirectionDecodingTests.swift` (ideas 1, 3, 4); `StylePreviewView.swift:363-367, 392-397` |
| SP-2 | 🔴 | **La tercera tarjeta de cada fila no se descubre y cuenta como rechazada.** Filas con `ScrollView(.horizontal, showsIndicators: false)` (`:203`) y tarjetas de 180 pt (`:214`): en un iPhone de 390 pt se ven 1,9 tarjetas, sin indicador, sin paginación ni "1/3". `sendIdeaSelection` marca como `rejected` **todo** lo no elegido (`ConversationViewModel.swift:209`), incluidas ideas que el usuario nunca vio. Contamina la señal "qué le atrae" que `API.md:113` describe como el objetivo. | `StylePreviewView.swift:203-220`; `ConversationViewModel.swift:209` |
| SP-3 | 🟠 | **Jerarquía invertida.** Mensaje (`.title3`) + brief (≈ 420 pt estimados) van antes de la acción principal (elegir ideas). La paleta, que es lo más escaneable, queda enterrada dentro de la tarjeta tras ≈ 330 caracteres de `summary`; la primera tarjeta aparece a ≈ 620 pt. Mensaje y `summary` repiten contenido (ambos hablan de elegante/fresco). | `:41-57`, `:101-176` |
| SP-4 | 🟠 | **El mensaje invita a hablar y no hay micrófono.** El texto del estilista (leído en voz alta) dice "…o dime si quieres ajustar algo", pero en `input_mode: preview` el único input es teclado (`ConversationView.swift:239`); `speechService` no se usa aquí. En una app de voz, escribir con el teclado sobre una pantalla de 2,5 alturas es el camino más caro. | `ConversationView.swift:225-241`; `StylePreviewView.swift:234-251` |
| SP-5 | 🟠 | **`why` truncado a 2 líneas sin salida.** Con 160 pt de texto útil (180 − 2×10) y `.caption`, el `why` real de 118 caracteres ("El lino es fresco, elegante y tiene textura, ideal para una boda de día. Este color profundo resalta tu tono de piel.") necesita ≈ 4-5 líneas; se corta con "…" y no hay detalle expandible. Lo mismo con "Foto de referencia: TheSigSag" (1 línea, ≈ 165 pt) y `garment` largo (2 líneas). El precio solo aparece como rango; el precio del producto de referencia (1.172,73 en idea_1) no se muestra. | `:326, 357, 367`, `ProductDTO.price` sin uso |
| SP-6 | 🟠 | **Selección sin guía.** Sin mínimo por fila, sin máximo, sin contador visible fuera del botón. "No me gusta ninguna" solo existe si el usuario escribe en el comentario; el backend completa con una prenda neutra la parte sin selección (`prompt.go:104`) y el título "Armar mis outfits (n)" cuenta ideas, no outfits. El hint dice "Toca las que te gusten en cada fila" pero ninguna fila lo exige. | `:193`, `:295-300`; `es.lproj:93,104` |
| SP-7 | 🟠 | **Cerrar con X durante el envío rompe la retroalimentación.** La X no se deshabilita (`:75`) y no cancela la petición. Si falla, `previewError` solo se pinta dentro del preview (cerrado): el usuario queda en `waitingForInput` con "Ver mis ideas" y **sin ningún error visible**. Si la petición tiene éxito, el preview se reabre solo o la conversación avanza sin aviso. | `ConversationViewModel.swift:236-244`; `StylePreviewView.swift:75, 260` |
| SP-8 | 🟠 | **TTS no se corta al cerrar ni se puede saltar.** Mientras habla, la voz y la pantalla compiten (S-2 del flujo, aquí agravado: el usuario lee el brief y escucha el mensaje a la vez). La X cierra el preview pero la voz sigue (`speak`, `:291`). No hay indicador de "hablando". | `ConversationViewModel.swift:289-292` |
| SP-9 | 🟠 | **Accesibilidad.** (a) X de 36×36 pt (`:79`), por debajo de 44 pt; mismo patrón en 5 vistas más. (b) Tarjeta: el `Button` combina hijos, pero el `Image(systemName: "circle"/"checkmark.circle.fill")` aporta su nombre de símbolo al label y la foto no tiene descripción; no hay `accessibilityHint` ni etiqueta de fila (0 `accessibilityLabel` salvo la X, `:82`). (c) Dynamic Type: ancho fijo 180 (`:214`), foto fija 190 (`:430`), íconos `.system(size: 16/24/26)` (`:77, 316, 438`) y chips `.caption2`; a tamaños AX el texto se corta o la tarjeta crece sin límite. (d) La selección se indica con color **y** forma (✓), bien; pero el verde sobre foto depende del `background(Circle().fill(.black.opacity(0.35)))`. | `StylePreviewView.swift:77-82, 214, 316-319, 430` |
| SP-10 | 🟡 | **Contraste.** `white 0.45` para "Foto de referencia" sobre tarjeta `white 0.08` ≈ 4,5:1 en 11 pt (límite); placeholder del campo `white 0.4` ≈ 3,8:1 (no pasa AA para texto pequeño, mismo umbral que T-4); `sectionLabel` a `0.5` en `.caption2` (11 pt) con `tracking(1)` pasa por poco. | `:366, 237, 182` |
| SP-11 | 🟡 | **Idea sin foto indistinguible de foto caída.** Sin `reference` (idea_5 "Reloj minimalista" del payload) o con `AsyncImage` en `.failure` se muestra el mismo ícono `tshirt` (`:437`) también para cinturones y relojes, sin caption y sin reintento. No se sabe si falta o falló. La tarjeta pierde su ancla visual y es menos probable que se elija. | `:412-441` |
| SP-12 | 🟡 | **Sin feedback del estado general.** El botón "Armar mis outfits (3)" es la única señal de cuántas ideas hay elegidas; no hay resumen ("1 camisa, 2 pantalones…") ni scroll al botón. `ThinkingIndicatorView` en el envío dice lo mismo que el primer análisis ("Analizando tu estilo…"), cuando lo que ocurre es búsqueda de productos + render (hasta 25 s en SerpAPI). | `:267-269`; ver S-4 |
| SP-13 | 🟡 | **Coherencia con el sistema de diseño (reporte §5).** Header copiado a mano (7ª copia, T-3); botón primario **blanco**, no el gradiente de acento; verde = "seleccionado" (la regla §5.3 reserva el verde para "listo"); radios 10/12/14/16 (tokens: 12/16/24); superficies `white 0.08/0.12` (tokens: 0.06/0.10); `.system(size:)` y `Color.black` plano sin `TexturedBackground`; swatch "Colorimetría: Deep Autumn" mezcla jerga inglesa con UI en español. | `:35, 75-97, 175, 246, 280, 372-375` |
| SP-14 | 🟡 | **Rendimiento (por inspección).** `ideasBySlot` es una propiedad calculada que reagrupa y ordena en cada `body` (`StyleDirectionModels.swift:161`), y `previewComment` es un `@Binding` a un `@Observable`: cada tecla re-evalúa todo `StylePreviewView` (9 tarjetas + `ChipsFlow`). Las 9 fotos se piden a la vez (`HStack`, no `LazyHStack`) con `AsyncImage` (solo `URLCache`, sin reintento); las miniaturas `encrypted-tbn*.gstatic.com` suelen ser pequeñas y aquí se recortan a 180×190 pt → posible borrosidad a 3×. | `:205-216, 415-424` |
| SP-15 | 🟡 | **Ronda 2 olvida lo anterior.** Selección y comentario se vacían al llegar otra ronda (`:270-271`) y no se muestra qué eligió o rechazó antes; el usuario no ve que "ajustar" tuvo efecto. | `ConversationViewModel.swift:270-271` |
| SP-16 | 🟡 | **Reapertura sin estado.** "Ver mis ideas" no indica que hay selección guardada ("3 elegidas") ni que ya pasó el TTS; en `.preview` no hay otro CTA ni mensaje en la conversación. | `ConversationView.swift:248-262` |
| SP-17 | 🟡 | **Estado "sin ideas" mudo.** Si el backend manda `ideas: []`, la pantalla se reduce a mensaje + comentario sin explicar por qué faltan las tarjetas ni ofrecer "reintentar". | `StylePreviewView.swift:53`, `ConversationViewModel.swift:266` |

### Posibles bugs (más que UX)

1. **SP-7** (error silencioso tras cerrar la X durante el envío) es un hueco real de manejo de estado, no solo de diseño.
2. **SP-2** deforma el dato enviado: `rejected` incluye ideas nunca vistas.
3. **Fixture desactualizado.** El payload de `StyleDirectionDecodingTests` tiene 5 ideas con 2 `accessory` y sin `outerwear`; el prompt actual pide exactamente 9 (3+3+3) y prohíbe accesorios y calzado (`prompt.go:102`). `previewSlotOrder` (`StyleDirectionModels.swift:191`) conserva `footwear` y `accessory`, que ya no deberían llegar. No rompe nada, pero los tests no cubren el caso real de 9 ideas.
4. `ChipsFlow` mide cada hijo con `.unspecified` (`:481-493`): un chip más ancho que la tarjeta no se parte ni se trunca y se sale del borde (nombres de color o textura largos).

---

## 4. Fortalezas (qué conservar)

- **Decodificación defensiva** (`StyleDirectionModels.swift`): una idea mala se descarta, una referencia mala solo pierde la foto, `brief` ausente no rompe.
- **Agrupar por parte del outfit** (`ideasBySlot`): una fila por prenda es el modelo mental correcto y el backend ya lo hace consistente (3+3+3).
- **Tarjeta completa como zona táctil**, háptico, `.isSelected`, borde + ✓ + color (no solo color).
- **Reintento sin perder trabajo**: selección y comentario viven en el view model; error con la barra inferior intacta.
- **El comentario libre como válvula** (`canSend` acepta solo texto) y su botón adaptado ("Enviar a tu estilista").
- **Swatches con hex y fallback punteado** cuando falta el color (`SwatchCircle`, 446-473); círculos tachados para "Evita".
- **Reabrir el preview** tras cerrarlo en vez de perderlo; ronda nueva reinicia el scroll.
- `#Preview` con muestra de 9 ideas y una sin foto (`:527-609`), útil para iterar sin backend.

---

## 5. Recomendaciones mapeadas al plan del reporte

### Fase 0 (quick wins, medio día)
- X a 44×44 (`frame` + `contentShape`) y `accessibilityLabel` en tarjetas ("Camisa de lino manga larga, verde botella, $700 a $1,200; seleccionada") con el ícono `accessibilityHidden` (SP-9).
- Peek de la siguiente tarjeta a 160 pt y un contador "1 de 3" por fila, o `scrollTargetBehavior(.viewAligned)` (SP-2). Calcular `rejected` solo con ideas **mostradas** o enviar `shown_ids` (requiere pequeño cambio de contrato; ver SP-2).
- `lineLimit(3)` en `why` y `garment`, y caption de referencia a 2 líneas (SP-5).
- Deshabilitar la X mientras `isSending`, o mostrar el error del envío fuera del cover (banner en `ConversationView`) (SP-7).
- Cortar el TTS al cerrar la X o al tocar la primera idea (SP-8).
- Si no hay `reference`, mostrar "Sin foto de referencia" en el caption (SP-11).
- Texto del backend: quitar "dime…" del `message` en turnos `preview` o añadir un mic (SP-4).

### Fase 1 (sistema de diseño, reporte §5)
- Header con `ScreenHeader`; botón primario con `PrimaryButton`; `Chip` para texturas/fit; `surface`/`stroke`/radios por token; `success` solo para "listo": usar `accent` para "seleccionado" (SP-13).
- `@ScaledMetric` para íconos y ancho de tarjeta (SP-9), `textTertiary` ≥ 0.5 (SP-10).
- Un componente `IdeaCard` reutilizable (el mismo servirá en "Mis looks").

### Fase 2 / 3
- **Fase 2 (conversación):** el preview deja de ser un `fullScreenCover` y pasa a ser un turno dentro de la sesión, con `UserPhotoCard` arriba y mic disponible (resuelve SP-4, SP-8, SP-16). Primero la paleta y las ideas; el brief colapsado ("Ver por qué") (SP-3).
- **Fase 3:** al guardar el look, conservar `direction.selected` como "lo que elegiste" (SP-15) y mostrar en el resultado qué idea originó cada prenda.
- **Backend:** que `reference` sea coherente con la idea (filtrar por color/manga o marcarla `match: "approximate"`) y exponer `shown_ids` (SP-1, SP-2). Revisar el fixture (3.).

### Expresión con el catálogo de UI generativa (reporte §9.3)

Con `text`, `palette`, `chips` y `product_card` casi todo cabe; faltan tres extensiones pequeñas (marcadas con `*`): `palette.avoid`, `product_card.selectable` y `chips` por fila con "Ninguna".

```json
{
  "session_id": "prev_37a9503f3fe5",
  "turn": 3,
  "phase": "preview",
  "ui_version": 1,
  "speech": "Con dos mil pesos te propongo prendas clave. Elige las que te gusten, o dime qué ajustar.",
  "ui": [
    { "type": "text", "role": "heading", "text": "Tu estilo" },
    { "type": "palette", "id": "brief_palette",
      "swatches": [{ "hex": "#3E5641", "name": "Verde botella" },
                   { "hex": "#B87D4F", "name": "Caramelo" },
                   { "hex": "#CC6B49", "name": "Terracota" }],
      "avoid": [{ "hex": "#000000", "name": "Negro puro", "why": "Apaga tu tono cálido" }],
      "note": "Cortes rectos, telas con caída." },
    { "type": "text", "role": "body", "text": "Toca las que te gusten en cada fila." },
    { "type": "text", "role": "heading", "text": "Camisas y playeras" },
    { "type": "product_card", "id": "idea_1", "group": "upper_body", "selectable": true,
      "title": "Camisa de lino manga larga", "image_url": "https://…",
      "subtitle": "Verde botella · lino · recta",
      "price_range_mxn": [700, 1200], "store": "Etsy",
      "reference_match": "approximate",
      "why": "Fresco y elegante; resalta tu tono de piel." },
    { "type": "product_card", "id": "idea_2", "group": "upper_body", "selectable": true, "…": "…" },
    { "type": "chips", "id": "upper_body_none", "select": "single",
      "options": [{ "id": "none", "label": "Ninguna de estas" }] },
    { "type": "text", "role": "heading", "text": "Pantalones" },
    { "type": "text", "role": "body", "text": "…" }
  ],
  "input": { "component_id": "ideas", "mode": "multi_select",
             "min_per_group": 0, "allow_voice": true, "allow_comment": true,
             "shown_ids": ["idea_1", "idea_2", "idea_3"] },
  "is_final": false
}
```

Respuesta del cliente: `{ "type": "ui_action", "component_id": "ideas", "value": { "selected": ["idea_1","idea_4"], "shown": ["idea_1", "…"], "none_groups": ["lower_body"], "text": "más casual" } }`. Con `speech` separado de `ui`, el TTS lee una frase corta y no duplica el brief en pantalla (SP-3, SP-8); `allow_voice` resuelve SP-4; `reference_match` y `shown` resuelven SP-1 y SP-2; "Ninguna de estas" resuelve SP-6.

---

## 6. Qué no pude verificar sin correr la app

1. **Alturas reales y pliegue**: las cifras de 400 pt por tarjeta, 420 pt de brief y ≈ 620 pt hasta la primera fila son estimaciones por tamaño de fuente; falta medir en un iPhone (SE, 15, 15 Pro Max) y con Dynamic Type grande.
2. **Cuánto se corta `why`/`garment`/caption** con textos reales en 160 pt y en AX sizes.
3. **Nitidez de las miniaturas** `encrypted-tbn*.gstatic.com` a 180×190 pt @3× y tiempos de carga de las 9 fotos en red móvil.
4. **VoiceOver**: qué lee realmente cada tarjeta (nombre del símbolo SF incluido) y el orden de foco.
5. **Re-renders por tecla** (SP-14): hace falta Instruments (SwiftUI) para confirmar que el cambio de `previewComment` no es perceptible.
6. **Latencia entre "Armar mis outfits" y el siguiente turno**, y si el usuario ve el estado "enviando" suficiente tiempo para confundirse (SP-12); depende del backend (SerpAPI 1-25 s).
7. **Coincidencia real foto/texto en sesiones reales** (SP-1): el payload analizado es una sola sesión; hay que contar en cuántas el `reference` contradice la idea.
8. **Comportamiento del TTS al cerrar la X** (SP-8) y de la X durante el envío (SP-7): inferido del código, sin reproducir.
