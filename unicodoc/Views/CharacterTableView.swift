import SwiftUI

struct CharacterTableView: View {
    @EnvironmentObject private var fontSettings: FontSettings
    @Binding var selected: UInt32?
    let scrollTarget: Double?
    let scrollTargetBump: Int
    let onScrollPositionChange: ((Double) -> Void)?

    private let minCellSize: CGFloat = 28
    private let rowHeaderRatio: CGFloat = 1.15

    var body: some View {
        GeometryReader { geo in
            let metrics = tableMetrics(for: geo.size.width)
            VStack(spacing: 0) {
                headerRow(metrics: metrics)
                Divider()
                GridTableView(
                    selected: $selected,
                    scrollTarget: scrollTarget,
                    scrollTargetBump: scrollTargetBump,
                    cellSize: metrics.cellSize,
                    rowHeaderWidth: metrics.rowHeaderWidth,
                    fontName: fontSettings.fontName,
                    onScrollPositionChange: onScrollPositionChange
                )
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private struct TableMetrics {
        let cellSize: CGFloat
        let rowHeaderWidth: CGFloat
        var totalWidth: CGFloat {
            rowHeaderWidth + cellSize * 16
        }
    }

    private func tableMetrics(for width: CGFloat) -> TableMetrics {
        let denominator = 16 + rowHeaderRatio
        let fitted = width / denominator
        let cell = max(minCellSize, fitted)
        return TableMetrics(cellSize: cell, rowHeaderWidth: cell * rowHeaderRatio)
    }

    private func headerRow(metrics: TableMetrics) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: metrics.rowHeaderWidth, height: metrics.cellSize * 0.6)
                .overlay(alignment: .trailing) { rowHeaderDivider }
            ForEach(0 ..< 16, id: \.self) { col in
                Text(String(format: "%X", col))
                    .font(.system(size: metrics.cellSize * 0.25, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: metrics.cellSize, height: metrics.cellSize * 0.6)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var rowHeaderDivider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1.5)
    }
}
