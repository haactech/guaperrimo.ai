//
//  LookComparisonView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct LookComparisonView: View {
    let look: LookItem
    let originalImageUrl: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            TexturedBackground()

            VStack(spacing: 0) {
                ScreenHeader(
                    title: look.name,
                    closeLabel: String(localized: "preview_close"),
                    onClose: onDismiss
                )

                BeforeAfterView(
                    beforeURL: URL(string: originalImageUrl),
                    afterURL: look.finalImageUrl.flatMap { URL(string: $0) }
                )

                Spacer()

                PrimaryButton(title: String(localized: "tryon_done")) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onDismiss()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, DS.Space.xl)
            }
        }
    }
}
#endif
