//
//  Buttons.swift
//  guaperrimo.ai
//

import SwiftUI

/// Solid rectangular button (radius 6) that darkens while pressed.
private struct SolidButtonStyle: ButtonStyle {
    let fill: Color
    let pressed: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: DS.minTap)
            .padding(.vertical, 1)
            .background(configuration.isPressed ? pressed : fill, in: RoundedRectangle(cornerRadius: DS.Radius.button))
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.button))
    }
}

/// Outlined rectangular button: 1 px border, no fill, slight tint while pressed.
private struct OutlineButtonStyle: ButtonStyle {
    let fullWidth: Bool
    let small: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(small ? .caption.weight(.semibold) : .subheadline.weight(.medium))
            .foregroundStyle(DS.textPrimary)
            .padding(.horizontal, small ? DS.Space.s : DS.Space.l)
            .padding(.vertical, small ? DS.Space.xs : DS.Space.s)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: small ? 36 : DS.minTap)
            .background(configuration.isPressed ? DS.surfaceRaised : Color.clear, in: RoundedRectangle(cornerRadius: DS.Radius.button))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.button).stroke(DS.strokeStrong, lineWidth: 1))
            .frame(minHeight: DS.minTap)
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.button))
    }
}

/// Full-width main call to action. `.accent` is solid cognac (max one per screen);
/// `.light` is solid hueso with obsidiana text.
struct PrimaryButton: View {
    enum Style { case accent, light }

    let title: String
    var systemImage: String? = nil
    var style: Style = .accent
    var accessibilityLabel: String? = nil
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) { label }
            .buttonStyle(SolidButtonStyle(
                fill: style == .accent ? DS.accent : DS.textPrimary,
                pressed: style == .accent ? DS.accentPressed : DS.textSecondary,
                foreground: style == .accent ? DS.onAccent : DS.bg
            ))
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

/// Secondary action: outlined, no fill.
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
        Button(action: action) { label }
            .buttonStyle(OutlineButtonStyle(fullWidth: fullWidth, small: size == .small))
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
                .underline(true, color: DS.stroke)
                .frame(minWidth: DS.minTap, minHeight: DS.minTap)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibilityLabel ?? title)
    }
}
