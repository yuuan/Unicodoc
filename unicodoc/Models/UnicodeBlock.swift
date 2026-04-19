import Foundation

struct UnicodeBlock: Identifiable, Hashable {
    let name: String
    let range: ClosedRange<UInt32>

    var id: UInt32 {
        range.lowerBound
    }

    var rowCount: Int {
        Int((range.upperBound - range.lowerBound) / 16) + 1
    }

    /// True for the three Private Use Area blocks. The Unicode gc=Co range
    /// exactly matches these blocks, so a scalar-level check suffices.
    var isPrivateUse: Bool {
        guard let s = Unicode.Scalar(range.lowerBound) else { return false }
        return s.properties.generalCategory == .privateUse
    }
}

extension UnicodeBlocks {
    static func block(containing codePoint: UInt32) -> UnicodeBlock? {
        all.first { $0.range.contains(codePoint) }
    }
}
