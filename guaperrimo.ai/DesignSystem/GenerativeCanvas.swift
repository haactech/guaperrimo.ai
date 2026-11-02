//
//  GenerativeCanvas.swift
//  guaperrimo.ai
//
//  Renders the closed catalog of generative UI components (see UIComponent)
//  with the design system. One small view per component; unknown types render
//  nothing. Interaction is reported through closures, never handled here.
//

#if os(iOS)
import SwiftUI

struct GenerativeCanvas: View {
    let components: [UIComponent]
    var isInteractive: Bool = true
    var onChip: (_ optionId: String, _ label: String) -> Void = { _, _ in }
    var onSliderConfirm: (_ componentId: String, _ value: String) -> Void = { _, _ in }

    var body: some View {
        VStack(spacing: DS.Space.m) {
            ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                view(for: component)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func view(for component: UIComponent) -> some View {
        switch component {
        case .text(let c):
            CanvasText(component: c)
        case .chips(let c):
            CanvasChips(component: c, isInteractive: isInteractive, onChip: onChip)
        case .slider(let c):
            CanvasSlider(component: c, isInteractive: isInteractive, onConfirm: onSliderConfirm)
                .id(c.id)
        case .palette(let c):
            CanvasPalette(component: c)
        case .steps(let c):
            CanvasSteps(component: c)
        case .productCard(let c):
            CanvasProductCard(component: c)
        case .budgetBar(let c):
            CanvasBudgetBar(component: c)
        case .unknown:
            EmptyView()
        }
    }
}

// MARK: - Formatting

private enum CanvasFormat {
    /// "2,500" (grouping, no decimals), Mexican locale.
    static func number(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "es_MX")
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    /// "2,500 MXN"
    static func amount(_ value: Double, unit: String? = "MXN") -> String {
        let number = number(value)
        guard let unit, !unit.isEmpty else { return number }
        return "\(number) \(unit)"
    }
}

// MARK: - Text

private struct CanvasText: View {
    let component: TextComponent

    var body: some View {
        switch component.role {
        case .stylist:
            Text(component.text)
                .font(.title3)
                .foregroundStyle(DS.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        case .heading:
            Text(component.text.uppercased())
                .font(.caption)
                .tracking(1.2)
                .foregroundStyle(DS.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        case .body:
            Text(component.text)
                .font(.body)
                .foregroundStyle(DS.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Flow layout

/// Lays children out left to right and wraps to a new centered line when the row is full.
private struct FlowLayout: Layout {
    var spacing: CGFloat = DS.Space.xs
    var lineSpacing: CGFloat = DS.Space.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = lines.map(\.width).max() ?? 0
        let height = lines.reduce(0) { $0 + $1.height } + CGFloat(max(lines.count - 1, 0)) * lineSpacing
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX + (bounds.width - line.width) / 2
            for index in line.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Line] {
        var lines: [Line] = []
        var current = Line()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                lines.append(current)
                current = Line()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { lines.append(current) }
        return lines
    }
}

// MARK: - Chips

private struct CanvasChips: View {
    let component: ChipsComponent
    let isInteractive: Bool
    let onChip: (String, String) -> Void

    var body: some View {
        FlowLayout {
            ForEach(component.options) { option in
                Button {
                    onChip(option.id, option.label)
                } label: {
                    Chip(label: option.label)
                        .frame(minHeight: DS.minTap)
                        .contentShape(Capsule())
                }
                .disabled(!isInteractive)
                .opacity(isInteractive ? 1 : 0.4)
                .accessibilityLabel(option.label)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Slider

private struct CanvasSlider: View {
    let component: SliderComponent
    let isInteractive: Bool
    let onConfirm: (String, String) -> Void

    @State private var value: Double

    init(component: SliderComponent, isInteractive: Bool, onConfirm: @escaping (String, String) -> Void) {
        self.component = component
        self.isInteractive = isInteractive
        self.onConfirm = onConfirm
        let low = component.min
        let high = Swift.max(component.max, low)
        _value = State(initialValue: Swift.min(Swift.max(component.defaultValue ?? low, low), high))
    }

    private var range: ClosedRange<Double> { component.min...Swift.max(component.max, component.min) }

    var body: some View {
        VStack(spacing: DS.Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(component.label)
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)
                Spacer(minLength: DS.Space.xs)
                Text(CanvasFormat.amount(value, unit: component.unit))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .monospacedDigit()
            }
            .accessibilityHidden(true)

            VStack(spacing: DS.Space.xxs) {
                slider
                    .tint(DS.accentStart)
                    .frame(minHeight: DS.minTap)
                    .disabled(!isInteractive)
                    .accessibilityLabel(component.label)
                    .accessibilityValue(CanvasFormat.amount(value, unit: component.unit))

                HStack {
                    Text(CanvasFormat.number(component.min))
                    Spacer()
                    Text(CanvasFormat.number(component.max))
                }
                .font(.caption)
                .foregroundStyle(DS.textTertiary)
                .accessibilityHidden(true)
            }

            PrimaryButton(title: String(localized: "ui_continue")) {
                onConfirm(component.id, "\(Int(value.rounded()))")
            }
            .disabled(!isInteractive)
        }
        .padding(DS.Space.m)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.m))
    }

    @ViewBuilder private var slider: some View {
        if let step = component.step, step > 0 {
            Slider(value: $value, in: range, step: step)
        } else {
            Slider(value: $value, in: range)
        }
    }
}

// MARK: - Palette

private struct CanvasPalette: View {
    let component: PaletteComponent

    var body: some View {
        VStack(spacing: DS.Space.s) {
            FlowLayout(spacing: DS.Space.m, lineSpacing: DS.Space.s) {
                ForEach(Array(component.swatches.enumerated()), id: \.offset) { _, swatch in
                    SwatchView(swatch: swatch, struck: false)
                }
            }
            .frame(maxWidth: .infinity)

            if let avoid = component.avoid, !avoid.isEmpty {
                VStack(spacing: DS.Space.xs) {
                    Text(String(localized: "ui_avoid").uppercased())
                        .font(.caption)
                        .tracking(1.2)
                        .foregroundStyle(DS.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)

                    FlowLayout(spacing: DS.Space.m, lineSpacing: DS.Space.s) {
                        ForEach(Array(avoid.enumerated()), id: \.offset) { _, swatch in
                            SwatchView(swatch: swatch, struck: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if let note = component.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private struct SwatchView: View {
        let swatch: PaletteSwatch
        let struck: Bool

        var body: some View {
            VStack(spacing: DS.Space.xxs) {
                Circle()
                    .fill(Color(hex: swatch.hex))
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(DS.stroke, lineWidth: 1))
                    .overlay {
                        if struck {
                            GeometryReader { geo in
                                Path { path in
                                    path.move(to: CGPoint(x: geo.size.width * 0.15, y: geo.size.height * 0.85))
                                    path.addLine(to: CGPoint(x: geo.size.width * 0.85, y: geo.size.height * 0.15))
                                }
                                .stroke(DS.danger, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            }
                        }
                    }

                if let name = swatch.name, !name.isEmpty {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(swatch.name ?? swatch.hex)
        }
    }
}

// MARK: - Steps

private struct CanvasSteps: View {
    let component: StepsComponent

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            ForEach(Array(component.items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: DS.Space.s) {
                    Text("\(index + 1)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(DS.surfaceRaised, in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)
                        if let detail = item.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(DS.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Product card

private struct CanvasProductCard: View {
    let component: ProductCardComponent

    var body: some View {
        if let url = component.link.flatMap(URL.init(string:)), url.scheme?.hasPrefix("http") == true {
            Link(destination: url) { row }
        } else {
            row
        }
    }

    private var caption: String {
        [component.priceMxn.map { CanvasFormat.amount($0) }, component.store.flatMap { $0.isEmpty ? nil : $0 }]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var row: some View {
        HStack(spacing: DS.Space.s) {
            image
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(component.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !caption.isEmpty {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(DS.textSecondary)
                }

                if let nearby = component.nearby {
                    Label(nearbyText(nearby), systemImage: "figure.walk")
                        .font(.caption)
                        .foregroundStyle(DS.success)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.m))
        .accessibilityElement(children: .combine)
    }

    private func nearbyText(_ nearby: NearbyStore) -> String {
        guard let distance = nearby.distanceM else { return nearby.name }
        return "\(nearby.name) · \(CanvasFormat.number(distance)) m"
    }

    @ViewBuilder private var image: some View {
        if let url = component.imageUrl.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Color(DS.surfaceRaised)
                        .overlay(Image(systemName: "photo").foregroundStyle(DS.textTertiary))
                default:
                    Color(DS.surfaceRaised).shimmer()
                }
            }
        } else {
            Color(DS.surfaceRaised)
                .overlay(Image(systemName: "tshirt").foregroundStyle(DS.textTertiary))
        }
    }
}

// MARK: - Budget bar

private struct CanvasBudgetBar: View {
    let component: BudgetBarComponent

    private var overBudget: Bool {
        guard let budget = component.budgetMxn else { return false }
        return component.totalMxn > budget
    }

    private var valueText: String {
        guard let budget = component.budgetMxn else { return CanvasFormat.amount(component.totalMxn) }
        return String(
            format: String(localized: "ui_budget_format"),
            CanvasFormat.amount(component.totalMxn), CanvasFormat.amount(budget)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            if let label = component.label, !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
            }

            Text(valueText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(overBudget ? DS.warning : DS.textPrimary)

            if let budget = component.budgetMxn, budget > 0 {
                let fraction = min(max(component.totalMxn / budget, 0), 1)
                Capsule()
                    .fill(DS.surfaceRaised)
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Group {
                                if overBudget {
                                    Capsule().fill(DS.warning)
                                } else {
                                    Capsule().fill(DS.accent)
                                }
                            }
                            .frame(width: geo.size.width * fraction)
                        }
                    }
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
#endif
