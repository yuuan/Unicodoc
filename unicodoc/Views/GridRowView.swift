import AppKit
import CoreText

/// A single row in the Unicode grid, drawing the row header + 16 glyph cells
/// directly via CoreText. Handles mouse clicks and context menu.
final class GridRowView: NSTableCellView {
    var rowStart: UInt32 = 0
    var cellSize: CGFloat = 44
    var rowHeaderWidth: CGFloat = 44
    var fontName: String = ""
    var selected: UInt32?
    var onSelect: ((UInt32) -> Void)?

    private static let maxCodePoint: UInt32 = 0x10FFFF

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        drawRowHeader(ctx: ctx)

        for col in 0 ..< 16 {
            let cp = rowStart + UInt32(col)
            if cp > Self.maxCodePoint { break }
            let x = rowHeaderWidth + CGFloat(col) * cellSize
            let cellRect = NSRect(x: x, y: 0, width: cellSize, height: cellSize)
            drawCell(ctx: ctx, cp: cp, rect: cellRect)
        }
    }

    // MARK: - Row header

    private func drawRowHeader(ctx: CGContext) {
        let headerRect = NSRect(x: 0, y: 0, width: rowHeaderWidth, height: cellSize)
        NSColor.controlBackgroundColor.setFill()
        headerRect.fill()

        // Divider (draw before text so stroke colors can't leak into text).
        NSColor.separatorColor.setFill()
        NSRect(x: rowHeaderWidth - 1.5, y: 0, width: 1.5, height: cellSize).fill()

        let hex = String(format: "%04X", rowStart)
        let fontSize = max(cellSize * 0.25, 4)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let attr = NSAttributedString(
            string: hex,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.secondaryLabelColor.cgColor,
            ]
        )
        let line = CTLineCreateWithAttributedString(attr as CFAttributedString)
        let typoBounds = CTLineGetBoundsWithOptions(line, [])

        // Right-aligned with trailing padding.
        let padding = cellSize * 0.175
        let textX = rowHeaderWidth - padding - typoBounds.width - typoBounds.origin.x
        let baselineY = (cellSize - typoBounds.height) / 2 - typoBounds.origin.y

        // Flipped view (y grows down) + CoreText (y grows up): flip once around
        // the baseline before drawing.
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.translateBy(x: 0, y: cellSize - baselineY)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = CGPoint(x: textX, y: 0)
        CTLineDraw(line, ctx)
    }

    // MARK: - Cell

    private func drawCell(ctx: CGContext, cp: UInt32, rect: NSRect) {
        let isSelected = (selected == cp)
        let scalar = Unicode.Scalar(cp)
        let category = scalar?.properties.generalCategory
        let isAssigned = category != nil
            && category != .unassigned
            && category != .surrogate
        let isPrivateUse = category == .privateUse

        // Background
        let bg: NSColor = if isSelected {
            NSColor.controlAccentColor.withAlphaComponent(0.25)
        } else if !isAssigned {
            Self.tinted(.separatorColor, multiplier: 0.4)
        } else if isPrivateUse {
            GridRowView.privateUseBackground
        } else {
            .clear
        }
        if bg != .clear {
            bg.setFill()
            rect.fill()
        }

        // Border: stroke inset by half line-width so it draws entirely inside
        // the rect (matching SwiftUI .strokeBorder). Adjacent cells end up
        // back-to-back, yielding ~1pt at shared edges — the same look the
        // SwiftUI cell had.
        Self.tinted(.separatorColor, multiplier: 0.4).setStroke()
        let bz = NSBezierPath(rect: rect.insetBy(dx: 0.25, dy: 0.25))
        bz.lineWidth = 0.5
        bz.stroke()

        // Glyph
        guard isAssigned else { return }
        let tint = glyphTint(for: cp, isPrivateUse: isPrivateUse)
        GlyphDrawer.draw(
            codePoint: cp,
            fontName: fontName,
            tint: tint,
            fontSize: cellSize * 0.7,
            in: rect,
            context: ctx,
            flipped: true
        )
    }

    private func glyphTint(for cp: UInt32, isPrivateUse: Bool) -> NSColor {
        if !GlyphAvailability.shared.hasGlyph(for: cp, fontName: fontName) {
            return .quaternaryLabelColor
        }
        if isPrivateUse { return Self.privateUseForeground }
        return .labelColor
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if let cp = codePoint(atX: p.x) {
            onSelect?(cp)
        }
        // Become first responder so ⌘C on the menu routes to the table's copy:.
        if let table = enclosingTableView {
            window?.makeFirstResponder(table)
        }
    }

    private var enclosingTableView: NSTableView? {
        var v: NSView? = superview
        while let current = v {
            if let t = current as? NSTableView { return t }
            v = current.superview
        }
        return nil
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let p = convert(event.locationInWindow, from: nil)
        guard let cp = codePoint(atX: p.x) else { return nil }
        onSelect?(cp)
        let menu = NSMenu()

        let copy = NSMenuItem(title: "Copy", action: #selector(copyCharacter(_:)), keyEquivalent: "")
        copy.target = self
        copy.representedObject = NSNumber(value: cp)
        if let scalar = Unicode.Scalar(cp) {
            let cat = scalar.properties.generalCategory
            copy.isEnabled = cat != .unassigned && cat != .surrogate
        } else {
            copy.isEnabled = false
        }
        menu.addItem(copy)

        let copyCP = NSMenuItem(title: "Copy Code Point", action: #selector(copyCodePoint(_:)), keyEquivalent: "")
        copyCP.target = self
        copyCP.representedObject = NSNumber(value: cp)
        menu.addItem(copyCP)

        return menu
    }

    private func codePoint(atX x: CGFloat) -> UInt32? {
        guard x >= rowHeaderWidth else { return nil }
        let col = Int((x - rowHeaderWidth) / cellSize)
        guard col >= 0, col < 16 else { return nil }
        let cp = rowStart + UInt32(col)
        return cp <= Self.maxCodePoint ? cp : nil
    }

    @objc private func copyCharacter(_ sender: NSMenuItem) {
        guard let num = sender.representedObject as? NSNumber,
              let s = Unicode.Scalar(num.uint32Value) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(String(s), forType: .string)
    }

    @objc private func copyCodePoint(_ sender: NSMenuItem) {
        guard let num = sender.representedObject as? NSNumber else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(String(format: "U+%04X", num.uint32Value), forType: .string)
    }

    // MARK: - Colors

    /// Returns `color` with its natural alpha multiplied by `multiplier`. Matches
    /// SwiftUI's `Color(nsColor:).opacity(_:)` behavior (multiplicative) rather
    /// than AppKit's `.withAlphaComponent(_:)` (replacement).
    static func tinted(_ color: NSColor, multiplier: CGFloat) -> NSColor {
        let baseAlpha = color.cgColor.alpha
        return color.withAlphaComponent(baseAlpha * multiplier)
    }

    private static let privateUseBackground: NSColor = .init(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        return isDark
            ? NSColor(srgbRed: 0.4, green: 0.7, blue: 1.0, alpha: 0.06)
            : NSColor(srgbRed: 0.2, green: 0.55, blue: 1.0, alpha: 0.06)
    }

    private static let privateUseForeground: NSColor = .init(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
        return isDark
            ? NSColor(srgbRed: 0.48, green: 0.58, blue: 0.92, alpha: 1)
            : NSColor(srgbRed: 0.10, green: 0.15, blue: 0.48, alpha: 1)
    }
}
