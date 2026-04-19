import SwiftUI

@main
struct unicodocApp: App {
    @StateObject private var fontSettings = FontSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(fontSettings)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // Strip default menu items the app doesn't use.
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .help) {}

            // Edit ▸ just the Find family (Cut/Copy/Paste/Select All come from
            // the default .pasteboard group and stay available in the search field).
            CommandGroup(replacing: .textEditing) {
                Button("Find") {
                    NotificationCenter.default.post(name: .focusSearchField, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])
                Button("Find Next") {
                    NotificationCenter.default.post(name: .findNext, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command])
                Button("Find Previous") {
                    NotificationCenter.default.post(name: .findPrevious, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }

            // Format ▸ just our two font actions.
            CommandGroup(replacing: .textFormatting) {
                Button("Show Fonts…") {
                    FontPickerCoordinator.shared.showPanel()
                }
                .keyboardShortcut("t", modifiers: [.command])
                Button("Reset to System Font") {
                    FontSettings.shared.fontName = ""
                }
                .disabled(fontSettings.fontName.isEmpty)
            }
        }
    }
}
