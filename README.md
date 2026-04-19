# Unicodoc

A native macOS app for browsing the entire Unicode character set — one scrollable grid,
all 346 blocks, every code point from U+0000 to U+10FFFF.

## Features

- **Single continuous grid** — no block-switching; all of Unicode in one virtualized
  table (NSTableView-backed), with the row at the top driving the block name shown
  in the toolbar.
- **Sidebar navigation** — every Unicode block listed with Japanese names where a
  translation exists, falling back to the official English name.
- **Favorites** — hover a block to reveal ☆, click to pin it as ★. Favorited blocks
  appear in a pinned section at the top of the sidebar.
- **Accurate glyph rendering** — each cell is drawn via CoreText directly on an NSView,
  so Nerd Font / PUA glyphs with unusual ink vs. advance widths render correctly.
- **Custom font** — `⌘T` opens the standard NSFontPanel; selection persists across
  restarts. Cells that can't render in the chosen font (CoreText falls back to
  `LastResort`) are dimmed.
- **PUA highlighting** — code points in the three Private Use Areas get a subtle
  blue background to visually distinguish font-embedded icons.
- **Search (⌘F)** — type the character directly (`あ`), a code point (`3042` or
  `U+3042`), or a substring of the character's Unicode name. `⌘G` / `⇧⌘G` cycle
  through matches. Pressing Return on the same query also advances.
- **State restoration** — scroll position (sub-row precise), the selected cell,
  the selected block, and the favorites list are all persisted via `UserDefaults`.

## Requirements

- macOS 15 (Sequoia) or later
- Xcode 15 or later for building

## Build & Run

The app ships as a hand-written Xcode project.

```sh
# Open in Xcode and press ⌘R
open unicodoc.xcodeproj

# Or drive the build from the command line via Task (see Taskfile.yml)
task build
task run        # kill → rebuild → launch
task clean
```

If your `xcode-select` points at Command Line Tools rather than Xcode.app, the
Taskfile injects `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` so
`xcodebuild` resolves correctly.

## Lint & Format

```sh
task lint          # SwiftLint
task lint:fix      # SwiftLint auto-correct
task format        # SwiftFormat in-place
task format:check  # SwiftFormat --lint (report only)
```

Configuration lives in `.swiftlint.yml` and `.swiftformat`.

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘F`     | Focus search field |
| `⌘G`     | Find next match |
| `⇧⌘G`   | Find previous match |
| `⌘T`     | Show Fonts panel |

## License

MIT License — see [LICENSE](LICENSE).
