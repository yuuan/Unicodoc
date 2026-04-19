import AppKit
import SwiftUI

final class FontSettings: ObservableObject {
    static let shared = FontSettings()

    private static let fontNameKey = "characterFontName"

    @Published var fontName: String {
        didSet {
            UserDefaults.standard.set(fontName, forKey: Self.fontNameKey)
        }
    }

    private init() {
        self.fontName = UserDefaults.standard.string(forKey: Self.fontNameKey) ?? ""
    }

    func font(size: CGFloat) -> Font {
        if fontName.isEmpty {
            return .system(size: size)
        }
        return .custom(fontName, size: size)
    }

    func nsFont(size: CGFloat) -> NSFont {
        if !fontName.isEmpty, let f = NSFont(name: fontName, size: size) {
            return f
        }
        return .systemFont(ofSize: size)
    }

    var displayName: String {
        if fontName.isEmpty { return "System" }
        return NSFont(name: fontName, size: 14)?.displayName ?? fontName
    }
}

/// Coordinator for NSFontPanel. Must be an NSObject so it can implement
/// `changeFont:` responder-chain action.
final class FontPickerCoordinator: NSObject {
    static let shared = FontPickerCoordinator()

    override private init() {
        super.init()
    }

    func showPanel() {
        let manager = NSFontManager.shared
        manager.target = self
        manager.setSelectedFont(
            FontSettings.shared.nsFont(size: NSFont.systemFontSize),
            isMultiple: false
        )
        manager.orderFrontFontPanel(nil)
    }

    @objc func changeFont(_ sender: Any?) {
        guard let manager = sender as? NSFontManager else { return }
        let current = FontSettings.shared.nsFont(size: NSFont.systemFontSize)
        let new = manager.convert(current)
        FontSettings.shared.fontName = new.fontName
    }

    /// Hide the text-effects / document-color sections: we only care about the family.
    @objc func validModesForFontPanel(_ panel: NSFontPanel) -> UInt {
        NSFontPanel.ModeMask([.collection, .face, .size]).rawValue
    }
}
