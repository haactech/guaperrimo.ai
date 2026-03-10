//
//  PriorityActionCardView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct PriorityActionCardView: View {
    let action: PriorityAction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(action.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Text(action.description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                badge(label: "Impacto: \(action.impact)", color: impactColor)
                badge(label: "Esfuerzo: \(action.effort)", color: effortColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor.opacity(0.4), lineWidth: 1)
        )
    }

    private func badge(label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var impactColor: Color {
        switch action.impact {
        case "alto": return .green
        case "medio": return .orange
        default: return .gray
        }
    }

    private var effortColor: Color {
        switch action.effort {
        case "bajo": return .green
        case "medio": return .orange
        default: return .red
        }
    }

    private var cardBackground: Color {
        if action.impact == "alto" && action.effort == "bajo" {
            return Color.green.opacity(0.12)
        } else if action.impact == "alto" {
            return Color.orange.opacity(0.10)
        }
        return Color.white.opacity(0.08)
    }

    private var cardBorderColor: Color {
        if action.impact == "alto" && action.effort == "bajo" {
            return .green
        } else if action.impact == "alto" {
            return .orange
        }
        return .white.opacity(0.2)
    }
}
#endif
