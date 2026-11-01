//
//  Buttons.swift
//  guaperrimo.ai
//

import SwiftUI

/// Full-width main call to action. `.accent` is the gradient (max one per screen);
/// `.light` is the white capsule with dark text.
struct PrimaryButton: View {
    enum Style { case accent, light }

    let title: String
    var systemImage: String? = nil
    var style: Style = .accent
    var accessibilityLabel: String? = nil
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            label
                .font(.headline)
                .foregroundStyle(style == .accent ? Color.white : Color.black)
                .frame(maxWidth: .infinity, minHeight: DS.minTap)
                .padding(.vertical, 1)
                .background {
                    switch style {
                    case .accent: Capsule().fill(DS.accent)
                    case .light: Capsule().fill(Color.white)
                    }
                }
                .contentShape(Capsule())
        }
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(accessibilityLabel ?? title)
    }

    @ViewBuilder private var label: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

/// Secondary action: raised surface with a hairline stroke.
struct SecondaryButton: View {
    enum Size { case regular, small }

    let title: String
    var systemImage: String? = nil
    var size: Size = .regular
    var fullWidth: Bool = false
    var accessibilityLabel: String? = nil
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            label
                .font(size == .small ? .caption.weight(.semibold) : .subheadline.weight(.medium))
                .foregroundStyle(DS.textPrimary)
                .padding(.horizontal, size == .small ? DS.Space.s : DS.Space.l)
                .padding(.vertical, size == .small ? DS.Space.xs : DS.Space.s)
                .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: size == .small ? 36 : DS.minTap)
                .background(DS.surfaceRaised, in: Capsule())
                .overlay(Capsule().stroke(DS.stroke, lineWidth: 1))
                .frame(minHeight: DS.minTap)
                .contentShape(Capsule())
        }
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(accessibilityLabel ?? title)
    }

    @ViewBuilder private var label: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

/// Text-only action.
struct TertiaryButton: View {
    let title: String
    var accessibilityLabel: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(DS.textSecondary)
                .frame(minWidth: DS.minTap, minHeight: DS.minTap)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}
