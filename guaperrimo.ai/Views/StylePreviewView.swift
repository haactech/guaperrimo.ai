//
//  StylePreviewView.swift
//  guaperrimo.ai
//
//  "Tu estilo": before searching products (and rendering try-on), the stylist
//  shows a short style brief and a few garment ideas. The user taps the ones
//  he likes and sends the selection; only those get searched.

#if os(iOS)
import SwiftUI

struct StylePreviewView: View {
    let message: String
    let direction: StyleDirectionDTO
    let selectedIds: Set<String>
    @Binding var comment: String
    let isSending: Bool
    let errorMessage: String?
    let onToggle: (String) -> Void
    let onSend: () -> Void
    let onClose: () -> Void

    @FocusState private var commentFocused: Bool

    private var trimmedComment: String {
        comment.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !isSending && (!selectedIds.isEmpty || !trimmedComment.isEmpty)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !message.isEmpty {
                            Text(message)
                                .font(.title3)
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let brief = direction.brief {
                            briefCard(brief)
                        }

                        if !direction.ideas.isEmpty {
                            ideasSection
                        }

                        commentField
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .id(direction.round) // a new round starts at the top
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .accessibilityLabel(String(localized: "preview_close"))

            Spacer()

            Text(String(localized: "preview_title"))
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Brief

    private func briefCard(_ brief: StyleBriefDTO) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let season = brief.colorSeason, !season.isEmpty {
                Text("\(String(localized: "preview_color_season")): \(season)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12), in: Capsule())
            }

            if !brief.summary.isEmpty {
                Text(brief.summary)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !brief.palette.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel(String(localized: "preview_palette"))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(Array(brief.palette.enumerated()), id: \.offset) { _, swatch in
                                VStack(spacing: 6) {
                                    SwatchCircle(swatch: swatch, size: 36)
                                    Text(swatch.name)
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.75))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(width: 64)
                            }
                        }
                    }
                }
            }

            if !brief.avoid.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel(String(localized: "preview_avoid"))
                    ForEach(Array(brief.avoid.enumerated()), id: \.offset) { _, swatch in
                        HStack(alignment: .top, spacing: 10) {
                            SwatchCircle(swatch: swatch, size: 22, crossedOut: true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(swatch.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                if let why = swatch.why, !why.isEmpty {
                                    Text(why)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.65))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }

            if let silhouette = brief.silhouette, !silhouette.isEmpty {
                Label {
                    Text(silhouette)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "figure.stand")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1)
            .foregroundStyle(.white.opacity(0.5))
    }

    // MARK: - Ideas

    private var ideasSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "preview_ideas_title"))
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(String(localized: "preview_ideas_hint"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            ForEach(direction.ideasBySlot) { group in
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel(previewSlotTitle(group.slot))
                    ForEach(group.ideas) { idea in
                        IdeaCardView(
                            idea: idea,
                            isSelected: selectedIds.contains(idea.id),
                            onTap: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onToggle(idea.id)
                            }
                        )
                        .disabled(isSending)
                    }
                }
            }
        }
    }

    // MARK: - Comment

    private var commentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "preview_comment_title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            TextField(
                "",
                text: $comment,
                prompt: Text(String(localized: "preview_comment_placeholder")).foregroundStyle(.white.opacity(0.4)),
                axis: .vertical
            )
            .lineLimit(1...4)
            .font(.subheadline)
            .foregroundStyle(.white)
            .tint(.white)
            .focused($commentFocused)
            .padding(12)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(commentFocused ? 0.35 : 0.15), lineWidth: 1)
            )
            .disabled(isSending)
        }
        .padding(.top, 4)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            if isSending {
                ThinkingIndicatorView()
                    .frame(minHeight: 50)
            } else {
                Button {
                    commentFocused = false
                    onSend()
                } label: {
                    Text(sendTitle)
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white, in: Capsule())
                }
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.4)
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [.black.opacity(0), .black, .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private var sendTitle: String {
        if selectedIds.isEmpty && !trimmedComment.isEmpty {
            return String(localized: "preview_send_comment")
        }
        return String(format: String(localized: "preview_send"), selectedIds.count)
    }
}

// MARK: - Idea card

private struct IdeaCardView: View {
    let idea: StyleIdeaDTO
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    referencePhoto

                    VStack(alignment: .leading, spacing: 8) {
                        Text(idea.garment)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if !idea.colors.isEmpty {
                            colorsRow
                        }

                        if !chips.isEmpty {
                            ChipsFlow(spacing: 6) {
                                ForEach(chips, id: \.self) { chip in
                                    Text(chip)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.12), in: Capsule())
                                }
                            }
                        }

                        if let price = idea.priceRangeLabel {
                            Text(price)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(isSelected ? .green : .white.opacity(0.4))
                }

                if let why = idea.why, !why.isEmpty {
                    Text(why)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if idea.reference != nil {
                    Text(referenceCaption)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.green.opacity(0.12) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.green : Color.white.opacity(0.12), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var chips: [String] {
        var result = idea.textures.filter { !$0.isEmpty }
        if let fit = idea.fit, !fit.isEmpty {
            result.append("\(String(localized: "preview_fit")): \(fit)")
        }
        return result
    }

    private var referenceCaption: String {
        let store = idea.reference?.store.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return store.isEmpty
            ? String(localized: "preview_reference")
            : "\(String(localized: "preview_reference")): \(store)"
    }

    private var colorsRow: some View {
        ChipsFlow(spacing: 8) {
            ForEach(Array(idea.colors.enumerated()), id: \.offset) { _, swatch in
                HStack(spacing: 5) {
                    SwatchCircle(swatch: swatch, size: 14)
                    Text(swatch.name)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }

    private var referencePhoto: some View {
        Group {
            if let urlString = idea.reference?.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        photoPlaceholder
                    default:
                        Color.white.opacity(0.08)
                    }
                }
            } else {
                photoPlaceholder
            }
        }
        .frame(width: 88, height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var photoPlaceholder: some View {
        ZStack {
            Color.white.opacity(0.08)
            Image(systemName: "tshirt")
                .font(.system(size: 26))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

// MARK: - Swatch

private struct SwatchCircle: View {
    let swatch: ColorSwatchDTO
    var size: CGFloat
    var crossedOut: Bool = false

    var body: some View {
        ZStack {
            if let rgb = swatch.rgb {
                Circle().fill(Color(red: rgb.red, green: rgb.green, blue: rgb.blue))
            } else {
                // No hex: neutral swatch, the name carries the color.
                Circle().fill(Color.white.opacity(0.12))
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
            Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)

            if crossedOut {
                Rectangle()
                    .fill(Color.red.opacity(0.9))
                    .frame(width: size * 1.1, height: 2)
                    .rotationEffect(.degrees(-45))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Wrapping chips layout

private struct ChipsFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(maxWidth: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth && !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Preview

#if DEBUG
extension StyleDirectionDTO {
    static let sample = StyleDirectionDTO(
        brief: StyleBriefDTO(
            summary: "Por tu silueta natural y tu tono cálido, los cortes fluidos y las telas con textura te dan ese equilibrio entre elegante y fresco.",
            colorSeason: "Deep Autumn",
            palette: [
                ColorSwatchDTO(name: "Verde botella", hex: "#3E5641"),
                ColorSwatchDTO(name: "Caramelo", hex: "#B87D4F"),
                ColorSwatchDTO(name: "Mostaza oscuro", hex: "#D4A017"),
                ColorSwatchDTO(name: "Terracota", hex: "#CC6B49"),
                ColorSwatchDTO(name: "Beige cálido"),
            ],
            avoid: [
                ColorSwatchDTO(name: "Negro puro", hex: "#000000", why: "Apaga tu tono cálido y profundo"),
                ColorSwatchDTO(name: "Blanco frío", hex: "#FFFFFF", why: "Puede verse demasiado contrastante con tu piel"),
            ],
            silhouette: "Cortes rectos o ligeramente estructurados, pero nunca ajustados."
        ),
        ideas: [
            StyleIdeaDTO(
                id: "idea_3", slot: "lower_body", garment: "Chinos de algodón",
                colors: [ColorSwatchDTO(name: "Beige cálido", hex: "#D4C4A6")],
                textures: ["algodón grueso"], fit: "recto",
                why: "Versátiles, frescos y combinan con todo.",
                priceMinMxn: 600, priceMaxMxn: 1000
            ),
            StyleIdeaDTO(
                id: "idea_1", slot: "upper_body", garment: "Camisa de lino manga larga",
                colors: [ColorSwatchDTO(name: "Verde botella", hex: "#3E5641")],
                textures: ["lino"], fit: "recta, sin ajustar",
                why: "El lino es fresco y elegante; este color resalta tu tono de piel.",
                priceMinMxn: 700, priceMaxMxn: 1200,
                reference: ProductDTO(
                    id: "p1", title: "Camisa de lino verde", store: "Etsy", price: 1172.73, currency: "MXN",
                    link: nil, thumbnail: "https://picsum.photos/200/250?random=1", largeImage: nil,
                    delivery: nil, availability: nil, nearbyStore: nil
                )
            ),
            StyleIdeaDTO(
                id: "idea_5", slot: "accessory", garment: "Reloj minimalista",
                colors: [ColorSwatchDTO(name: "Plateado", hex: "")],
                textures: ["metal"], fit: "estándar",
                why: "Complementa tu look sin llamar demasiado la atención.",
                priceMinMxn: 500, priceMaxMxn: 1000
            ),
        ],
        round: 1
    )
}

private struct StylePreviewPreviewHost: View {
    @State private var selected: Set<String> = ["idea_1"]
    @State private var comment = ""
    @State private var sending = false

    var body: some View {
        StylePreviewView(
            message: "Con $2,000 te propongo prendas clave que te harán ver elegante pero fresco. Elige las que más te gusten.",
            direction: .sample,
            selectedIds: selected,
            comment: $comment,
            isSending: sending,
            errorMessage: nil,
            onToggle: { id in
                if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
            },
            onSend: { sending = true },
            onClose: {}
        )
    }
}

#Preview("Style preview") {
    StylePreviewPreviewHost()
}
#endif
#endif
