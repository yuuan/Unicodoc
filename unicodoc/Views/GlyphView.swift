import AppKit
import SwiftUI

/// NSViewRepresentable that renders a single Unicode scalar centered in its
/// bounds via `GlyphDrawer`. Used for the large glyph in the detail pane.
struct GlyphView: NSViewRepresentable {
    let codePoint: UInt32
    let fontName: String
    let cellSize: CGFloat
    let tintColor: NSColor

    func makeNSView(context: Context) -> GlyphRenderView {
        let v = GlyphRenderView()
        v.wantsLayer = true
        return v
    }

    func updateNSView(_ view: GlyphRenderView, context: Context) {
        view.configure(
            codePoint: codePoint,
            fontName: fontName,
            cellSize: cellSize,
            tintColor: tintColor
        )
    }
}

final class GlyphRenderView: NSView {
    private var codePoint: UInt32 = 0
    private var fontName: String = ""
    private var cellSize: CGFloat = 44
    private var tintColor: NSColor = .labelColor

    override var isFlipped: Bool {
        false
    }

    func configure(codePoint: UInt32, fontName: String, cellSize: CGFloat, tintColor: NSColor) {
        let changed = self.codePoint != codePoint
            || self.fontName != fontName
            || self.cellSize != cellSize
            || self.tintColor != tintColor
        if changed {
            self.codePoint = codePoint
            self.fontName = fontName
            self.cellSize = cellSize
            self.tintColor = tintColor
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        GlyphDrawer.draw(
            codePoint: codePoint,
            fontName: fontName,
            tint: tintColor,
            fontSize: cellSize * 0.7,
            in: bounds,
            context: ctx,
            flipped: false
        )
    }
}
