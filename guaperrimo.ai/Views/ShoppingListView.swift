//
//  ShoppingListView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

/// "Mi lista": the products the stylist recommended, with price, store,
/// approximate distance and a link, kept as a reference for shopping.
struct ShoppingListView: View {
    @State private var store = ShoppingListStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            TexturedBackground()

            VStack(spacing: 0) {
                header

                if let list = store.current {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            summaryCard(list)

                            ForEach(list.items) { item in
                                itemSection(item, list: list)
                            }

                            if !list.stores.isEmpty {
                                storesSection(list.stores)
                            }
                        }
                        .padding(.horizontal, DS.Space.inset)
                        .padding(.vertical, DS.Space.m)
                    }
                } else {
                    emptyState
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ScreenHeader(
            title: String(localized: "shopping_title"),
            closeLabel: String(localized: "preview_close"),
            onClose: { dismiss() }
        )
    }

    // MARK: - Summary

    private func summaryCard(_ list: SavedShoppingList) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(cleanStylistCopy(list.summary))
                .font(.subheadline)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("\(String(localized: "shopping_saved_on")) \(list.savedAt.formatted(date: .abbreviated, time: .omitted))")
                Spacer()
                if list.totalMxn > 0 {
                    Text("\(String(localized: "shopping_total")): $\(Int(list.totalMxn.rounded())) MXN")
                        .fontWeight(.semibold)
                }
            }
            .font(.caption)
            .foregroundStyle(DS.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.m))
    }

    // MARK: - Items

    private func itemSection(_ item: ShoppingItemDTO, list: SavedShoppingList) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(slotLabel(item.slot).uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(DS.textTertiary)
                Text(item.displayDescription)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
            }

            if let why = item.displayWhy {
                Text(why)
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if item.products.isEmpty {
                Text(String(localized: "shopping_no_product"))
                    .font(.caption)
                    .foregroundStyle(DS.textTertiary)
            }

            ForEach(item.products) { product in
                productRow(product, nearby: list.store(for: product), purchased: list.purchased.contains(product.id))
            }
        }
    }

    private func productRow(_ product: ProductDTO, nearby: StoreDTO?, purchased: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                thumbnail(product.imageUrl)

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.title)
                        .font(.subheadline)
                        .foregroundStyle(DS.textPrimary)
                        .lineLimit(2)
                        .strikethrough(purchased, color: DS.textSecondary)

                    Text(product.priceAndStoreLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.textSecondary)

                    locationLine(product, nearby: nearby)
                }

                Spacer(minLength: 0)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.togglePurchased(product.id)
                } label: {
                    Image(systemName: purchased ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(purchased ? DS.success : DS.textTertiary)
                }
                .accessibilityLabel(String(localized: "shopping_mark"))
            }

            HStack(spacing: 10) {
                if let link = product.link, let url = URL(string: link) {
                    actionButton(String(localized: "shopping_buy"), icon: "bag") { openURL(url) }
                }
                if let nearby, let url = nearby.mapsUrl {
                    actionButton(String(localized: "shopping_directions"), icon: "map") { openURL(url) }
                }
            }
        }
        .padding(12)
        .background(purchased ? DS.surface.opacity(0.5) : DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.m))
    }

    @ViewBuilder
    private func locationLine(_ product: ProductDTO, nearby: StoreDTO?) -> some View {
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

    private func thumbnail(_ urlString: String?) -> some View {
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

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        SecondaryButton(title: title, systemImage: icon, size: .small, action: action)
    }

    // MARK: - Stores

    private func storesSection(_ stores: [StoreDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "shopping_stores_title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.textPrimary)

            ForEach(stores) { s in
                Button {
                    if let url = s.mapsUrl { openURL(url) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(DS.success)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name)
                                .font(.subheadline)
                                .foregroundStyle(DS.textPrimary)
                            Text([s.address, s.openState].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(DS.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(distanceLabel(s.distanceM))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(DS.textSecondary)
                    }
                    .padding(12)
                    .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.s))
                }
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bag")
                .font(.largeTitle)
                .foregroundStyle(DS.textTertiary)
            Text(String(localized: "shopping_empty"))
                .font(.body)
                .foregroundStyle(DS.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}
#endif
