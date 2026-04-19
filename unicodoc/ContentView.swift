import SwiftUI

struct ContentView: View {
    @State private var selectedBlockID: UInt32? = AppPersistence.loadBlockID()
    @State private var selectedScalar: UInt32? = AppPersistence.loadSelectedScalar()
    @State private var searchText: String = ""
    @State private var scrollTargetRow: Double? = AppPersistence.loadScrollRow()
    @State private var scrollTargetBump: Int = 0
    @State private var visibleTopCP: UInt32? = AppPersistence.loadScrollRow()
        .map { UInt32(max(0, min($0, Double(0x10FFFF / 16)))) * 16 }

    /// Set by `jump(to:)` before mutating `selectedBlockID`; consumed by the
    /// selectedBlockID onChange to scroll to the specific code point's row
    /// instead of the block's first row.
    @State private var searchJumpCP: UInt32?

    @State private var isSearchExpanded: Bool = false
    @State private var searchShouldFocus: Bool = false

    /// Query that produced the currently-selected scalar. Pressing Enter again
    /// with the same query cycles to the next match instead of starting over.
    @State private var lastSearchedQuery: String = ""

    @State private var favorites: Set<UInt32> = AppPersistence.loadFavorites()

    private var selectedBlock: UnicodeBlock? {
        guard let id = selectedBlockID else { return nil }
        return UnicodeBlocks.all.first { $0.id == id }
    }

    /// The block containing the top-most visible row of the grid. Updates as
    /// the user scrolls. Falls back to the sidebar selection before the first
    /// scroll event fires.
    private var displayBlock: UnicodeBlock? {
        if let cp = visibleTopCP, let b = UnicodeBlocks.block(containing: cp) {
            return b
        }
        return selectedBlock
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: $selectedBlockID,
                onTap: { id in sidebarTapped(id) },
                favorites: $favorites
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 360)
        } detail: {
            VStack(spacing: 0) {
                CharacterTableView(
                    selected: $selectedScalar,
                    scrollTarget: scrollTargetRow,
                    scrollTargetBump: scrollTargetBump,
                    onScrollPositionChange: { row in handleScroll(row: row) }
                )
                Divider()
                CharacterDetailView(scalar: selectedScalar)
                    .frame(height: 96)
                    .frame(maxWidth: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
            }
            .navigationTitle(displayTitle(for: displayBlock))
            .navigationSubtitle(displayBlock.map(blockRangeLabel) ?? "")
        }
        .onChange(of: favorites) { _, newValue in AppPersistence.saveFavorites(newValue) }
        .onChange(of: selectedScalar) { _, newValue in AppPersistence.saveSelectedScalar(newValue) }
        .onChange(of: selectedBlockID) { _, newValue in handleBlockSelectionChanged(newValue) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    FontPickerCoordinator.shared.showPanel()
                } label: {
                    Image(systemName: "textformat")
                }
                .help("Change Font (⌘T)")
            }
            ToolbarItem(placement: .primaryAction) {
                if isSearchExpanded {
                    SearchField(
                        text: $searchText,
                        shouldFocus: $searchShouldFocus,
                        placeholder: "Search (あ, 0041, HIRAGANA)",
                        onSubmit: { handleSearch() },
                        onCancel: { collapseSearch() }
                    )
                    .frame(width: 280)
                } else {
                    Button {
                        expandSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .help("Search (⌘F)")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearchField)) { _ in
            expandSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .findNext)) { _ in
            findNext()
        }
        .onReceive(NotificationCenter.default.publisher(for: .findPrevious)) { _ in
            findPrevious()
        }
    }

    private func blockRangeLabel(_ block: UnicodeBlock) -> String {
        String(format: "U+%04X – U+%04X", block.range.lowerBound, block.range.upperBound)
    }

    private func displayTitle(for block: UnicodeBlock?) -> String {
        guard let block else { return "Unicode" }
        let jp = block.localizedName
        if jp == block.name { return block.name }
        return "\(jp) (\(block.name))"
    }

    // MARK: - Scroll & block sync

    private func handleScroll(row: Double) {
        AppPersistence.saveScrollRow(row)
        // The first row whose cell is fully visible at the top drives the
        // displayed block name; `ceil` skips past a partially-clipped top row.
        let fullRow = ceil(row)
        let clamped = max(0.0, min(fullRow, Double(0x10FFFF / 16)))
        let cp = UInt32(clamped) * 16
        visibleTopCP = cp
        // Keep sidebar selection in sync. The selectedBlockID onChange handler
        // sees visibleTopCP is already in the new block and skips re-scrolling.
        if let block = UnicodeBlocks.block(containing: cp),
           selectedBlockID != block.id {
            selectedBlockID = block.id
        }
    }

    private func handleBlockSelectionChanged(_ newValue: UInt32?) {
        AppPersistence.saveBlockID(newValue)
        guard let v = newValue else { return }
        if let cp = searchJumpCP {
            requestScroll(toRow: Double(cp / 16))
            searchJumpCP = nil
        } else if let cp = visibleTopCP,
                  let b = UnicodeBlocks.block(containing: cp),
                  b.id == v {
            // Sidebar sync came from a scroll update — don't scroll back.
        } else {
            requestScroll(toRow: Double(v / 16))
        }
    }

    // MARK: - Search focus

    private func expandSearch() {
        isSearchExpanded = true
        searchShouldFocus = true
    }

    private func collapseSearch() {
        isSearchExpanded = false
        searchShouldFocus = false
    }

    private func handleSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }

        // Pressing Enter a second time with the same query cycles to the next
        // match — convenient for name searches where many glyphs match.
        if query == lastSearchedQuery {
            findNext()
            return
        }
        lastSearchedQuery = query

        // 1. A single Unicode scalar (e.g. "あ", "🎉", or "a") — jump to it.
        //    This beats hex-digit parsing so typing "a" lands on U+0061, not U+000A.
        let scalars = Array(query.unicodeScalars)
        if scalars.count == 1 {
            jump(to: scalars[0].value)
            return
        }

        // 2. "U+XXXX" or bare hex (2–6 digits) → code point.
        if let cp = parseCodePoint(query) {
            jump(to: cp)
            return
        }

        // 3. Name substring search.
        if let match = CharacterNameIndex.shared.firstMatch(for: query) {
            jump(to: match)
        }
    }

    private func findNext() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        let start: UInt32 = selectedScalar.map { $0 < 0x10FFFF ? $0 + 1 : 0 } ?? 0
        let index = CharacterNameIndex.shared
        if let cp = index.firstMatch(for: query, startingAt: start) {
            jump(to: cp)
        } else if let cp = index.firstMatch(for: query, startingAt: 0) {
            // Wrap around to the beginning.
            jump(to: cp)
        }
    }

    private func findPrevious() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        let end: UInt32 = selectedScalar.map { $0 > 0 ? $0 - 1 : 0x10FFFF } ?? 0x10FFFF
        let index = CharacterNameIndex.shared
        if let cp = index.lastMatch(for: query, endingAt: end) {
            jump(to: cp)
        } else if let cp = index.lastMatch(for: query, endingAt: 0x10FFFF) {
            jump(to: cp)
        }
    }

    private func parseCodePoint(_ s: String) -> UInt32? {
        var hex = s.uppercased()
        if hex.hasPrefix("U+") { hex.removeFirst(2) }
        guard hex.count >= 1, hex.count <= 6,
              hex.allSatisfy(\.isHexDigit),
              let cp = UInt32(hex, radix: 16),
              cp <= 0x10FFFF else { return nil }
        return cp
    }

    private func jump(to cp: UInt32) {
        if let block = UnicodeBlocks.block(containing: cp) {
            if selectedBlockID == block.id {
                // Same block — onChange won't fire, so scroll explicitly.
                selectedScalar = cp
                requestScroll(toRow: Double(cp / 16))
            } else {
                searchJumpCP = cp
                selectedBlockID = block.id
                selectedScalar = cp
            }
        }
    }

    /// Sidebar tap — fires on every click, including re-clicking the already-
    /// selected row. For new selections the onChange handler also fires, so
    /// we only need to handle the re-click case here (same block id).
    private func sidebarTapped(_ blockID: UInt32) {
        if selectedBlockID == blockID {
            requestScroll(toRow: Double(blockID / 16))
        } else {
            selectedBlockID = blockID
        }
    }

    private func requestScroll(toRow row: Double) {
        scrollTargetRow = row
        scrollTargetBump &+= 1
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}
