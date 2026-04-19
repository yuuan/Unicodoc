import AppKit
import CoreText

/// Ink (visible-drawing) bounds of a glyph at a fixed reference font size,
/// after CoreText's font-substitution chain. Needed because Nerd Fonts often
/// report advance=1em but paint much wider — caller needs the real rect to
/// scale the font and center the drawing.
struct GlyphMetrics {
    static let referenceFontSize: CGFloat = 100

    /// Ink rect measured at `referenceFontSize`. origin.x may be negative for
    /// glyphs that overhang to the left; origin.y is typically negative
    /// (descent below baseline).
    let inkRect: CGRect

    var widthEm: CGFloat {
        inkRect.width / Self.referenceFontSize
    }

    var heightEm: CGFloat {
        inkRect.height / Self.referenceFontSize
    }
}

/// Detects whether a given code point renders as a real glyph (as opposed to the
/// `.notdef` tofu box) under CoreText's full font-substitution chain for `fontName`.
/// Results are memoized per (fontName, codePoint).
final class GlyphAvailability {
    static let shared = GlyphAvailability()
    private init() {}

    private struct Key: Hashable {
        let fontName: String
        let cp: UInt32
    }

    private let queue = DispatchQueue(label: "GlyphAvailability.cache")
    private var cache: [Key: Bool] = [:]
    private var metricsCache: [Key: GlyphMetrics] = [:]

    func hasGlyph(for cp: UInt32, fontName: String) -> Bool {
        let key = Key(fontName: fontName, cp: cp)
        return queue.sync {
            if let cached = cache[key] { return cached }
            let result = compute(cp: cp, fontName: fontName)
            cache[key] = result
            return result
        }
    }

    func metrics(for cp: UInt32, fontName: String) -> GlyphMetrics {
        let key = Key(fontName: fontName, cp: cp)
        return queue.sync {
            if let m = metricsCache[key] { return m }
            let m = computeMetrics(cp: cp, fontName: fontName)
            metricsCache[key] = m
            return m
        }
    }

    private func compute(cp: UInt32, fontName: String) -> Bool {
        guard let scalar = Unicode.Scalar(cp) else { return false }

        let base: NSFont = if !fontName.isEmpty, let f = NSFont(name: fontName, size: NSFont.systemFontSize) {
            f
        } else {
            .systemFont(ofSize: NSFont.systemFontSize)
        }

        let cfString = String(scalar) as CFString
        let length = CFStringGetLength(cfString)
        let substituted = CTFontCreateForString(base as CTFont, cfString, CFRange(location: 0, length: length))
        let psName = CTFontCopyPostScriptName(substituted) as String

        // CoreText returns "LastResort" when no font in the fallback chain has a glyph.
        // The visible result is the tofu "box with script hint" placeholder.
        if psName == "LastResort" || psName == ".LastResort" { return false }
        return true
    }

    private func computeMetrics(cp: UInt32, fontName: String) -> GlyphMetrics {
        let fallback = GlyphMetrics(inkRect: CGRect(
            x: 0, y: 0,
            width: GlyphMetrics.referenceFontSize,
            height: GlyphMetrics.referenceFontSize
        ))
        guard let scalar = Unicode.Scalar(cp) else { return fallback }

        let refSize = GlyphMetrics.referenceFontSize
        let base: NSFont = if !fontName.isEmpty, let f = NSFont(name: fontName, size: refSize) {
            f
        } else {
            .systemFont(ofSize: refSize)
        }
        let attr = NSAttributedString(
            string: String(scalar),
            attributes: [.font: base]
        )
        let line = CTLineCreateWithAttributedString(attr as CFAttributedString)
        let ink = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
        guard ink.width > 0, ink.height > 0 else { return fallback }

        return GlyphMetrics(inkRect: ink)
    }
}
