//
//  Controls.swift
//  guaperrimo.ai
//

import SwiftUI

/// Option pill. Wrap in a Button when it must be tappable.
struct Chip: View {
    let label: String
    var isSelected: Bool = false

    var body: some View {
        Text(label)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? Color.white : DS.textSecondary)
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, DS.Space.xs)
            .frame(minHeight: DS.minTap - DS.Space.s)
            .background {
                if isSelected {
                    Capsule().fill(DS.accent)
                } else {
                    Capsule().fill(DS.surface)
                }
            }
            .overlay(Capsule().stroke(isSelected ? Color.clear : DS.stroke, lineWidth: 1))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Segmented control styled with the surface/stroke tokens.
struct SegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: String)]

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = option.value == selection
                Button {
                    guard !isSelected else { return }
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.easeInOut(duration: 0.2)) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isSelected ? DS.textPrimary : DS.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if isSelected {
                                Capsule().fill(DS.surfaceRaised)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(DS.surface, in: Capsule())
        .overlay(Capsule().stroke(DS.stroke, lineWidth: 1))
    }
}

/// Simple confirmation capsule.
struct Toast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(DS.textPrimary)
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, DS.Space.s)
            .background(DS.surfaceRaised, in: Capsule())
            .overlay(Capsule().stroke(DS.stroke, lineWidth: 1))
            .accessibilityAddTraits(.updatesFrequently)
    }
}
