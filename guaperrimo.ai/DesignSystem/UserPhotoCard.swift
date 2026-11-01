//
//  UserPhotoCard.swift
//  guaperrimo.ai
//

import SwiftUI

/// 3:4 photo card with large radius. Shows a local image, else a remote URL,
/// else a shimmering placeholder.
struct UserPhotoCard: View {
    var image: UIImage? = nil
    var url: String? = nil

    var body: some View {
        Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay { content }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.l).stroke(DS.stroke, lineWidth: 1))
    }

    @ViewBuilder private var content: some View {
        if let image {
            Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
        } else if let url, let remote = URL(string: url) {
            AsyncImage(url: remote) { phase in
                if case .success(let loaded) = phase {
                    loaded.resizable().aspectRatio(contentMode: .fill)
                } else {
                    ShimmerPlaceholder(cornerRadius: DS.Radius.l)
                }
            }
        } else {
            ShimmerPlaceholder(cornerRadius: DS.Radius.l)
        }
    }
}
