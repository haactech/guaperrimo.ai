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
    @State private var contentWidth: CGFloat = 0

    /// Two cards plus a peek of the third, so the row visibly scrolls.
    private var cardWidth: CGFloat {
        guard contentWidth > 0 else { return 160 }
        return max(140, ((contentWidth - 12) / 2.2).rounded(.down))
    }

    private var trimmedComment: String {
        comment.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        !isSending && (!selectedIds.isEmpty || !trimmedComment.isEmpty)
    }

    var body: some View {
        ZStack {
            TexturedBackground()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if !message.isEmpty {
                            Text(message)
                                .font(.title3)
                                .foregroundStyle(DS.textPrimary)
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
                    .onGeometryChange(for: CGFloat.self) { $0.size.width - 40 } action: { contentWidth = $0 }
                }
                .scrollIndicators(.hidden)
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
        ScreenHeader(
            title: String(localized: "preview_title"),
            closeLabel: String(localized: "preview_close"),
            onClose: onClose
        )
        .disabled(isSending) // closing mid-send would hide the result or the error
    }

    // MARK: - Brief

    private func briefCard(_ brief: StyleBriefDTO) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let season = brief.colorSeason, !season.isEmpty {
                Text("\(String(localized: "preview_color_season")): \(season)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DS.surfaceRaised, in: Capsule())
            }

            if !brief.summary.isEmpty {
                Text(brief.summary)
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !brief.palette.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel(String(localized: "preview_palette"))
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(Array(brief.palette.enumerated()), id: \.offset) { _, swatch in
                                VStack(spacing: 6) {
                                    SwatchCircle(swatch: swatch, size: 36)
                                    Text(swatch.name)
                                        .font(.caption2)
                                        .foregroundStyle(DS.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                }
                                .frame(width: 64)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
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
                                    .foregroundStyle(DS.textPrimary)
                                if let why = swatch.why, !why.isEmpty {
                                    Text(why)
                                        .font(.caption)
                                        .foregroundStyle(DS.textSecondary)
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
                .foregroundStyle(DS.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.m))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1)
            .foregroundStyle(DS.textTertiary)
    }

    // MARK: - Ideas

    private var ideasSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "preview_ideas_title"))
                    .font(.headline)
                    .foregroundStyle(DS.textPrimary)
                Text(String(localized: "preview_ideas_hint"))
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
            }

            // One row per garment of the outfit (shirts, pants, jackets),
            // its alternatives side by side.
            ForEach(direction.ideasBySlot) { group in
                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel(previewSlotTitle(group.slot))
                    IdeasRow(
                        ideas: group.ideas,
                        cardWidth: cardWidth,
                        selectedIds: selectedIds,
                        isSending: isSending,
                        onToggle: onToggle
                    )
                }
            }
        }
    }

    // MARK: - Comment

    private var commentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "preview_comment_title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.textPrimary)

            TextField(
                "",
                text: $comment,
                prompt: Text(String(localized: "preview_comment_placeholder")).foregroundStyle(DS.textTertiary),
                axis: .vertical
            )
            .lineLimit(1...4)
            .font(.subheadline)
            .foregroundStyle(DS.textPrimary)
            .tint(.white)
            .focused($commentFocused)
            .padding(12)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.s))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(commentFocused ? DS.textTertiary : DS.stroke, lineWidth: 1)
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
                    .foregroundStyle(DS.warning)
                    .multilineTextAlignment(.center)
            }

            if isSending {
                ThinkingIndicatorView()
                    .frame(minHeight: 50)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(localized: "preview_a11y_sending"))
            } else {
                PrimaryButton(title: sendTitle, style: .light, accessibilityLabel: sendTitle) {
                    commentFocused = false
                    onSend()
                }
                .disabled(!canSend)
                .accessibilityHint(canSend ? "" : String(localized: "preview_a11y_send_hint"))
                .padding(.horizontal, DS.Space.inset)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            LinearGradient(colors: [DS.bg.opacity(0), DS.bg, DS.bg], startPoint: .top, endPoint: .bottom)
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

// MARK: - Ideas row

/// One horizontal row of alternatives: about two and a bit cards visible,
/// snapping to cards, with dots that follow the scroll position.
private struct IdeasRow: View {
    let ideas: [StyleIdeaDTO]
    let cardWidth: CGFloat
    let selectedIds: Set<String>
    let isSending: Bool
    let onToggle: (String) -> Void

    @State private var position: String?

    /// Cards that fit fully in view (the rest peeks).
    private let visibleCount = 2

    private var leadingIndex: Int {
        ideas.firstIndex { $0.id == position } ?? 0
    }

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(ideas) { idea in
                        IdeaCardView(
                            idea: idea,
                            isSelected: selectedIds.contains(idea.id),
                            onTap: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onToggle(idea.id)
                            }
                        )
                        .frame(width: cardWidth)
                        .disabled(isSending)
                        .id(idea.id)
                    }
                }
                .scrollTargetLayout()
                .fixedSize(horizontal: false, vertical: true) // cards in a row share one height
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position)

            if ideas.count > visibleCount {
                HStack(spacing: 6) {
                    ForEach(Array(ideas.enumerated()), id: \.offset) { index, _ in
                        let isVisible = index >= leadingIndex && index < leadingIndex + visibleCount
                        Capsule()
                            .fill(isVisible ? DS.textPrimary : DS.textTertiary)
                            .frame(width: isVisible ? 14 : 6, height: 6)
                    }
                }
                .animation(.easeOut(duration: 0.15), value: leadingIndex)
                .accessibilityHidden(true)
            }
        }
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
                referencePhoto
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(isSelected ? DS.success : DS.textPrimary)
                            .background(Circle().fill(.black.opacity(0.35)))
                            .padding(8)
                    }

                Text(idea.garment)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !idea.colors.isEmpty {
                    colorsRow
                }

                if !chips.isEmpty {
                    ChipsFlow(spacing: 6) {
                        ForEach(chips, id: \.self) { chip in
                            Text(chip)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(DS.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(DS.surfaceRaised, in: Capsule())
                        }
                    }
                }

                if let price = idea.priceRangeLabel {
                    Text(price)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                }

                if let why = idea.why, !why.isEmpty {
                    Text(why)
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if idea.reference != nil {
                    Text(referenceCaption)
                        .font(.caption2)
                        .foregroundStyle(DS.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(isSelected ? DS.success.opacity(0.12) : DS.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? DS.success : DS.stroke, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue(isSelected ? String(localized: "preview_a11y_selected") : String(localized: "preview_a11y_not_selected"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityDescription: String {
        let colorNames = idea.colors.map(\.name).filter { !$0.isEmpty }
        return ([idea.garment] + colorNames).joined(separator: ", ")
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
                        .foregroundStyle(DS.textSecondary)
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
                        DS.surface
                            .shimmer()
                    }
                }
            } else {
                photoPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var photoPlaceholder: some View {
        ZStack {
            DS.surface
            Image(systemName: "tshirt")
                .font(.title2)
                .foregroundStyle(DS.textTertiary)
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
                Circle().fill(DS.surfaceRaised)
                Circle()
                    .strokeBorder(DS.textTertiary, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
            Circle().strokeBorder(DS.stroke, lineWidth: 1)

            if crossedOut {
                Rectangle()
                    .fill(DS.danger)
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
    /// Three alternatives per garment, like the backend sends.
    private static let sampleIdeas: [StyleIdeaDTO] = {
        let rows: [(String, [(String, String, String)])] = [
            ("upper_body", [("Camisa de lino manga larga", "Verde botella", "#3E5641"),
                            ("Camisa oxford", "Azul cielo", "#9DB8D9"),
                            ("Polo de punto", "Caramelo", "#B87D4F")]),
            ("lower_body", [("Chinos de algodón", "Beige cálido", "#D4C4A6"),
                            ("Pantalón de lino", "Arena", "#CDBB9A"),
                            ("Chino slim", "Azul marino", "#1F2A44")]),
            ("outerwear", [("Saco desestructurado", "Camel", "#B5895A"),
                           ("Chamarra de mezclilla", "Azul medio", "#4A6FA5"),
                           ("Blazer de punto", "Gris", "#8A8D91")]),
        ]
        var ideas: [StyleIdeaDTO] = []
        for (slot, garments) in rows {
            for (garment, color, hex) in garments {
                let n = ideas.count + 1
                ideas.append(StyleIdeaDTO(
                    id: "idea_\(n)", slot: slot, garment: garment,
                    colors: [ColorSwatchDTO(name: color, hex: hex)],
                    textures: ["algodón"], fit: "recto",
                    why: "Fresco y elegante; este color resalta tu tono de piel.",
                    priceMinMxn: 600, priceMaxMxn: 1100,
                    reference: n == 6 ? nil : ProductDTO(
                        id: "p\(n)", title: garment, store: "Liverpool", price: 899, currency: "MXN",
                        link: nil, thumbnail: "https://picsum.photos/400/500?random=\(n)", largeImage: nil,
                        delivery: nil, availability: nil, nearbyStore: nil
                    )
                ))
            }
        }
        return ideas
    }()

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
        ideas: sampleIdeas,
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
