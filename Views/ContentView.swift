import SwiftUI
import UniformTypeIdentifiers

// MARK: - ContentView (root window)

struct ContentView: View {

    @EnvironmentObject var appState: AppState
    @State private var isDragTargeted = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                TabBarView()
                Divider()

                if let tab = appState.selectedTab {
                    HStack(spacing: 0) {
                        LogTabView(viewModel: tab)
                        if appState.isSidebarVisible {
                            Divider()
                            SidebarView()
                                .frame(width: 290)
                        }
                    }
                } else {
                    emptyState
                }
            }

            // Drop overlay
            if isDragTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .background(Color.accentColor.opacity(0.08).cornerRadius(12))
                    .overlay(
                        VStack(spacing: 10) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 48))
                            Text("Drop to Open")
                                .font(.title2.bold())
                        }
                        .foregroundColor(.accentColor)
                    )
                    .padding(16)
                    .allowsHitTesting(false)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onDrop(of: [UTType.fileURL], isTargeted: $isDragTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        DispatchQueue.main.async { appState.openFile(url: url) }
                    }
                }
            }
            return true
        }
        .onDisappear {
            appState.savePreferences()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image("LogSuperToolLogo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 360)
                .opacity(0.88)
            Text("Open a log file or drop one here")
                .font(.title2)
                .foregroundColor(.secondary)
            Button("Open File…") { appState.openFileDialog() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("o", modifiers: .command)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
