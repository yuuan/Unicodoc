import Foundation

/// Searches Unicode.Scalar.Properties.name for a substring match.
/// Scans on demand — no full index built up front. Fast enough for a synchronous search
/// because the total assigned scalar count is ~155K and property lookup is backed by ICU.
final class CharacterNameIndex {
    static let shared = CharacterNameIndex()
    private init() {}

    func firstMatch(for query: String, startingAt start: UInt32 = 0) -> UInt32? {
        let needle = query.uppercased()
        guard !needle.isEmpty else { return nil }

        for block in UnicodeBlocks.all where block.range.upperBound >= start {
            let lo = max(block.range.lowerBound, start)
            for cp in lo ... block.range.upperBound {
                guard let s = Unicode.Scalar(cp) else { continue }
                if let name = s.properties.name,
                   name.uppercased().contains(needle) {
                    return cp
                }
            }
        }
        return nil
    }

    func lastMatch(for query: String, endingAt end: UInt32 = UInt32.max) -> UInt32? {
        let needle = query.uppercased()
        guard !needle.isEmpty else { return nil }

        for block in UnicodeBlocks.all.reversed() where block.range.lowerBound <= end {
            let hi = min(block.range.upperBound, end)
            var cp = Int(hi)
            let minCp = Int(block.range.lowerBound)
            while cp >= minCp {
                if let s = Unicode.Scalar(UInt32(cp)),
                   let name = s.properties.name,
                   name.uppercased().contains(needle) {
                    return UInt32(cp)
                }
                cp -= 1
            }
        }
        return nil
    }
}
