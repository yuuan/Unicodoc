import AppKit
import SwiftUI

struct CharacterDetailView: View {
    @EnvironmentObject private var fontSettings: FontSettings

    let scalar: UInt32?

    var body: some View {
        HStack(spacing: 16) {
            glyphPane
            infoPane
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var glyphPane: some View {
        if let cp = scalar, let s = Unicode.Scalar(cp),
           s.properties.generalCategory != .surrogate {
            GlyphView(
                codePoint: cp,
                fontName: fontSettings.fontName,
                cellSize: 72,
                tintColor: .labelColor
            )
            .frame(width: 72, height: 72)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(Rectangle().strokeBorder(Color(nsColor: .separatorColor)))
            .id(cp)
        } else {
            Rectangle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(Rectangle().strokeBorder(Color(nsColor: .separatorColor)))
                .frame(width: 72, height: 72)
        }
    }

    @ViewBuilder
    private var infoPane: some View {
        if let cp = scalar {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "U+%04X", cp))
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                Text(characterName(cp))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 12) {
                    Text(categoryLabel(cp))
                    if let block = UnicodeBlocks.block(containing: cp) {
                        Text("·")
                        Text(block.name)
                    }
                    Text("·")
                    Text("Font: \(fontSettings.displayName)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        } else {
            Text("No character selected")
                .foregroundStyle(.secondary)
        }
    }

    private func characterName(_ cp: UInt32) -> String {
        guard let s = Unicode.Scalar(cp) else { return "(invalid)" }
        if let name = s.properties.name, !name.isEmpty { return name }
        if s.properties.generalCategory == .unassigned { return "(unassigned)" }
        if s.properties.generalCategory == .privateUse { return "(private use)" }
        if s.properties.generalCategory == .surrogate { return "(surrogate)" }
        if let alias = s.properties.nameAlias, !alias.isEmpty { return alias }
        return "(no name)"
    }

    private func categoryLabel(_ cp: UInt32) -> String {
        guard let s = Unicode.Scalar(cp) else { return "—" }
        return describeCategory(s.properties.generalCategory)
    }

    private func describeCategory(_ cat: Unicode.GeneralCategory) -> String {
        switch cat {
        case .uppercaseLetter: return "Uppercase Letter (Lu)"
        case .lowercaseLetter: return "Lowercase Letter (Ll)"
        case .titlecaseLetter: return "Titlecase Letter (Lt)"
        case .modifierLetter: return "Modifier Letter (Lm)"
        case .otherLetter: return "Other Letter (Lo)"
        case .nonspacingMark: return "Nonspacing Mark (Mn)"
        case .spacingMark: return "Spacing Mark (Mc)"
        case .enclosingMark: return "Enclosing Mark (Me)"
        case .decimalNumber: return "Decimal Number (Nd)"
        case .letterNumber: return "Letter Number (Nl)"
        case .otherNumber: return "Other Number (No)"
        case .connectorPunctuation: return "Connector Punctuation (Pc)"
        case .dashPunctuation: return "Dash Punctuation (Pd)"
        case .openPunctuation: return "Open Punctuation (Ps)"
        case .closePunctuation: return "Close Punctuation (Pe)"
        case .initialPunctuation: return "Initial Punctuation (Pi)"
        case .finalPunctuation: return "Final Punctuation (Pf)"
        case .otherPunctuation: return "Other Punctuation (Po)"
        case .mathSymbol: return "Math Symbol (Sm)"
        case .currencySymbol: return "Currency Symbol (Sc)"
        case .modifierSymbol: return "Modifier Symbol (Sk)"
        case .otherSymbol: return "Other Symbol (So)"
        case .spaceSeparator: return "Space Separator (Zs)"
        case .lineSeparator: return "Line Separator (Zl)"
        case .paragraphSeparator: return "Paragraph Separator (Zp)"
        case .control: return "Control (Cc)"
        case .format: return "Format (Cf)"
        case .surrogate: return "Surrogate (Cs)"
        case .privateUse: return "Private Use (Co)"
        case .unassigned: return "Unassigned (Cn)"
        @unknown default: return "Unknown"
        }
    }
}
