# Reporte de mejoras UX — app iOS guaperrimo.ai

**Fecha:** 11 de octubre de 2026 · **Actualizado:** 31 de octubre de 2026 (§9 UI generativa, fase 1.5)
**Base:** [`auditoria-ux-flujo-ios.md`](auditoria-ux-flujo-ios.md). Los IDs entre paréntesis (S-1, G-2…) remiten a hallazgos de ese documento.
**Foco pedido:** la captura y los looks van bien; las pantallas de **generar el outfit** (conversación) y **guardar outfits** (lista) se ven feas. Este reporte explica por qué y propone qué hacer, en orden.

---

## 1. Resumen ejecutivo

1. **Las dos pantallas "feas" no tienen un problema de estilo, tienen un problema de contenido.** La conversación es negra porque le quitaron la foto; la lista es densa porque muestra datos crudos del backend sin jerarquía. Cambiar colores no las arregla; cambiar qué se muestra, sí.
2. **Hay tres "guardar" y ninguno guarda un outfit.** Unificar en un solo gesto (♥ sobre el look en el Style Mirror) que guarde foto + prendas resuelve G-1, G-2 y la confusión del botón del preview (P-1).
3. **La foto del usuario debe estar presente en toda la sesión.** Es el hilo visual que conecta captura → conversación → looks → lista. Hoy desaparece entre el preview y el espejo.
4. **El Style Mirror ya define el nivel de calidad.** El trabajo no es inventar un estilo nuevo, sino extraer el que ya existe ahí (fondo con textura, cápsulas, gradiente, haptics) a componentes compartidos y aplicarlo a las otras cinco pantallas.
5. **Quick wins de un día** (§6, fase 0) quitan lo que más se nota: markdown crudo, indicador desalineado, botón "Guardar" mal nombrado, botón 5 s en release, acentos.
6. **El concepto de UI generativa (OpenUI) encaja, pero como contrato, no como framework.** El backend ya decide parte de la pantalla (`input_mode`, `options`, `priority_actions`); el paso natural es que el estilista componga la sesión y el plan con un catálogo cerrado de componentes nativos SwiftUI, mientras captura, espejo y navegación siguen siendo fijos. Detalle en §9; entra como fase 1.5 del plan.

---

## 2. Diagnóstico: por qué se sienten feas

### 2.1 Conversación ("generar el outfit")

```
Hoy                                    Por qué molesta
┌──────────────────────────┐
│ ✕      guaperrimo.ai     │  ← marca en vez de contexto (S-5)
│                          │
│                          │
│                          │  ← 40 % de la pantalla vacío
│   Veo un look casual     │
│   con buenas proporcio‑  │  ← habla de una foto que no está (S-1)
│   nes. ¿Qué estilo te    │
│   representa más?        │
│                          │
│                          │  ← mientras suena el TTS no hay nada más (S-2)
│   ( Casual elevado )     │
│   ( Streetwear )         │  ← aparecen al 40 % de opacidad y luego al 100 %,
│   ( Minimalista )        │     sin explicar la espera (S-8)
│   ( Smart casual )       │
│                          │
└──────────────────────────┘
```

Tres causas, en orden de peso:

1. **Falta el sujeto.** Un estilista mira tu ropa mientras te habla. La app te muestra un párrafo sobre fondo negro.
2. **Falta el tiempo.** No hay indicador de turno (1/3, 2/3), ni de que la voz está sonando, ni botón para saltarla. Cada espera parece un cuelgue.
3. **Falta memoria.** Sin historial, la pantalla se "resetea" en cada turno y nunca acumula sensación de progreso.

### 2.2 Guardar / Mi lista ("guardar los outfits")

```
Hoy                                              Por qué molesta
┌──────────────────────────────┐
│ ✕          Mi lista          │
│ ┌──────────────────────────┐ │
│ │ Vamos a ajustar el pre‑  │ │  ← mensaje completo del estilista como "resumen" (G-7)
│ │ supuesto para que todo   │ │
│ │ quede dentro de tus…     │ │
│ │ Guardada el 11 oct  Total│ │  ← el total, lo más útil, en .caption
│ └──────────────────────────┘ │
│ ENCIMA  Saco azul marino     │  ← dos niveles tipográficos en una línea (G-8)
│ slim (talla M o L …).        │
│ **Precio: $539**             │  ← markdown crudo (G-3)
│ El azul marino es elegante…  │
│ ┌────┐ Saco de Gabardina     │
│ │img │ Cierres Liso Caballero│  ← título de Mercado Libre sin limpiar (G-4)
│ └────┘ $539 MXN · Mercado L. │
│        🚶 Liverpool · 450 m  │
│   (Comprar)  (Cómo llegar)   │  ← "Comprar" abre Google Shopping (G-5)
│ …                            │
│ Tiendas cerca con algo…      │  ← la info clave del producto al final (G-9)
└──────────────────────────────┘
```

Causas:

1. **No guarda lo que el usuario quiere guardar.** Quiere el *outfit* (la imagen de él con la ropa). Guarda una lista de SKUs.
2. **Datos sin curar.** Descripciones con markdown, títulos de marketplace, tiendas vacías. El backend manda texto para un LLM, la app lo pega.
3. **Jerarquía invertida.** Lo caro (total), lo cercano (tienda a 450 m) y lo visual (imagen del look) están abajo o no están. Lo verboso (el porqué, la descripción) está arriba.

---

## 3. Principios para el rediseño

1. **La foto siempre presente.** Desde el preview hasta la lista, el usuario se ve a sí mismo. La conversación ocurre *sobre* su foto.
2. **Un solo "guardar", y guarda un outfit.** Corazón sobre un look = guardas ese look (imagen + prendas + tiendas). La lista de compras se deriva de los looks guardados.
3. **El estilista es una voz, no una pantalla.** El texto acompaña al audio (subtítulo), no lo sustituye. Siempre se puede saltar.
4. **Mostrar progreso honesto.** Turno 2 de 3. "Generando look 1 de 3". Nunca un porcentaje inventado.
5. **Un sistema, seis pantallas.** Header, botones, tarjetas, shimmer y fondo salen de un solo archivo.
6. **Lenguaje de estilista, no de PM.** "Lo que más cambia tu look" en vez de "Impacto: alto". "Fácil de conseguir" en vez de "Esfuerzo: bajo".
7. **El estilista compone, la app enmarca.** La sesión y el plan son un lienzo de componentes nativos que el backend ordena en cada turno (§9). Captura, Style Mirror, comparación, ♥ y navegación son nativos y fijos.

---

## 4. Rediseño propuesto, pantalla por pantalla

### 4.1 `PhotoPreviewView` → "¿Usamos esta foto?"

```
┌──────────────────────────┐
│ ✕                        │
│ ┌──────────────────────┐ │
│ │                      │ │
│ │     tu foto          │ │  ← 3:4, esquinas 24, misma tarjeta que usará
│ │     (zoom/pan)       │ │     el Style Mirror
│ │                      │ │
│ └──────────────────────┘ │
│  Asegúrate de que se vean│
│  zapatos y cabeza.       │  ← micro‑checklist, .footnote 70 %
│                          │
│ ┌──────────────────────┐ │
│ │ ✦ Analizar mi outfit │ │  ← primario, gradiente de marca
│ └──────────────────────┘ │
│      Tomar otra          │  ← secundario, solo texto
└──────────────────────────┘
```

- Renombrar "Guardar" → **"Analizar mi outfit"** con ícono `sparkles`; quitar "Foto guardada" y el ícono de compartir (P-1, P-2).
- Subir en segundo plano **al tocar**, y transicionar a la sesión de inmediato con la foto haciendo *hero transition* a su posición en la siguiente pantalla (`matchedGeometryEffect` o `NavigationTransition.zoom` en iOS 18+). La subida termina mientras el usuario ya ve la siguiente pantalla.
- Si el usuario regresa desde la sesión, el botón vuelve a estar activo y dice **"Continuar sesión"** (P-3).
- Error de red: texto humano ("No pudimos subir la foto. Revisa tu conexión.") + reintentar (P-5).

### 4.2 `ConversationView` → "Sesión con tu estilista"

```
┌──────────────────────────┐
│ ✕   Tu estilista   ● ● ○ │  ← puntos = turnos (2 de 3)
│ ┌──────────────────────┐ │
│ │                      │ │
│ │     tu foto          │ │  ← 45 % del alto, esquinas 24,
│ │                      │ │     mismo tamaño que en Style Mirror
│ │   ╭──────────────╮   │ │
│ │   │ ▂▃▅▃▂ ⏭      │   │ │  ← pastilla flotante: onda mientras habla
│ │   ╰──────────────╯   │ │     + saltar (S-2)
│ └──────────────────────┘ │
│                          │
│  Veo un look casual con  │  ← subtítulo .body, se revela palabra a
│  buenas proporciones.    │     palabra con el audio (o de golpe si TTS cae)
│  ¿Qué estilo te repre‑   │
│  senta más?              │
│                          │
│  ( Casual elevado )( Streetwear ) │  ← chips en flow layout, 2 columnas,
│  ( Minimalista )( Smart casual )  │     aparecen cuando termina el audio
│                          │
│  ▸ Ver conversación      │  ← historial colapsado (S-3)
└──────────────────────────┘
```

Cambios concretos:

| Qué | Resuelve | Cómo |
|-----|----------|------|
| Foto del usuario arriba, siempre | S-1 | Reusar el mismo componente `UserPhotoCard` del preview y del espejo. Cargar desde `UIImage` local (ya la tenemos), no desde la URL. |
| Pastilla "hablando" + botón saltar | S-2, S-8 | Mostrar ícono de onda animada mientras `isSpeaking`; "⏭" llama a `ttsService.stop()` y pasa a `waitingForInput`. Las opciones aparecen **al terminar** el audio con `.transition(.move(edge: .bottom).combined(with: .opacity))`, no al 40 %. |
| Indicador de turno | S-5 | El backend ya manda `turn` y `phase`. Header: "Tu estilista" + 3 puntos. |
| Historial colapsable | S-3 | Volver a acumular `[ConversationMessage]` (el modelo existe y está sin uso). Mostrar solo el último; "Ver conversación" expande una `sheet` con el hilo. |
| Loading con contexto | S-4 | `ThinkingIndicatorView` centrado, bajo la foto, con textos distintos: "Mirando tu outfit…" (turno 1), "Pensando…" (turnos siguientes), "Armando tu plan…" (último). Quitar el `Spacer()`. |
| Mic: tap para empezar, tap para terminar | S-6, S-7 | Reemplazar hold por toggle (con hold como atajo). Si el transcript queda vacío: haptic de error + "No te escuché, intenta otra vez". Enviar automático con barra de 2 s para cancelar; "Editar" como opción, no como paso obligatorio. |
| Pedir permisos de voz en el primer turno de voz | S-12 | Mover `requestAuthorization()` al momento en que `inputMode == .voice` por primera vez, precedido de una línea "Puedes responder hablando". |
| Reintentar sin perder turno | S-9 | Guardar el último `ChatRequest` y reenviarlo en `retry()`. |

### 4.3 Pantalla final → "Tu plan de estilo"

```
┌──────────────────────────┐
│ ✕   Tu plan de estilo    │
│ ┌──────────────────────┐ │
│ │ ◀  tu foto → look 1 ▶│ │  ← HERO: Style Mirror embebido (misma vista,
│ │        ● ○ ○         │ │     modo compacto). Mientras genera: tu foto
│ │   Generando 1 de 3…  │ │     con shimmer + texto honesto (R-1, R-5)
│ └──────────────────────┘ │
│                          │
│  "Vamos a ajustar el     │  ← mensaje del estilista como cita, .body,
│   presupuesto para…"     │     máx. 3 líneas + "más"
│                          │
│  LO QUE MÁS CAMBIA TU LOOK          │  ← sección editorial
│  1  Cambia los tenis por botas      │
│     Chelsea ──────────── Ver en mí ▸│  ← try‑on como link, no botón gradiente
│  2  Agrega una capa intermedia      │
│  3  Suma un accesorio clave         │
│                                      │
│ ┌──────────────────────┐ │
│ │   ✦ Ver mis looks    │ │  ← primario (único gradiente de la pantalla)
│ └──────────────────────┘ │
│   Mi lista de compras ($2,247)      │  ← secundario con el total visible
└──────────────────────────┘
```

- **El hero es el espejo.** Embeber `StyleMirrorCanvasView` arriba, con la foto original como estado inicial y shimmer mientras llega el primer look. Al tocar, se expande al Style Mirror completo. **Quitar el auto‑open** a los 3 s; en su lugar, el hero hace crossfade al look 1 cuando llega + haptic (R-2).
- **Acciones como lista numerada**, sin tarjetas tintadas ni badges (R-3, R-4). El orden ya codifica prioridad. Opcional: un chip discreto "Fácil" cuando `effort == "bajo"`. Los strings "Impacto"/"Esfuerzo" desaparecen (resuelve también la localización).
- **Try‑on como acción secundaria** por fila ("Ver en mí ▸"), no un botón gradiente por tarjeta. El gradiente se reserva para **un** CTA por pantalla.
- Botón de lista muestra el total aproximado, que es lo que decide si el usuario sigue.

### 4.4 Guardar → "Mis looks" (reemplaza "Mi lista")

Modelo nuevo:

```
SavedLook
├── id, sessionId, savedAt
├── name, description            ← del LookItem
├── finalImageUrl, originalImageUrl   ← ¡la imagen! (G-2)
├── pieces: [LookPieceItem]      ← con productId, price, store, link
├── stores: [StoreDTO]           ← las cercanas de esa sesión
└── purchased: Set<String>
```

- **Un solo gesto para guardar:** ♥ en la barra superior del Style Mirror (y en el hero de la pantalla final). Guarda el look visible. Toast "Guardado en Mis looks" + haptic. Doble toque sobre la imagen también guarda (patrón Instagram).
- **Se pueden guardar varios looks.** `ShoppingListStore` → `SavedLooksStore` con `[SavedLook]`. Se elimina `SavedShoppingList` singleton (G-1).
- **Eliminar los otros dos "guardar":** el del preview pasa a "Analizar mi outfit" (4.1); el "Me gustó este outfit" se vuelve el ♥ del hero; "Guardar este look en mi lista" dentro de `LookPieceSheet` desaparece (ya está guardado al dar ♥).
- **Pantalla "Mis looks"** con dos pestañas:

```
┌──────────────────────────┐
│ ✕      Mis looks         │
│  [ Looks ]  [ Compras ]  │  ← segmented propio (no el del sistema)
│                          │
│ ┌──────────┐ ┌──────────┐│
│ │          │ │          ││  ← grid 2 col de SavedLook con tu foto,
│ │  look 1  │ │  look 2  ││     nombre y "$2,247 · 2 tiendas cerca"
│ │          │ │          ││
│ │ Casual   │ │ Smart    ││
│ │ $2,247   │ │ $1,890   ││
│ └──────────┘ └──────────┘│
│                          │
│  swipe ← para eliminar   │  ← G-6
└──────────────────────────┘
```

- **Pestaña Compras** (la `ShoppingListView` actual, limpiada):

```
┌──────────────────────────┐
│ Total aproximado  $2,247 │  ← .title2, arriba, lo primero
│ 3 prendas · 2 tiendas a < 1 km │
│                          │
│ 🚶 LIVERPOOL · 450 m · abierto hasta 21:00 │  ← agrupado por tienda (G-9)
│ ┌────┐ Saco azul marino slim     $539 │
│ │img │ Mercado Libre               ○  │  ← título = descripción del estilista
│ └────┘                                 │     (limpia), no el del marketplace
│ ┌────┐ Camisa beige de lino      $740 │
│ │img │ H&M                         ○  │
│ └────┘                                 │
│         [ Cómo llegar ]                │  ← una acción por tienda, no por producto
│                                        │
│ 📦 EN LÍNEA                            │
│ ┌────┐ Cinturón café de piel     $289 │
│ │img │ H&M · ver producto ↗          ○  │  ← "ver producto" si el link es búsqueda,
│ └────┘                                 │     "Comprar" solo si es tienda directa (G-5)
└──────────────────────────┘
```

- **Limpieza de datos en el cliente** (hasta que el backend lo haga): quitar `**…**` y la cola `Precio: $…` de `description` (G-3); usar `item.description` corta como título del producto y el título del marketplace en `.caption` (G-4); si `store` está vacío, no mostrar el separador; filtrar "Señoras"/"Mujer" en títulos cuando el usuario es hombre o pedir al backend que lo haga.
- **Comprado**: mover el ítem a una sección "Ya lo tienes" al final con animación, en vez de tachado al 4 % (G-11).

### 4.5 Style Mirror (ajustes menores, ya es la mejor pantalla)

- Barra superior: `✕` · nombre del look · **♥** (guardar) · `⇄` (comparar). El ♥ relleno si ya está guardado (L-1).
- Barra inferior: **nombres de los looks como chips deslizables** ("Original", "Casual elevado", "Smart casual") en lugar de solo puntos; tocar un chip salta a ese look (L-2).
- "Ver prendas" → **tira de miniaturas** de las prendas (56 pt) bajo la imagen; tocar una abre la sheet con ese producto enfocado. Deja de ser una cápsula gris.
- Abrir el espejo **en el primer look listo**, no en "Original" (L-3); el original queda a la izquierda para comparar.
- Looks fallidos: mostrar una tarjeta "No pudimos armar este look" con reintentar, en vez de desaparecer (L-5).
- Reservar área segura para header y chips (`.safeAreaInset`) para que no se monten sobre la imagen en iPhone SE/mini (L-4).

### 4.6 Try‑on

- Quitar el porcentaje; dejar la barra indeterminada con los textos por fase (R-8). Mejor aún: usar la misma animación de shimmer sobre tu foto que ya existe, sin barra.
- Unificar `TryOnResultView` y `LookComparisonView` en un `BeforeAfterView(before:after:title:)` (R-9) con un segmented propio del sistema de diseño (R-10).
- Añadir en el resultado: "♥ Guardar prenda" y "Ver dónde comprarla" (R-12).

### 4.7 Cámara y onboarding (la parte que ya va bien)

- **Guía por voz** con `AVSpeechSynthesizer` para los estados de posición ("Acércate un poco", "Perfecto, no te muevas") con debounce de 1.5 s; el usuario está a 120 cm y no lee la pantalla (C-4). Es la mejora de mayor impacto en esta fase.
- **Preview espejado** (`isVideoMirrored = true` en el preview layer) manteniendo la foto final sin espejo (C-5). Invertir las strings de izquierda/derecha en consecuencia, o mejor: "Muévete hacia ← / →" con flecha grande.
- Botón 5 s dentro de `#if DEBUG` (C-6).
- Banner "105 cm · 120 cm" desaparece a los 3 s o cuando se detecta persona (C-7).
- Onboarding en 3 tarjetas deslizables: *qué hace la app* (foto → estilista → looks con tu cara), *cómo colocar el teléfono* (ilustración con silueta), *qué pasa con tu foto* (privacidad) (C-1, C-2).

### 4.8 Hogar e historial (T-2)

Pantalla de inicio mínima, antes de la cámara, una vez que hay algo guardado:

```
┌──────────────────────────┐
│ guaperrimo            ⚙  │
│                          │
│ ┌──────────────────────┐ │
│ │  📷  Nueva sesión    │ │  ← primario
│ └──────────────────────┘ │
│                          │
│ MIS LOOKS                │
│ ┌────┐ ┌────┐ ┌────┐     │  ← últimos 3 guardados
│ │    │ │    │ │    │     │
│ └────┘ └────┘ └────┘     │
│                          │
│ SESIONES                 │
│ Hoy · Boda de día · 3 looks │  ← reabre la sesión aunque los looks
│ 3 oct · Casual · 2 looks    │     siguieran generándose (T-10, R-6)
└──────────────────────────┘
```

Requiere persistir `sessionId` + `imageUrl` + fecha por sesión. Primera vez: la app sigue abriendo directo en cámara.

---

## 5. Sistema de diseño mínimo (`DesignSystem.swift`)

Extraer lo que ya existe en el Style Mirror. Un archivo, ~150 líneas, y seis pantallas lo consumen.

### 5.1 Tokens

| Token | Valor propuesto | Hoy |
|-------|-----------------|-----|
| `bg` | `#0B0B0F` (negro cálido) + grid de puntos del Style Mirror reutilizable como `TexturedBackground()` | `.black` plano |
| `surface` / `surfaceRaised` | `white 0.06` / `white 0.10` | 0.06, 0.08, 0.10, 0.12, 0.15 |
| `stroke` | `white 0.12` | 0.2, 0.3 |
| `textPrimary` / `textSecondary` / `textTertiary` | `white` / `white 0.70` / `white 0.50` | 0.5‑0.9 sin regla |
| `accent` | gradiente `#7C5CFF → #3D8BFF` (el morado→azul actual, definido en Assets) | `.purple → .blue` del sistema |
| `success` | `#4ADE80` (verde menos saturado que `.green`) | `.green` |
| `warning` / `danger` | `#F59E0B` / `#F87171` | `.orange` / `.red` |
| `radius.s / m / l` | 12 / 16 / 24 | 10‑24 |
| `space` | múltiplos de 4; contenido a 20 pt de los bordes | 16‑40 |
| Tipografía | SF Pro con `.rounded` para números; **una** fuente display opcional para títulos ("Tu plan de estilo") | sistema |

### 5.2 Componentes

| Componente | Reemplaza |
|------------|-----------|
| `ScreenHeader(title:leading:trailing:)` | 6 headers copiados a mano |
| `PrimaryButton` (gradiente), `SecondaryButton` (surface), `TertiaryButton` (solo texto) | 4 estilos de cápsula ad hoc |
| `UserPhotoCard(image:)` 3:4, radius L | foto en preview, conversación, espejo, loading, lista |
| `Shimmer()` modificador | 3 copias |
| `BeforeAfterView` | `TryOnResultView` + `LookComparisonView` |
| `SegmentedControl` propio | `Picker(.segmented)` del sistema |
| `Chip` | opciones de la conversación, nombres de look, filtros |
| `Toast` | confirmaciones de guardado |

### 5.3 Reglas

- **Un gradiente por pantalla**: solo el CTA principal.
- **Verde solo para "listo"**; no para alineado *y* éxito *y* tienda cercana *y* comprado.
- Todo texto con `.font(.body)`/`.caption` etc., nunca `.system(size:)` salvo íconos; íconos con `@ScaledMetric`.
- Todo botón de ícono con `accessibilityLabel`.
- `preferredColorScheme(.dark)` declarado en la raíz.

---

## 6. Plan por fases

| Fase | Objetivo | Esfuerzo | Items |
|------|----------|----------|-------|
| **0 · Quick wins** | Quitar lo que más se nota, sin rediseño | 1 día | Renombrar "Guardar" → "Analizar mi outfit" + ícono `sparkles` (P-1). Centrar `ThinkingIndicatorView` y variar textos (S-4). Limpiar `**` y "Precio:" en descripciones (G-3). Ocultar " · " si `store` vacío (G-4). Botón 5 s a `#if DEBUG` (C-6). Quitar `SentrySDK.capture("This app uses Sentry!")` y poner `sendDefaultPii = false` (T-6). Corregir acentos en `es.lproj` (T-5). Quitar el porcentaje del try‑on (R-8). Localizar "Impacto/Esfuerzo" o quitarlos (R-3). `slotLabel()` en `LookPieceSheet` (L-6). Borrar código muerto (T-8). |
| **1 · Sistema de diseño** | Un archivo de tokens y componentes; migrar las 6 pantallas | 2‑3 días | §5 completo. Sin cambiar flujo. Resultado: todas las pantallas se ven como el Style Mirror. |
| **1.5 · Contrato de UI generativa** | El backend compone la sesión y el plan con un catálogo cerrado de componentes nativos | 3‑4 días (iOS + Go) | §9: catálogo v1 (8 componentes), JSON Schema compartido, `GenerativeCanvas` en SwiftUI, tool `render_ui` en el backend, stub con payloads reales. Decidir **antes** de la fase 2 porque cambia `ChatResponse`. |
| **2 · Conversación** | La sesión sobre tu foto | 3‑4 días | 4.2: `UserPhotoCard` arriba, pastilla "hablando" + saltar, turnos, historial colapsable, mic toggle, permisos en contexto, retry sin perder turno. El área de contenido es el `GenerativeCanvas` de §9. |
| **3 · Pantalla final + guardar** | Un solo guardar, looks con imagen, lista legible | 4‑5 días | 4.3 (hero = espejo embebido, acciones numeradas como componente `steps`, sin auto‑open) + 4.4 (`SavedLook`, ♥, "Mis looks" con pestañas, compras agrupadas por tienda). Es el cambio de modelo más grande; con §9 la limpieza de `description`/`title` queda del lado del backend por construcción. |
| **4 · Cámara y hogar** | Voz en captura, preview espejado, onboarding, inicio con historial | 3‑4 días | 4.7 + 4.8 + persistencia de sesión. |

Total estimado: 3,5 semanas de una persona. Las fases 0 y 1 se pueden hacer sin tocar el backend; la 1.5 y la 3 conviene hacerlas junto con él.

### 6.1 Progreso

**Fase 0 completada el 31 de octubre de 2026** en la rama `ios-ux-flow-audit` (basada en `shopping-list` @ `2451d67`), un commit por cambio, cada uno compilado para simulador antes de subirlo a GitHub:

| Hallazgo | Commit | Cambio |
|----------|--------|--------|
| T-6 | `4833085` | Sin evento de prueba de Sentry al arrancar; `sendDefaultPii = false`. |
| C-6 | `b1dfe96` | Botón "5s" solo en `#if DEBUG`, con hueco para mantener el obturador centrado. |
| T-5 | `62f4eb6` | Acentos, "¡…!" y puntos suspensivos tipográficos en es/en; "micrófono" en el plist de permisos. |
| S-4 | `2bd149c` | Indicador de carga centrado; "Mirando tu outfit…" / "Pensando…" según la fase. |
| R-8 | `50fa337` | Sin porcentaje inventado en la carga del try‑on. |
| L-6 | `8524cb5` | Etiqueta de prenda localizada en la hoja de prendas. |
| R-3 | `5c51169` | "Impacto/Esfuerzo" y sus niveles localizados. |
| G-3, G-4 | `8335e2c` | `cleanStylistCopy()` quita `**` y "Precio: $…"; sin " · " cuando no hay tienda; 5 tests nuevos. |
| P-1, P-2, P-3, P-5 | `b8dde2d` | "Analizar mi outfit" ✦, "Continuar sesión" al volver de la conversación, error de subida en lenguaje humano. |
| T-8 | `7eedd99` | Borrados el carrusel muerto, `ConversationMessage`, `retryLook` y 8 claves de texto huérfanas. |

Tests unitarios tras la fase 0: **18 de 19 pasan**. El que falla es `ElevenLabsTests.checkCurrentConfiguredVoice()`, que llama a la API real y recibe `payment_required` ("Free users cannot use library voices via the API"): la voz configurada ya no funciona en el plan gratuito, así que hoy el TTS cae en silencio a `AVSpeechSynthesizer` es‑MX (hallazgo T-7). No está relacionado con estos cambios; hay que elegir otra voz o pagar el plan.

Siguiente paso sugerido: fase 1 (sistema de diseño) o el modo stub de §7.1 para tomar capturas en simulador.

---

## 7. Cómo validar: pruebas en dispositivo y simulador

### 7.1 Qué se puede probar sin el teléfono

El simulador no tiene cámara, así que hoy la app se queda en `CameraView` y no se puede llegar a las pantallas que queremos revisar. Propuesta: **un modo stub de un día**, solo en `DEBUG`, activado por argumento de lanzamiento:

```swift
// guaperrimo_aiApp.swift
#if DEBUG
if CommandLine.arguments.contains("-stubFlow") {
    ConversationView(
        sessionId: "stub",
        imageUrl: Bundle.main.url(forResource: "sample-outfit", withExtension: "jpg")!.absoluteString,
        stylistService: StubStylistService(),   // ya existe y cubre los 3 turnos + looks + try-on
        ttsService: StubTTSService()            // ya existe (AVSpeechSynthesizer)
    )
}
#endif
```

Con eso se pueden tomar capturas de cada estado con `xcrun simctl io booted screenshot` y revisarlas aquí, sin permisos ni teléfono. Falta extender `StubStylistService` para que la respuesta final incluya `shoppingList` y `stores` (hoy solo manda `priorityActions`), copiando el JSON real que ya está en `ShoppingListDecodingTests.swift`.

### 7.2 Qué sí requiere el iPhone

| Prueba | Por qué en dispositivo |
|--------|------------------------|
| Captura guiada con 2‑3 personas a 120 cm | Cámara, Vision, legibilidad real de las instrucciones (C-4), preview espejado vs. no (C-5). |
| Voz: tap corto vs. hold, ruido ambiente, es‑MX | `SFSpeechRecognizer` y micrófono reales (S-6, S-7). |
| Latencias reales de `/chat`, ElevenLabs y `/looks` | Red del teléfono, no de la Mac. Define si S-2 y R-5 son fricción o bloqueo. |
| Haptics | El simulador no vibra. |
| Hero transition y crossfade a 60 fps con fotos de 12 MP | Rendimiento real. |

Hay un iPhone 14 ("haacphone") conectado a esta Mac y el backend responde en `192.168.100.39:8080`. No hace falta concederme permisos del teléfono: lo que yo no puedo hacer es *ver* la pantalla del dispositivo ni tocarla. Dos opciones:

1. **Tú corres la sesión completa desde Xcode** en el iPhone y me pasas 8‑10 capturas (preview, loading, hablando, botones, mic, final, espejo, lista) + el log filtrado por `ai.guaperrimo` para los tiempos. Con eso cierro §8 de la auditoría.
2. **Yo agrego el modo stub (7.1)**, tomo las capturas en simulador y te las anexo a este reporte. Cubre todo menos cámara y voz.

### 7.3 Métricas para después del rediseño

- Tiempo desde el disparo hasta ver el primer look (objetivo: < 60 s y siempre con algo en pantalla).
- % de sesiones que llegan a `finished` (abandono en la conversación).
- % de sesiones con al menos un look guardado (♥).
- % de usuarios que vuelven a abrir "Mis looks" en otra sesión.
- Toques de "saltar" en TTS (si > 50 %, el mensaje es demasiado largo).

---

## 8. Anexo: textos a corregir en `es.lproj/Localizable.strings`

| Clave | Hoy | Propuesto |
|-------|-----|-----------|
| `save_photo` | Guardar | Analizar mi outfit |
| `photo_saved` | Foto guardada | *(eliminar)* |
| `thinking` | Analizando tu estilo... | Mirando tu outfit… / Pensando… / Armando tu plan… (3 claves) |
| `voice_hold_hint` | Manten presionado para hablar | Toca para hablar |
| `mic_denied` | …al microfono. Activalo… | …al micrófono. Actívalo… |
| `error_generic` | Algo salio mal. Intenta de nuevo. | Algo salió mal. Intenta de nuevo. |
| `voice_error` | No te entendi. Intenta de nuevo. | No te escuché. Intenta otra vez. |
| `tryon_button` | Ver como me quedaria | Ver en mí |
| `tryon_after` | Despues | Después |
| `looks_first_ready` | Tu primer look esta listo! | ¡Tu primer look está listo! |
| `looks_carousel_title` | Tus Looks | Tus looks |
| `shopping_title` | Mi lista | Mis looks |
| `shopping_save` / `shopping_like` / `shopping_save_look` | tres variantes | *(eliminar; un solo ♥ con toast "Guardado en Mis looks")* |
| *(nuevas)* | — | `session_title` "Tu estilista" · `plan_title` "Tu plan de estilo" · `plan_section_actions` "Lo que más cambia tu look" · `tryon_inline` "Ver en mí" · `saved_toast` "Guardado en Mis looks" · `tts_skip` "Saltar" |

Y en código: `"Impacto: …"`, `"Esfuerzo: …"` (`PriorityActionCardView.swift:25-26`), `"guaperrimo.ai"` (`ConversationView.swift:74`), `"120 cm"`, `"5s"` (`CameraView.swift`) deben salir de los strings o localizarse.

---

## 9. UI generativa (el concepto detrás de OpenUI): cómo encaja en el rediseño

*Añadido el 31 de octubre de 2026 a petición del fundador.*

### 9.1 Qué es OpenUI y qué parte nos sirve

[OpenUI](https://github.com/thesysdev/openui) (thesysdev, MIT) es un framework de **UI generativa**: en vez de texto o HTML, el modelo emite un lenguaje declarativo compacto y en streaming ("OpenUI Lang"); un runtime React lo parsea conforme llegan los tokens y lo renderiza con una **biblioteca de componentes que tú defines**. El sistema genera el prompt a partir de esa biblioteca, así que el modelo solo puede usar esos componentes, y lo que llega inválido se descarta en vez de romper la pantalla.

Tres ideas de ahí son las que nos importan; el paquete en sí no:

| Idea | Nos sirve | Por qué |
|------|-----------|---------|
| El modelo **compone** la interfaz con un catálogo cerrado | ✅ | La conversación de un estilista es variable por naturaleza: a veces hay que señalar algo en la foto, a veces mostrar una paleta, a veces preguntar presupuesto con un slider. Pantallas fijas lo aplastan todo a "párrafo + botones" (S‑1, S‑3, R‑1). |
| El catálogo **es** el contrato y genera el prompt | ✅ | Una sola fuente de verdad para "qué puede mostrar el estilista", compartida entre Go e iOS. |
| Streaming y tolerancia a fragmentos inválidos | ✅ | La pantalla nunca está vacía ni se rompe por una respuesta a medias (S‑2). |
| Runtime React / React Native | ❌ | La app es SwiftUI con interacciones nativas finas (captura, espejo). OpenUI solo llega a iOS vía React Native, en un experimento que sus autores llaman eso mismo ([AppLess](https://github.com/thesysdev/appless/wiki)). |

La app **ya hace UI dirigida por servidor en versión primitiva**: `input_mode` (buttons/voice/none), `options`, `priority_actions`, `shopping_list`, `stores`, `looks_generating`. El cliente tiene un `switch` fijo sobre eso. El salto es pasar de "campos sueltos que el cliente interpreta" a "lista de componentes que el cliente renderiza".

### 9.2 Regla de oro: el estilista compone el contenido, la app es dueña del marco

```
┌──────────────────────────┐
│ ✕   Tu estilista   ● ● ○ │  ← marco nativo fijo
│ ┌──────────────────────┐ │
│ │     tu foto          │ │  ← marco nativo fijo (UserPhotoCard)
│ │   ● "rompen la línea"│ │  ← photo_markers: componente generativo
│ └──────────────────────┘ │     que se dibuja SOBRE el marco
│ ╭ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ╮  │
│   text (stylist)         │  ← GenerativeCanvas: lo que el backend
│   chips: Boda · Oficina  │     ordena este turno
│   slider: presupuesto    │
│ ╰ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ╯  │
│  ▸ Ver conversación      │  ← marco nativo fijo
└──────────────────────────┘
```

| Nativo y fijo (no generativo) | Generativo |
|-------------------------------|------------|
| Onboarding, cámara, silueta, countdown | Área de contenido de la sesión (bajo la foto) |
| Preview y "Analizar mi outfit" | Cuerpo de "Tu plan de estilo" |
| Header, indicador de turno, foto del usuario | Qué pregunta se hace y con qué control |
| Style Mirror, comparación antes/después, try‑on | Qué se señala en la foto, qué paleta, qué orden |
| ♥ guardar, "Mis looks", navegación | — |

El modelo **elige y ordena** componentes; nunca dibuja layout, colores ni tamaños. Eso queda en el sistema de diseño (§5).

### 9.3 Catálogo v1 (8 componentes)

| `type` | Props principales | Reemplaza / resuelve |
|--------|-------------------|----------------------|
| `text` | `role: stylist \| heading \| body`, `text` | `messageText` (S‑3: se acumulan, hay historial) |
| `photo_markers` | `markers: [{x, y, label}]` (normalizados 0‑1) | S‑1: la foto tiene un uso; el estilista "apunta" |
| `chips` | `id`, `select: single \| multi`, `options: [{id, label}]`, `allow_voice` | `buttonsInput` (S‑6/S‑7: input por pregunta) |
| `slider` | `id`, `min`, `max`, `step`, `unit`, `default` | preguntas de presupuesto que hoy van por voz |
| `palette` | `swatches: [{hex, name}]`, `note` | contenido nuevo: colores que te favorecen |
| `steps` | `items: [{title, detail, action?: {kind: tryon \| product, id}}]` | `PriorityActionCardView` (R‑3/R‑4: sin Impacto/Esfuerzo) |
| `product_card` | `product_id`, `title`, `price_mxn`, `store`, `image_url`, `link`, `nearby?: {name, distance_m}` | `productRow` (G‑3/G‑4: campos tipados, sin markdown) |
| `budget_bar` | `total_mxn`, `budget_mxn`, `label` | el total escondido en `.caption` (G‑7) |

Reservados para v2: `before_after`, `look_card` (embebe el espejo), `store_row`, `checklist`, `date_picker`. La regla para añadir uno: aparece en ≥ 3 sesiones reales y no se puede expresar con los existentes.

### 9.4 Contrato: un turno de ejemplo

```json
{
  "session_id": "712bd6de-…",
  "turn": 2,
  "phase": "discovery",
  "ui_version": 1,
  "speech": "Veo que los tenis blancos rompen la línea del pantalón. ¿Para qué ocasión te vistes?",
  "ui": [
    { "type": "photo_markers", "markers": [{ "x": 0.52, "y": 0.91, "label": "Rompen la línea" }] },
    { "type": "text", "role": "stylist", "text": "Los tenis blancos cortan la silueta. Antes de proponerte algo, dime:" },
    { "type": "chips", "id": "occasion", "select": "single", "allow_voice": true,
      "options": [
        { "id": "boda_dia", "label": "Boda de día" },
        { "id": "oficina", "label": "Oficina" },
        { "id": "cita", "label": "Cita" }
      ] }
  ],
  "input": { "component_id": "occasion" },
  "is_final": false
}
```

Respuesta del cliente: `{ "type": "ui_action", "component_id": "occasion", "value": "boda_dia" }` o, si habló, `{ "type": "voice_response", "component_id": "occasion", "transcript": "…" }`.

Decisiones embebidas en el contrato:

- **`speech` separado de `ui`.** El TTS lee `speech` (corto); la pantalla muestra `ui`. La voz sigue siendo el canal principal y nunca "lee la interfaz".
- **`ui_version` + tipo desconocido → fallback.** Un componente que el cliente no conoce se renderiza como `text` con su `fallback_text`; `ui` vacío → `speech` como texto. La app vieja nunca se rompe con un backend nuevo.
- **`input` apunta a un componente**, no a un modo global. Un turno puede tener chips y además aceptar voz.

### 9.5 Implementación iOS (sin React, ~2 días)

```swift
enum UIComponent: Decodable, Identifiable {
    case text(TextProps), photoMarkers(PhotoMarkersProps), chips(ChipsProps), slider(SliderProps)
    case palette(PaletteProps), steps(StepsProps), productCard(ProductCardProps), budgetBar(BudgetBarProps)
    case unknown(type: String, fallback: String?)
    // init(from:) lee "type" y cae en .unknown si no lo conoce
}

struct GenerativeCanvas: View {
    let components: [UIComponent]
    let onAction: (UIAction) -> Void
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(components) { component in
                switch component { /* una vista del sistema de diseño por caso */ }
            }
        }
    }
}
```

- Cada caso es **un** componente del sistema de diseño (§5.2). El catálogo y la biblioteca de componentes son la misma lista: resuelve T‑3 de raíz.
- `photo_markers` se renderiza como overlay de `UserPhotoCard`, no dentro del canvas.
- **Streaming en dos pasos.** Paso A: `/chat` sigue devolviendo JSON completo y el canvas renderiza al llegar; el marco (foto, header, pastilla "pensando") ya está en pantalla, así que nunca se ve negro. Paso B: SSE o NDJSON con un componente por línea; el canvas apila con `.transition(.move(edge: .bottom).combined(with: .opacity))` mientras el TTS empieza con `speech`, que llega primero.
- **Pruebas:** un snapshot test por componente con payloads reales, igual que `ShoppingListDecodingTests` hoy; un test de contrato que falla si el schema de Go y el enum de Swift divergen.

### 9.6 Implementación backend (Go, OpenAI‑compatible con tools)

- **Dos fuentes de componentes.** El **código** compone los de datos (`product_card`, `budget_bar`, en v2 `store_row`) a partir de SerpAPI y Maps: sin alucinaciones, sin markdown, títulos cortos por construcción. El **LLM** compone los conversacionales (`text`, `chips`, `slider`, `photo_markers`, `palette`, `steps`) a través de una tool `render_ui` con JSON Schema estricto (o structured output).
- **Prompt generado desde el catálogo**, como hace OpenUI con `generatePrompt`: el schema produce la descripción de cada componente que ve el modelo.
- **Validación en servidor** contra el schema; lo inválido se descarta y se registra, no se envía. `speech` es obligatorio.
- Con campos tipados, G‑3/G‑4/G‑5 dejan de ser bugs de UI: `product_card.title` no puede contener `**Precio: $539**` porque no es prosa.

### 9.7 Riesgos y reglas

1. **Nada de HTML, WebViews ni layout libre.** Catálogo cerrado y pequeño; el modelo elige y ordena. Usar OpenUI "de verdad" en iOS significa React Native y perder el Style Mirror nativo: descartado.
2. **Latencia.** Ya es el punto débil (S‑2) y la UI generativa añade tokens. Mitigar con ids cortos, componentes de datos por código, `speech` primero, streaming y un límite de 6 componentes por turno.
3. **Siempre hay fallback.** Tipo desconocido → texto; `ui` vacío → `speech`; error de parseo → el turno anterior sigue en pantalla.
4. **Voz primero.** Todo componente interactivo acepta voz (`allow_voice`); el TTS lee `speech`, nunca los labels.
5. **Versionar y testear el contrato en ambos repos.** `ui_version`, fixtures compartidos, test que compila el schema contra el enum.
6. **No generativizar** captura, espejo, comparación ni navegación. Son el valor diferencial y ya están bien.

### 9.8 Opciones de implementación

| Opción | Qué es | Veredicto |
|--------|--------|-----------|
| **A. SDUI propio en SwiftUI** | `UIComponent` + `GenerativeCanvas` + schema propio inspirado en OpenUI y A2UI | **Recomendada.** 2‑3 días de cliente, cero dependencias, encaja con la fase 1 y con cómo ya está escrita la app. |
| B. [A2UI](https://github.com/google/A2UI) + renderer SwiftUI comunitario | Protocolo abierto de Google: lista plana de componentes con ids, catálogo confiable en el cliente, streaming. Renderers Apple no oficiales ([A2UI‑Swift](https://github.com/BBC6BAE9/a2ui-swift/wiki), [a2ui‑bindjs](https://github.com/metabindai/a2ui-bindjs)). | Vale la pena **leer el spec** para copiar el formato de streaming y de referencias por id. Depender de un renderer comunitario para la pantalla central es riesgoso hoy. |
| C. OpenUI real | React Native + AppLess | No. Reescribe la app y sus autores lo describen como experimento sin integraciones reales. |

### 9.9 OpenUI como herramienta de diseño (uso secundario, recomendado)

Donde OpenUI sí entra tal cual es **antes de escribir SwiftUI**: definir el catálogo v1 como ocho componentes React de juguete, generar el prompt con `@openuidev/lang-core`, alimentarlo con 5‑10 transcripciones reales de sesiones y ver en el navegador cómo compone el modelo las pantallas 4.2 y 4.3. Veinte variantes en una tarde para validar que el catálogo alcanza, qué componentes faltan y cuántos tokens cuesta cada turno, antes de tocar la app.

### 9.10 Impacto en el plan

Nueva **fase 1.5 "Contrato de UI generativa"** (§6) entre el sistema de diseño y la conversación: catálogo v1, JSON Schema compartido, `GenerativeCanvas`, tool `render_ui`, stub con payloads reales. Las fases 2 y 3 se construyen sobre el canvas en lugar de sobre `switch viewModel.state`. Hay que decidirla **antes** de la fase 2 porque cambia `ChatResponse`; si se posterga, la conversación rediseñada se tendría que rehacer.
