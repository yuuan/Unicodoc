import Foundation

/// UserDefaults-backed persistence for everything the app restores on launch:
/// selected sidebar block, selected scalar, scroll position, favorites.
enum AppPersistence {
    private enum Key {
        static let scrollRow = "savedScrollRow"
        static let blockID = "savedBlockID"
        static let selectedScalar = "savedSelectedScalar"
        static let favorites = "favoriteBlockIDs"
    }

    // MARK: - Block ID

    static func loadBlockID() -> UInt32? {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Key.blockID) != nil {
            let v = defaults.integer(forKey: Key.blockID)
            if v >= 0 { return UInt32(v) }
        }
        return UnicodeBlocks.all.first?.id
    }

    static func saveBlockID(_ value: UInt32?) {
        if let v = value {
            UserDefaults.standard.set(Int(v), forKey: Key.blockID)
        } else {
            UserDefaults.standard.removeObject(forKey: Key.blockID)
        }
    }

    // MARK: - Selected scalar

    static func loadSelectedScalar() -> UInt32? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Key.selectedScalar) != nil else { return nil }
        let v = defaults.integer(forKey: Key.selectedScalar)
        return (v >= 0 && v <= 0x10FFFF) ? UInt32(v) : nil
    }

    static func saveSelectedScalar(_ value: UInt32?) {
        if let v = value {
            UserDefaults.standard.set(Int(v), forKey: Key.selectedScalar)
        } else {
            UserDefaults.standard.removeObject(forKey: Key.selectedScalar)
        }
    }

    // MARK: - Scroll row

    static func loadScrollRow() -> Double? {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Key.scrollRow) != nil {
            let row = defaults.double(forKey: Key.scrollRow)
            if row >= 0 { return row }
        }
        return UnicodeBlocks.all.first.map { Double($0.range.lowerBound / 16) }
    }

    static func saveScrollRow(_ value: Double) {
        UserDefaults.standard.set(value, forKey: Key.scrollRow)
    }

    // MARK: - Favorites

    static func loadFavorites() -> Set<UInt32> {
        guard let array = UserDefaults.standard.array(forKey: Key.favorites) as? [Int] else {
            return []
        }
        return Set(array.compactMap { ($0 >= 0 && $0 <= 0x10FFFF) ? UInt32($0) : nil })
    }

    static func saveFavorites(_ value: Set<UInt32>) {
        UserDefaults.standard.set(value.sorted().map { Int($0) }, forKey: Key.favorites)
    }
}
