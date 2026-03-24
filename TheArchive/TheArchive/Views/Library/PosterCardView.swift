import SwiftUI

struct PosterCardView: View {
    let item: LibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Poster
            ZStack(alignment: .bottomLeading) {
                // Background: artwork or gradient fallback
                AsyncImage(url: URL(string: item.artworkURL)) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        ArchiveTheme.posterGradient(for: item.title)
                    }
                }
                .frame(width: 220, height: 330)
                .clipped()

                // Catalog badge
                Text(item.catalogID)
                    .font(ArchiveTheme.monoFont(size: 11))
                    .foregroundColor(ArchiveTheme.textMuted)
                    .padding(6)
            }
            .frame(width: 220, height: 330)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(ArchiveTheme.border, lineWidth: 1)
            )

            // Title + meta
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(ArchiveTheme.bodyFont(size: 16))
                    .foregroundColor(ArchiveTheme.textPrimary)
                    .lineLimit(2)
                Text(item.type == .film ? "\(item.year) · FILM" : "SERIES · \(item.year)")
                    .font(ArchiveTheme.monoFont(size: 12))
                    .foregroundColor(ArchiveTheme.textMuted)
            }
            .padding(.top, 8)
            .frame(width: 220, alignment: .leading)
        }
        .accessibilityLabel("\(item.type == .film ? "Film" : "Series"): \(item.title), \(item.year)")
    }
}
