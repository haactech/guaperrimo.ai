//
//  GenerativeCanvas.swift
//  guaperrimo.ai
//
//  Renders the closed catalog of generative UI components (see UIComponent)
//  with the design system. One small view per component; unknown types render
//  nothing. Interaction is reported through closures, never handled here.
//
//  Signature detail of the visual language: the measuring tape (slider and
//  budget line). Everything else stays plain.
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

/// Small uppercase label, as on a garment tag.
private struct CanvasLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(DS.Font.label)
            .tracking(DS.labelTracking)
            .foregroundStyle(DS.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Measuring tape

/// A tailor's tape: a baseline with ticks hanging below, every fifth one taller.
private struct TapeShape: Shape {
    var ticks: Int = 40

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: y))
        path.addLine(to: CGPoint(x: rect.maxX, y: y))
        for i in 0...ticks {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(ticks)
            let height = i % 5 == 0 ? rect.height * 0.5 : rect.height * 0.25
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x, y: y + height))
        }
        return path
    }
}

/// Slider drawn as a measuring tape with a solid cognac thumb.
private struct TapeSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let isEnabled: Bool

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat(min(max((value - range.lowerBound) / span, 0), 1))
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let midY = geo.size.height / 2
            ZStack(alignment: .leading) {
                TapeShape()
                    .stroke(DS.strokeStrong, lineWidth: 1)
                    .frame(height: 20)

                Rectangle()
                    .fill(DS.accent)
                    .frame(width: max(width * fraction, 0), height: 2)
                    .position(x: width * fraction / 2, y: midY)

                Circle()
                    .fill(DS.accent)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(DS.bg, lineWidth: 2))
                    .position(x: width * fraction, y: midY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard isEnabled, width > 0 else { return }
                        set(fraction: gesture.location.x / width)
                    }
            )
        }
        .frame(height: DS.minTap)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement()
        .accessibilityAdjustableAction { direction in
            let delta = step > 0 ? step : (range.upperBound - range.lowerBound) / 20
            switch direction {
            case .increment: value = min(value + delta, range.upperBound)
            case .decrement: value = max(value - delta, range.lowerBound)
            @unknown default: break
            }
        }
    }

    private func set(fraction raw: CGFloat) {
        let clamped = min(max(raw, 0), 1)
        var next = range.lowerBound + Double(clamped) * (range.upperBound - range.lowerBound)
        if step > 0 { next = (next / step).rounded() * step }
        value = min(max(next, range.lowerBound), range.upperBound)
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
            Text(component.text)
                .font(DS.Font.heading)
                .foregroundStyle(DS.textPrimary)
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
                        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.s))
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
        VStack(alignment: .leading, spacing: DS.Space.s) {
            CanvasLabel(text: component.label)

            Text(CanvasFormat.amount(value, unit: component.unit))
                .font(DS.Font.monoLarge)
                .monospacedDigit()
                .foregroundStyle(DS.textPrimary)
                .accessibilityHidden(true)

            TapeSlider(value: $value, range: range, step: component.step ?? 0, isEnabled: isInteractive)
                .accessibilityLabel(component.label)
                .accessibilityValue(CanvasFormat.amount(value, unit: component.unit))

            HStack {
                Text(CanvasFormat.number(component.min))
                Spacer()
                Text(CanvasFormat.number(component.max))
            }
            .font(DS.Font.monoSmall)
            .foregroundStyle(DS.textTertiary)
            .accessibilityHidden(true)

            PrimaryButton(title: String(localized: "ui_continue")) {
                onConfirm(component.id, "\(Int(value.rounded()))")
            }
            .disabled(!isInteractive)
            .padding(.top, DS.Space.xxs)
        }
        .padding(DS.Space.m)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.m))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.m).stroke(DS.stroke, lineWidth: 1))
    }
}

// MARK: - Palette

private struct CanvasPalette: View {
    let component: PaletteComponent

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            FlowLayout(spacing: DS.Space.xs, lineSpacing: DS.Space.s) {
                ForEach(Array(component.swatches.enumerated()), id: \.offset) { _, swatch in
                    SwatchView(swatch: swatch, struck: false)
                }
            }
            .frame(maxWidth: .infinity)

            if let avoid = component.avoid, !avoid.isEmpty {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    CanvasLabel(text: String(localized: "ui_avoid"))
                        .accessibilityAddTraits(.isHeader)

                    FlowLayout(spacing: DS.Space.xs, lineSpacing: DS.Space.s) {
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

    /// A swatch of fabric: a square with a hairline, the name underneath.
    private struct SwatchView: View {
        let swatch: PaletteSwatch
        let struck: Bool

        var body: some View {
            VStack(spacing: DS.Space.xxs) {
                RoundedRectangle(cornerRadius: DS.Radius.s)
                    .fill(Color(hex: swatch.hex))
                    .frame(width: 48, height: 48)
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.s).stroke(DS.stroke, lineWidth: 1))
                    .overlay {
                        if struck {
                            GeometryReader { geo in
                                Path { path in
                                    path.move(to: CGPoint(x: geo.size.width * 0.1, y: geo.size.height * 0.9))
                                    path.addLine(to: CGPoint(x: geo.size.width * 0.9, y: geo.size.height * 0.1))
                                }
                                .stroke(DS.danger, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            }
                        }
                    }
                    .opacity(struck ? 0.7 : 1)

                Text(swatch.name ?? " ")
                    .font(.caption2)
                    .foregroundStyle(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 60, height: 30, alignment: .top)
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
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(component.items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                    Text("\(index + 1)")
                        .font(DS.Font.numeral)
                        .foregroundStyle(DS.brass)
                        .frame(width: 28, alignment: .leading)
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
                .padding(.vertical, DS.Space.s)
                .accessibilityElement(children: .combine)

                if index < component.items.count - 1 {
                    Rectangle().fill(DS.stroke).frame(height: 1)
                }
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

    /// "Liverpool · Liverpool Andares"
    private var meta: String {
        var parts: [String] = []
        if let store = component.store, !store.isEmpty { parts.append(store) }
        if let nearby = component.nearby, nearby.name != component.store { parts.append(nearby.name) }
        return parts.joined(separator: " · ")
    }

    /// "450 m"
    private var distance: String? {
        guard let meters = component.nearby?.distanceM else { return nil }
        return "\(CanvasFormat.number(meters)) m"
    }

    private var row: some View {
        HStack(spacing: DS.Space.s) {
            image
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(component.title)
                    .font(.subheadline)
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let price = component.priceMxn {
                    Text(CanvasFormat.amount(price))
                        .font(DS.Font.mono)
                        .monospacedDigit()
                        .foregroundStyle(DS.textPrimary)
                }

                if !meta.isEmpty || distance != nil {
                    HStack(spacing: DS.Space.xs) {
                        if !meta.isEmpty {
                            Text(meta)
                                .font(.caption)
                                .foregroundStyle(DS.textTertiary)
                                .lineLimit(1)
                        }
                        if let distance {
                            Text(distance)
                                .font(DS.Font.monoSmall)
                                .foregroundStyle(DS.accent)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Space.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.m))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.m).stroke(DS.stroke, lineWidth: 1))
        .accessibilityElement(children: .combine)
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
                CanvasLabel(text: label)
            }

            Text(valueText)
                .font(DS.Font.mono)
                .monospacedDigit()
                .foregroundStyle(overBudget ? DS.warning : DS.textPrimary)

            if let budget = component.budgetMxn, budget > 0 {
                let fraction = min(max(component.totalMxn / budget, 0), 1)
                let ink = overBudget ? DS.warning : DS.accent
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        TapeShape()
                            .stroke(DS.strokeStrong, lineWidth: 1)

                        Rectangle()
                            .fill(ink)
                            .frame(width: geo.size.width * fraction, height: 2)
                            .position(x: geo.size.width * fraction / 2, y: geo.size.height / 2)

                        Rectangle()
                            .fill(ink)
                            .frame(width: 2, height: 14)
                            .position(x: geo.size.width * fraction, y: geo.size.height / 2)
                    }
                }
                .frame(height: 20)
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
#endif
