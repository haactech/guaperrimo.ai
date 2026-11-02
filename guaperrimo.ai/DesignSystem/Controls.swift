//
//  Controls.swift
//  guaperrimo.ai
//

import SwiftUI

/// Option tag, like a garment label: rectangular, 1 px border. Selected: cognac
/// border and a 12 % cognac fill. Wrap in a Button when it must be tappable.
struct Chip: View {
    let label: String
    var isSelected: Bool = false

    var body: some View {
        Text(label)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(DS.textPrimary)
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.xs)
            .frame(minHeight: DS.minTap - DS.Space.s)
            .background(isSelected ? DS.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: DS.Radius.s))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.s)
                    .stroke(isSelected ? DS.accent : DS.strokeStrong, lineWidth: 1)
            )
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Segmented control: outlined track, raised selected segment.
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
                                RoundedRectangle(cornerRadius: DS.Radius.s).fill(DS.surfaceRaised)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.s))
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.button))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.button).stroke(DS.stroke, lineWidth: 1))
    }
}

/// Simple confirmation.
struct Toast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(DS.textPrimary)
            .padding(.horizontal, DS.Space.m)
            .padding(.vertical, DS.Space.s)
            .background(DS.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.button))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.button).stroke(DS.stroke, lineWidth: 1))
            .accessibilityAddTraits(.updatesFrequently)
    }
}
