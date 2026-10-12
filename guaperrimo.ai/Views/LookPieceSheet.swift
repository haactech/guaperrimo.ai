//
//  LookPieceSheet.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct LookPieceSheet: View {
    let pieces: [LookPieceItem]
    let onSave: () -> Void

    @State private var saved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(pieces) { piece in
                        pieceRow(piece)
                    }
                }
                .padding(16)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    Button {
                        onSave()
                        saved = true
                    } label: {
                        Label(String(localized: "shopping_save_look"), systemImage: "bag.badge.plus")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white, in: Capsule())
                    }
                    if saved {
                        Text(String(localized: "shopping_look_saved"))
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black)
            }
            .background(Color.black)
            .navigationTitle(String(localized: "looks_pieces_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.black)
    }

    private func pieceRow(_ piece: LookPieceItem) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let urlStr = piece.productImageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Color.white.opacity(0.08)
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 72, height: 72)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(piece.productName ?? piece.slotDescription)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(piece.category.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))

                Text(piece.slotDescription)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}
#endif
