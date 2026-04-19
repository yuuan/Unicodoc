import SwiftUI

struct SidebarView: View {
    @Binding var selection: UInt32?
    /// Fires on *every* tap — including re-tapping the already-selected row —
    /// so the caller can re-trigger scroll even when `selection` doesn't change.
    let onTap: (UInt32) -> Void
    @Binding var favorites: Set<UInt32>

    var body: some View {
        List(selection: $selection) {
            if !favoriteBlocks.isEmpty {
                Section {
                    ForEach(favoriteBlocks) { block in
                        BlockRow(
                            block: block,
                            isFavorite: true,
                            onToggleFavorite: { toggleFavorite(block.id) },
                            onTap: { onTap(block.id) }
                        )
                    }
                }
            }
            Section {
                ForEach(UnicodeBlocks.all) { block in
                    BlockRow(
                        block: block,
                        isFavorite: favorites.contains(block.id),
                        onToggleFavorite: { toggleFavorite(block.id) },
                        onTap: { onTap(block.id) }
                    )
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var favoriteBlocks: [UnicodeBlock] {
        UnicodeBlocks.all.filter { favorites.contains($0.id) }
    }

    private func toggleFavorite(_ id: UInt32) {
        if favorites.contains(id) {
            favorites.remove(id)
        } else {
            favorites.insert(id)
        }
    }
}

private struct BlockRow: View {
    let block: UnicodeBlock
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onTap: () -> Void

    @State private var isHovered = false

    private var starVisible: Bool {
        isFavorite || isHovered
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(block.localizedName)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture().onEnded { onTap() })

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? Color.yellow : Color.secondary)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .help(isFavorite ? "Remove from Favorites" : "Add to Favorites")
            .opacity(starVisible ? 1 : 0)
            .allowsHitTesting(starVisible)
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
