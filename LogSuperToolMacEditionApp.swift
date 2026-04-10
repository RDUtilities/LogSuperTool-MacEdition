import SwiftUI

@main
struct LogSuperToolMacEditionApp: App {

    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.colorSchemePreference.swiftUIScheme)
                .onOpenURL { url in
                    appState.openFile(url: url)
                }
        }
        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
        .commands {
            // About panel with custom credits
            CommandGroup(replacing: .appInfo) {
                Button("About LogSuperTool") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName:    "LogSuperTool",
                        .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
                        .version:            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
                        .credits: NSAttributedString(
                            string: "A fast, native macOS log viewer.\ngithub.com/RDUtilities/LogSuperTool",
                            attributes: [
                                .font: NSFont.systemFont(ofSize: 11),
                                .foregroundColor: NSColor.secondaryLabelColor
                            ]
                        ),
                        .applicationIcon: NSImage(named: "AppIcon") ?? NSImage()
                    ])
                }
            }

            // File menu additions
            CommandGroup(replacing: .newItem) {
                Button("Open Log File…") {
                    appState.openFileDialog()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("New Tab") {
                    appState.addEmptyTab()
                }
                .keyboardShortcut("t", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Divider()

                // Open Recent submenu
                Menu("Open Recent") {
                    if appState.recentFiles.isEmpty {
                        Text("No Recent Files")
                    } else {
                        ForEach(appState.recentFiles, id: \.path) { url in
                            Button(url.lastPathComponent) {
                                appState.openFile(url: url)
                            }
                        }
                        Divider()
                        Button("Clear Recent Files") {
                            appState.clearRecentFiles()
                        }
                    }
                }

                Divider()

                Button("Reload") {
                    appState.reloadSelectedTab()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(appState.selectedTab?.fileURL == nil)

                Button("Close Tab") {
                    if let id = appState.selectedTabID {
                        appState.closeTab(id: id)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
            }
        }
    }
}
