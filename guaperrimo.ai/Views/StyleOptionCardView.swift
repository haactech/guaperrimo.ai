//
//  StyleOptionCardView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct StyleOptionCardView: View {
    let option: StyleOption
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(option.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
