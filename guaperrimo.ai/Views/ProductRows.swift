//
//  ProductRows.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

/// 64pt square product picture.
struct ProductThumbnail: View {
    let urlString: String?

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        DS.surfaceRaised
                    }
                }
            } else {
                DS.surfaceRaised
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
    }
}

/// "Comprar" / "Ver producto", "Cómo llegar": the small secondary action used on product rows.
struct ProductActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        SecondaryButton(title: title, systemImage: icon, size: .small, action: action)
    }
}

/// Where a product can be had: a walkable store or online.
struct ProductLocationLine: View {
    let product: ProductDTO
    let nearby: StoreDTO?

    var body: some View {
        if let nearby {
            Label {
                Text("\(nearby.name) · \(distanceLabel(nearby.distanceM))")
            } icon: {
                Image(systemName: "figure.walk")
            }
            .font(.caption)
            .foregroundStyle(DS.success)
        } else {
            let detail = [product.availability, product.delivery].compactMap { $0 }.filter { !$0.isEmpty }.first
            Label {
                Text(detail ?? String(localized: "shopping_online"))
            } icon: {
                Image(systemName: "shippingbox")
            }
            .font(.caption)
            .foregroundStyle(DS.textSecondary)
        }
    }
}

/// A product card: picture, title, price and store, optional purchased checkbox, buy link.
struct ProductRow: View {
    @Environment(\.openURL) private var openURL

    let product: ProductDTO
    var nearby: StoreDTO? = nil
    var showsLocation = false
    var showsDirections = false
    /// nil hides the checkbox.
    var purchased: Bool? = nil
    var onToggle: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ProductThumbnail(urlString: product.imageUrl)

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.title)
                        .font(.subheadline)
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(2)

                    Text(product.priceAndStoreLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.textSecondary)

                    if showsLocation {
                        ProductLocationLine(product: product, nearby: nearby)
                    }
                }

                Spacer(minLength: 0)

                if let purchased, let onToggle {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onToggle()
                    } label: {
                        Image(systemName: purchased ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(purchased ? DS.success : DS.textTertiary)
                    }
                    .accessibilityLabel(String(localized: "shopping_mark"))
                }
            }

            HStack(spacing: 10) {
                if let link = product.link, let url = URL(string: link) {
                    ProductActionButton(
                        title: String(localized: isDirectStoreLink(link) ? "shopping_buy" : "shopping_view_product"),
                        icon: isDirectStoreLink(link) ? "bag" : "arrow.up.right"
                    ) { openURL(url) }
                }
                if showsDirections, let nearby, let url = nearby.mapsUrl {
                    ProductActionButton(title: String(localized: "shopping_directions"), icon: "map") { openURL(url) }
                }
            }
        }
        .padding(12)
        .background(DS.surface.opacity(purchased == true ? 0.5 : 1), in: RoundedRectangle(cornerRadius: DS.Radius.m))
    }
}

/// A walkable store: name, distance, open state, with one "Cómo llegar".
struct StoreHeader: View {
    @Environment(\.openURL) private var openURL
    let store: StoreDTO

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text(store.name).fontWeight(.semibold)
                } icon: {
                    Image(systemName: "figure.walk")
                }
                .font(.subheadline)
                .foregroundStyle(DS.success)

                Text([distanceLabel(store.distanceM), store.openState].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
            }
            Spacer(minLength: 0)
            if let url = store.mapsUrl {
                ProductActionButton(title: String(localized: "shopping_directions"), icon: "map") { openURL(url) }
            }
        }
    }
}
#endif
