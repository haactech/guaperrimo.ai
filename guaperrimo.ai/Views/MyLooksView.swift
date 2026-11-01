//
//  MyLooksView.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

/// "Mis looks": every look the user kept (Looks) and what is left to buy (Compras).
struct MyLooksView: View {
    enum Tab: Hashable { case looks, shopping }

    @State private var store = SavedLooksStore.shared
    @State private var tab: Tab = .looks
    @State private var openLook: SavedLook?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            TexturedBackground()

            VStack(spacing: DS.Space.s) {
                ScreenHeader(
                    title: String(localized: "shopping_title"),
                    closeLabel: String(localized: "preview_close"),
                    onClose: { dismiss() }
                )

                if store.hasLooks {
                    SegmentedControl(selection: $tab, options: [
                        (.looks, String(localized: "mylooks_tab_looks")),
                        (.shopping, String(localized: "mylooks_tab_shopping")),
                    ])
                    .padding(.horizontal, DS.Space.inset)

                    switch tab {
                    case .looks: looksGrid
                    case .shopping: ShoppingTab(store: store)
                    }
                } else {
                    emptyState
                }
            }
        }
        .sheet(item: $openLook) { look in
            SavedLookDetailSheet(look: look)
        }
    }

    // MARK: - Looks

    private var looksGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                ForEach(store.looks) { look in
                    Button { openLook = look } label: { card(look) }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation { store.remove(id: look.id) }
                            } label: {
                                Label(String(localized: "mylooks_delete"), systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, DS.Space.inset)
            .padding(.vertical, DS.Space.m)
        }
    }

    private func card(_ look: SavedLook) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            UserPhotoCard(url: look.coverImageUrl)
            Text(look.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if !look.summaryLine.isEmpty {
                Text(look.summaryLine)
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "heart")
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

// MARK: - Compras

private struct ShoppingTab: View {
    let store: SavedLooksStore

    var body: some View {
        let basket = ShoppingBasket(looks: store.looks)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if basket.isEmpty {
                    Text(String(localized: "mylooks_shopping_empty"))
                        .font(.body)
                        .foregroundStyle(DS.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                } else {
                    totals(basket)

                    ForEach(basket.pending) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            if let storeInfo = group.store {
                                StoreHeader(store: storeInfo)
                            } else {
                                Label(String(localized: "shopping_online"), systemImage: "shippingbox")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(DS.textSecondary)
                            }
                            ForEach(group.entries) { row($0) }
                        }
                    }

                    if !basket.purchased.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(String(localized: "mylooks_already_have"), systemImage: "checkmark.circle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DS.textSecondary)
                            ForEach(basket.purchased) { row($0) }
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Space.inset)
            .padding(.vertical, DS.Space.m)
            .animation(.easeInOut(duration: 0.25), value: basket)
        }
    }

    private func totals(_ basket: ShoppingBasket) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "shopping_total"))
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)
                Spacer()
                Text("$\(Int(basket.totalMxn.rounded()).formatted(.number.grouping(.automatic))) MXN")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
            }
            Text(countsLine(basket))
                .font(.caption)
                .foregroundStyle(DS.textSecondary)
        }
    }

    private func countsLine(_ basket: ShoppingBasket) -> String {
        let items = basket.itemCount == 1
            ? String(localized: "mylooks_item_one")
            : String(format: String(localized: "mylooks_items_other"), basket.itemCount)
        guard basket.nearbyStoreCount > 0 else { return items }
        let stores = basket.nearbyStoreCount == 1
            ? String(localized: "mylooks_store_near_one")
            : String(format: String(localized: "mylooks_stores_near"), basket.nearbyStoreCount)
        return "\(items) · \(stores)"
    }

    private func row(_ entry: ShoppingBasket.Entry) -> some View {
        ProductRow(
            product: entry.product,
            nearby: entry.store,
            purchased: entry.purchased,
            onToggle: { store.setPurchased(!entry.purchased, productId: entry.product.id) }
        )
        .transition(.opacity)
    }
}

// MARK: - Detail

private struct SavedLookDetailSheet: View {
    let look: SavedLook
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                ScreenHeader(title: look.name, closeLabel: String(localized: "preview_close"), onClose: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        UserPhotoCard(url: look.coverImageUrl)
                            .frame(maxWidth: 280)
                            .frame(maxWidth: .infinity)

                        if !look.description.isEmpty {
                            Text(look.description)
                                .font(.subheadline)
                                .foregroundStyle(DS.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !look.summaryLine.isEmpty {
                            Text(look.summaryLine)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DS.textPrimary)
                        }

                        ForEach(look.products) { product in
                            ProductRow(product: product, nearby: look.store(for: product), showsLocation: true)
                        }

                        if !look.stores.isEmpty {
                            storesSection
                        }
                    }
                    .padding(.horizontal, DS.Space.inset)
                    .padding(.vertical, DS.Space.m)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(DS.bg)
    }

    private var storesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "shopping_stores_title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.textPrimary)
            ForEach(look.stores) { s in
                Button {
                    if let url = s.mapsUrl { openURL(url) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse").foregroundStyle(DS.success)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(.subheadline).foregroundStyle(DS.textPrimary)
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
}
#endif
