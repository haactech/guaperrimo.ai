//
//  LookPieceSheet.swift
//  guaperrimo.ai
//

#if os(iOS)
import SwiftUI

struct LookPieceSheet: View {
    let pieces: [LookPieceItem]

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
            .background(DS.bg)
            .navigationTitle(String(localized: "looks_pieces_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(DS.bg)
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
                        DS.surfaceRaised
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DS.surfaceRaised)
                    .frame(width: 72, height: 72)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(piece.productName ?? piece.slotDescription)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)

                Text(slotLabel(piece.category))
                    .font(.caption)
                    .foregroundStyle(DS.textTertiary)

                Text(piece.slotDescription)
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.Radius.s))
    }
}
#endif
