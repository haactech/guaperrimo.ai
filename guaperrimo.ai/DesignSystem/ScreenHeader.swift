//
//  ScreenHeader.swift
//  guaperrimo.ai
//

import SwiftUI

/// Round 36pt icon button (close, compare, bag...). Outlined, with a dark scrim
/// so it stays legible over photos. Always pass an accessibility label.
struct IconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.textPrimary)
                .frame(width: 36, height: 36)
                .background(DS.bg.opacity(0.6), in: Circle())
                .overlay(Circle().stroke(DS.strokeStrong, lineWidth: 1))
                .contentShape(Circle().inset(by: -4)) // 44pt hit area, 36pt look
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Top bar: leading slot (usually the close button), centered serif title, trailing slot.
struct ScreenHeader<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            leading
            Spacer()
            Text(title)
                .font(DS.Font.heading)
                .foregroundStyle(DS.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            trailing
        }
        .padding(.horizontal, DS.Space.m)
        .padding(.top, DS.Space.xs)
        .padding(.bottom, DS.Space.s)
    }
}

extension ScreenHeader where Trailing == HeaderSpacer {
    /// Header with a 36pt spacer on the trailing side.
    init(title: String, @ViewBuilder leading: () -> Leading) {
        self.title = title
        self.leading = leading()
        self.trailing = HeaderSpacer()
    }
}

extension ScreenHeader where Leading == IconButton, Trailing == HeaderSpacer {
    /// Header with a close (X) button and a 36pt spacer.
    init(title: String, closeLabel: String, onClose: @escaping () -> Void) {
        self.title = title
        self.leading = IconButton(systemName: "xmark", accessibilityLabel: closeLabel, action: onClose)
        self.trailing = HeaderSpacer()
    }
}

/// Invisible 36pt block that balances the title when there is no trailing control.
struct HeaderSpacer: View {
    var body: some View { Color.clear.frame(width: 36, height: 36) }
}
