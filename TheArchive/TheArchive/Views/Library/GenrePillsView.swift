import SwiftUI

struct GenrePillsView: View {
    let genres: [String]
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                pill(label: "All Genres", value: nil)
                ForEach(genres, id: \.self) { genre in
                    pill(label: genre, value: genre)
                }
            }
            .padding(.horizontal, 40)
        }
    }

    @ViewBuilder
    private func pill(label: String, value: String?) -> some View {
        let isActive = selected == value
        Button(label) { selected = value }
            .font(ArchiveTheme.monoFont(size: 14))
            .foregroundColor(isActive ? ArchiveTheme.accent : ArchiveTheme.textMuted)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isActive ? ArchiveTheme.accent.opacity(0.6) : ArchiveTheme.border, lineWidth: 1)
                    .background(isActive ? ArchiveTheme.accent.opacity(0.1) : Color.clear)
            )
            .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
