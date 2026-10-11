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
            Color.black.ignoresSafeArea()

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
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                } else {
                    emptyState
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1), in: Circle())
            }

            Spacer()

            Text(String(localized: "shopping_title"))
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Summary

    private func summaryCard(_ list: SavedShoppingList) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(list.summary)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
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
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Items

    private func itemSection(_ item: ShoppingItemDTO, list: SavedShoppingList) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(slotLabel(item.slot).uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.5))
                Text(item.description)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            if let why = item.why, !why.isEmpty {
                Text(why)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if item.products.isEmpty {
                Text(String(localized: "shopping_no_product"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
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
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .strikethrough(purchased, color: .white.opacity(0.6))

                    Text("\(product.priceLabel) · \(product.store)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))

                    locationLine(product, nearby: nearby)
                }

                Spacer(minLength: 0)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    store.togglePurchased(product.id)
                } label: {
                    Image(systemName: purchased ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(purchased ? .green : .white.opacity(0.4))
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
        .background(Color.white.opacity(purchased ? 0.04 : 0.08), in: RoundedRectangle(cornerRadius: 14))
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
            .foregroundStyle(.green)
        } else {
            let detail = [product.availability, product.delivery].compactMap { $0 }.filter { !$0.isEmpty }.first
            Label {
                Text(detail ?? String(localized: "shopping_online"))
            } icon: {
                Image(systemName: "shippingbox")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.6))
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
                        Color.white.opacity(0.08)
                    }
                }
            } else {
                Color.white.opacity(0.08)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 36)
                .background(Color.white.opacity(0.15), in: Capsule())
        }
    }

    // MARK: - Stores

    private func storesSection(_ stores: [StoreDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "shopping_stores_title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            ForEach(stores) { s in
                Button {
                    if let url = s.mapsUrl { openURL(url) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Text([s.address, s.openState].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(distanceLabel(s.distanceM))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bag")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.4))
            Text(String(localized: "shopping_empty"))
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}
#endif
