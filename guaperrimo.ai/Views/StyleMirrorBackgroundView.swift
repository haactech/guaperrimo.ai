//
//  StyleMirrorBackgroundView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct StyleMirrorBackgroundView: View {
    @State private var breathe: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 20
            let cols = Int(size.width / spacing) + 1
            let rows = Int(size.height / spacing) + 1
            let baseOpacity = 0.03 + breathe * 0.06

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * spacing + spacing / 2
                    let y = CGFloat(row) * spacing + spacing / 2
                    let path = Circle().path(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
                    context.fill(path, with: .color(.white.opacity(baseOpacity)))
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                breathe = 1
            }
        }
    }
}
#endif
