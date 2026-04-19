import AppKit
import CoreText

/// Shared CoreText drawing primitive used by `GlyphView` (detail pane) and
/// `GridRowView` (grid cells). Centers the glyph using its typographic bounds
/// (ascent + descent) so each character sits at its natural baseline position.
enum GlyphDrawer {
    /// Draws `codePoint` centered in `rect` within the current `context`.
    /// - Parameter flipped: pass `true` if the caller's NSView has
    ///   `isFlipped == true` (grid rows). CoreText always draws in a y-up
    ///   coordinate space, so the context is temporarily flipped when needed.
    static func draw(
        codePoint: UInt32,
        fontName: String,
        tint: NSColor,
        fontSize: CGFloat,
        in rect: CGRect,
        context: CGContext,
        flipped: Bool
    ) {
        guard let scalar = Unicode.Scalar(codePoint) else { return }

        let font: NSFont = {
            if !fontName.isEmpty, let custom = NSFont(name: fontName, size: fontSize) {
                return custom
            }
            return .systemFont(ofSize: fontSize)
        }()

        let attr = NSAttributedString(
            string: String(scalar),
            attributes: [
                .font: font,
                .foregroundColor: tint.cgColor,
            ]
        )
        let line = CTLineCreateWithAttributedString(attr as CFAttributedString)
        let typo = CTLineGetBoundsWithOptions(line, [])
        guard typo.width > 0 else { return }

        context.saveGState()
        defer { context.restoreGState() }

        let tx = rect.midX - (typo.origin.x + typo.width / 2)
        if flipped {
            context.translateBy(x: 0, y: rect.midY)
            context.scaleBy(x: 1, y: -1)
            let ty = -(typo.origin.y + typo.height / 2)
            context.textPosition = CGPoint(x: tx, y: ty)
        } else {
            let ty = rect.midY - (typo.origin.y + typo.height / 2)
            context.textPosition = CGPoint(x: tx, y: ty)
        }
        CTLineDraw(line, context)
    }
}
