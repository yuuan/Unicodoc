import AppKit
import SwiftUI

/// AppKit `NSSearchField` wrapped for SwiftUI. Gives the native Finder-style
/// magnifying-glass icon and clear button that SwiftUI's `TextField` lacks.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    @Binding var shouldFocus: Bool
    let placeholder: String
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit(_:))
        field.sendsWholeSearchString = true
        field.sendsSearchStringImmediately = false
        field.placeholderString = placeholder
        field.bezelStyle = .roundedBezel
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self

        if field.stringValue != text {
            field.stringValue = text
        }
        if field.placeholderString != placeholder {
            field.placeholderString = placeholder
        }
        if shouldFocus {
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
                shouldFocus = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField

        init(_ parent: SearchField) {
            self.parent = parent
        }

        @objc func submit(_ sender: Any?) {
            parent.onSubmit()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            // If the field is empty when focus moves away, collapse it back
            // to the magnifying-glass icon.
            if parent.text.isEmpty {
                parent.onCancel()
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel()
                return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            default:
                return false
            }
        }
    }
}
