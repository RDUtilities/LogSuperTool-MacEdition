import SwiftUI

// MARK: - TabBarView

struct TabBarView: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(appState.tabs) { tab in
                        TabItemView(tab: tab)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }

            Divider().frame(height: 22)

            // Add-tab button
            Button {
                appState.addEmptyTab()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .help("New Tab")
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - TabItemView

struct TabItemView: View {

    @EnvironmentObject var appState: AppState
    @ObservedObject var tab: LogTabViewModel

    @State private var isRenaming = false
    @State private var renameText = ""

    private var isSelected: Bool { appState.selectedTabID == tab.id }

    var body: some View {
        HStack(spacing: 5) {
            // Loading spinner
            if tab.isLoading {
                ProgressView()
                    .scaleEffect(0.55)
                    .frame(width: 13, height: 13)
            } else {
                // File icon
                Image(systemName: tab.fileURL == nil ? "doc" : "doc.text")
                    .font(.caption)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }

            // Title or rename field
            if isRenaming {
                TextField("", text: $renameText)
                    .frame(width: 130)
                    .textFieldStyle(.plain)
                    .onSubmit      { commitRename() }
                    .onExitCommand { isRenaming = false }
            } else {
                Text(tab.tabTitle)
                    .lineLimit(1)
                    .frame(maxWidth: 160, alignment: .leading)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }

            // Problem badge
            if !tab.problemLineNumbers.isEmpty {
                Text("\(tab.problemLineNumbers.count)")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.red.opacity(0.75))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }

            // Close button
            Button {
                appState.closeTab(id: tab.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isSelected ? 1 : 0.4)
            .help("Close Tab")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tabBackground)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { appState.selectedTabID = tab.id }
        .contextMenu {
            Button("Rename Tab") { beginRename() }
            Divider()
            Button("Reload")     { Task { await tab.reload() } }.disabled(tab.fileURL == nil)
            Divider()
            Button("Close Tab")  { appState.closeTab(id: tab.id) }
        }
    }

    // MARK: Helpers

    private var tabBackground: some View {
        Group {
            if isSelected {
                Color.accentColor.opacity(0.12)
            } else {
                Color(NSColor.windowBackgroundColor)
            }
        }
    }

    private func beginRename() {
        renameText = tab.tabTitle
        isRenaming = true
    }

    private func commitRename() {
        if !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
            tab.tabTitle = renameText
        }
        isRenaming = false
    }
}
