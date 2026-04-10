import SwiftUI

// MARK: - SearchFilterBar

struct SearchFilterBar: View {

    @ObservedObject var viewModel: LogTabViewModel
    @EnvironmentObject var appState: AppState
    @FocusState private var searchFocused: Bool
    @State private var showSaveAlert   = false
    @State private var newFilterName   = ""

    var body: some View {
        HStack(spacing: 8) {

            // ── Search field ──────────────────────────────────────────────
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)

                TextField("Search…", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 140, maxWidth: 220)
                    .focused($searchFocused)

                if !viewModel.searchText.isEmpty {
                    // Match count badge
                    if viewModel.searchMatchCount > 0 {
                        Text("\(viewModel.searchMatchCount)")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.25))
                            .clipShape(Capsule())
                    }

                    Button { viewModel.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(fieldBackground)
            .cornerRadius(7)

            // Prev / Next search
            Button {
                viewModel.findPrev()
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.searchMatchCount == 0)
            .help("Previous match  ⌘↑")
            .keyboardShortcut(.upArrow, modifiers: .command)

            Button {
                viewModel.findNext()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.searchMatchCount == 0)
            .help("Next match  ⌘↓")
            .keyboardShortcut(.downArrow, modifiers: .command)

            Divider().frame(height: 22)

            // ── Include filter ────────────────────────────────────────────
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundColor(.secondary)
                    .font(.caption)

                TextField("Filter…", text: $viewModel.filterText)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 120, maxWidth: 200)

                if !viewModel.filterText.isEmpty {
                    Button { viewModel.filterText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(fieldBackground)
            .cornerRadius(7)

            // ── Exclude filter ────────────────────────────────────────────
            HStack(spacing: 4) {
                Image(systemName: "minus.circle")
                    .foregroundColor(.red.opacity(0.7))
                    .font(.caption)

                TextField("Exclude…", text: $viewModel.excludeText)
                    .textFieldStyle(.plain)
                    .frame(minWidth: 100, maxWidth: 180)

                if !viewModel.excludeText.isEmpty {
                    Button { viewModel.excludeText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(fieldBackground)
            .cornerRadius(7)

            Divider().frame(height: 22)

            // ── Options ───────────────────────────────────────────────────
            Toggle(isOn: $viewModel.isCaseSensitive) {
                Text("Case Sensitive")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .help("Case sensitive")

            Toggle(isOn: $viewModel.useRegex) {
                Text("Regex")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .help("Regular expressions")

            // ── Saved filters ─────────────────────────────────────────────
            Menu {
                // Apply a saved filter
                if appState.savedFilters.isEmpty {
                    Text("No Saved Filters")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(appState.savedFilters) { filter in
                        Button {
                            viewModel.filterText      = filter.filterText
                            viewModel.excludeText     = filter.excludeText
                            viewModel.isCaseSensitive = filter.isCaseSensitive
                            viewModel.useRegex        = filter.useRegex
                        } label: {
                            Label(filter.name, systemImage: "line.3.horizontal.decrease")
                        }
                    }
                    Divider()
                    // Delete submenu
                    Menu("Delete Saved Filter") {
                        ForEach(appState.savedFilters) { filter in
                            Button(filter.name, role: .destructive) {
                                appState.deleteFilter(id: filter.id)
                            }
                        }
                    }
                    Divider()
                }
                Button {
                    newFilterName = ""
                    showSaveAlert = true
                } label: {
                    Label("Save Current Filter…", systemImage: "plus")
                }
                .disabled(viewModel.filterText.isEmpty && viewModel.excludeText.isEmpty)
            } label: {
                Image(systemName: "bookmark")
                    .foregroundColor(appState.savedFilters.isEmpty ? .secondary : .accentColor)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 22)
            .help("Saved filters")

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .alert("Save Filter", isPresented: $showSaveAlert) {
            TextField("Filter name", text: $newFilterName)
            Button("Save") {
                guard !newFilterName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                appState.saveFilter(SavedFilter(
                    name:            newFilterName,
                    filterText:      viewModel.filterText,
                    excludeText:     viewModel.excludeText,
                    isCaseSensitive: viewModel.isCaseSensitive,
                    useRegex:        viewModel.useRegex
                ))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Name this filter set to recall it later.")
        }
        // ⌘F focuses the search field
        .onReceive(
            NotificationCenter.default.publisher(for: .focusSearchField)
        ) { _ in
            searchFocused = true
        }
    }

    private var fieldBackground: some ShapeStyle {
        Color(NSColor.controlBackgroundColor)
    }
}

// MARK: - Notification for focus

extension Notification.Name {
    static let focusSearchField = Notification.Name("LogSuperTool.FocusSearchField")
}
