import AppKit
import SwiftUI

/// NSTableView subclass that forwards the standard `copy:` responder action
/// to a SwiftUI-side handler so ⌘C (via Edit ▸ Copy) copies the selected
/// character. If the search field has focus, AppKit routes the action to the
/// text field instead, so typing ⌘C in the search box still copies text.
final class CopyableTableView: NSTableView {
    var onCopy: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    @objc func copy(_ sender: Any?) {
        onCopy?()
    }
}

/// NSScrollView + NSTableView wrapper that virtualizes the grid rows. Each row
/// is a single `GridRowView` that draws its 17 cells in one `draw(_:)` pass.
struct GridTableView: NSViewRepresentable {
    @Binding var selected: UInt32?
    /// Row index (possibly fractional) to pin to the top of the viewport.
    /// Fractional values preserve sub-row scroll positions across restarts.
    let scrollTarget: Double?
    /// Bumped by the caller to force a re-scroll even when `scrollTarget`
    /// doesn't change (e.g. re-clicking the already-selected sidebar block).
    let scrollTargetBump: Int
    let cellSize: CGFloat
    let rowHeaderWidth: CGFloat
    let fontName: String
    let onScrollPositionChange: ((Double) -> Void)?

    static let rowCount: Int = (0x10FFFF / 16) + 1

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false

        let table = CopyableTableView()
        let coord = context.coordinator
        table.onCopy = { [weak coord] in
            guard let coord,
                  let cp = coord.parent.selected,
                  let scalar = Unicode.Scalar(cp) else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(String(scalar), forType: .string)
        }
        table.headerView = nil
        table.backgroundColor = .textBackgroundColor
        table.gridStyleMask = []
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.selectionHighlightStyle = .none
        table.usesAlternatingRowBackgroundColors = false
        table.allowsColumnReordering = false
        table.allowsColumnResizing = false
        table.allowsMultipleSelection = false
        table.allowsEmptySelection = true
        table.rowSizeStyle = .custom
        table.style = .plain
        table.rowHeight = cellSize
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("grid"))
        column.resizingMask = .autoresizingMask
        column.minWidth = 200
        table.addTableColumn(column)

        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        context.coordinator.tableView = table

        scroll.documentView = table

        // Report top-visible code point as the user scrolls so it can be persisted.
        scroll.contentView.postsBoundsChangedNotifications = true
        let coordinator = context.coordinator
        coordinator.scrollObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scroll.contentView,
            queue: .main
        ) { [weak coordinator, weak table] _ in
            guard let coordinator, let table else { return }
            let y = table.visibleRect.origin.y
            let rowHeight = coordinator.lastCellSize > 0 ? coordinator.lastCellSize : table.rowHeight
            guard rowHeight > 0 else { return }
            let rowAsDouble = max(0, Double(y / rowHeight))
            if coordinator.lastReportedScrollRow != rowAsDouble {
                coordinator.lastReportedScrollRow = rowAsDouble
                coordinator.parent.onScrollPositionChange?(rowAsDouble)
            }
        }

        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let table = scroll.documentView as? NSTableView else { return }

        let coord = context.coordinator
        let sizeChanged = coord.lastCellSize != cellSize
            || coord.lastRowHeaderWidth != rowHeaderWidth
            || coord.lastFontName != fontName
        let targetChanged = coord.lastScrollTarget != scrollTarget
            || coord.lastScrollTargetBump != scrollTargetBump

        coord.parent = self
        coord.lastCellSize = cellSize
        coord.lastRowHeaderWidth = rowHeaderWidth
        coord.lastFontName = fontName
        coord.lastScrollTarget = scrollTarget
        coord.lastScrollTargetBump = scrollTargetBump

        if sizeChanged {
            table.rowHeight = cellSize
            table.reloadData()
        } else if coord.lastSelected != selected {
            // Redraw only the affected rows (old + new selection).
            var rows = IndexSet()
            if let old = coord.lastSelected { rows.insert(Int(old / 16)) }
            if let new = selected { rows.insert(Int(new / 16)) }
            if !rows.isEmpty {
                table.reloadData(forRowIndexes: rows, columnIndexes: IndexSet(integer: 0))
            }
        }
        coord.lastSelected = selected

        // Re-apply scroll when either the target changes OR the cell size changes
        // (the absolute pixel offset depends on cellSize, so a resize invalidates
        // the previous scroll). First-pass GeometryReader sizes often differ from
        // the final size, so without this the initial restore lands on a stale
        // offset.
        if let target = scrollTarget, targetChanged || sizeChanged {
            let rowHeight = cellSize
            DispatchQueue.main.async { [weak scroll] in
                guard let scroll else { return }
                let y = CGFloat(target) * rowHeight
                let origin = NSPoint(x: 0, y: y)
                scroll.contentView.setBoundsOrigin(origin)
                scroll.reflectScrolledClipView(scroll.contentView)
            }
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: GridTableView
        weak var tableView: NSTableView?
        var scrollObserver: Any?

        var lastCellSize: CGFloat = -1
        var lastRowHeaderWidth: CGFloat = -1
        var lastFontName: String = "<uninitialised>"
        var lastSelected: UInt32?
        var lastScrollTarget: Double?
        var lastScrollTargetBump: Int = .min
        var lastReportedScrollRow: Double?

        init(parent: GridTableView) {
            self.parent = parent
            super.init()
        }

        deinit {
            if let observer = scrollObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            GridTableView.rowCount
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let identifier = NSUserInterfaceItemIdentifier("GridRow")
            let view: GridRowView
            if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? GridRowView {
                view = reused
            } else {
                view = GridRowView()
                view.identifier = identifier
            }
            view.rowStart = UInt32(row) * 16
            view.cellSize = parent.cellSize
            view.rowHeaderWidth = parent.rowHeaderWidth
            view.fontName = parent.fontName
            view.selected = parent.selected
            view.onSelect = { [weak self] cp in
                self?.parent.selected = cp
            }
            view.needsDisplay = true
            return view
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            parent.cellSize
        }

        func selectionShouldChange(in tableView: NSTableView) -> Bool {
            false // row-level selection handled in GridRowView.mouseDown
        }
    }
}
