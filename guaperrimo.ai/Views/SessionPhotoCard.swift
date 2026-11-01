//
//  SessionPhotoCard.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

/// The user's photo, kept on screen for the whole session so the stylist's words
/// always have something to point at. Prefers the captured image; falls back to the uploaded URL.
struct SessionPhotoCard: View {
    let image: UIImage?
    let imageUrl: String

    var body: some View {
        Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay { content }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            AsyncImage(url: URL(string: imageUrl)) { phase in
                switch phase {
                case .success(let loaded):
                    loaded
                        .resizable()
                        .scaledToFill()
                default:
                    Rectangle().fill(Color.white.opacity(0.08))
                }
            }
        }
    }
}
#endif
