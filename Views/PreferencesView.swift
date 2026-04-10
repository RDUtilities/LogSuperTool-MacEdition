import SwiftUI
import AppKit

// MARK: - PreferencesView

struct PreferencesView: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralPrefsPane()
                .tabItem { Label("General", systemImage: "gearshape") }

            FontPrefsPane()
                .tabItem { Label("Font", systemImage: "textformat") }

            HighlightRulesPane()
                .tabItem { Label("Highlights", systemImage: "paintpalette") }

            ShortcutsPane()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .padding(20)
        .frame(width: 520)
    }
}

// MARK: - General

private struct GeneralPrefsPane: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appState.colorSchemePreference) {
                    ForEach(ColorSchemePreference.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: appState.colorSchemePreference) { _ in appState.savePreferences() }
            } header: {
                Text("Appearance").font(.headline)
            }

            Divider().padding(.vertical, 6)

            Section {
                Toggle("Show Line Numbers", isOn: Binding(
                    get:  { appState.selectedTab?.showLineNumbers ?? true },
                    set:  { v in appState.selectedTab?.showLineNumbers = v; appState.savePreferences() }
                ))
                Toggle("Show Severity", isOn: Binding(
                    get:  { appState.selectedTab?.showSeverity ?? true },
                    set:  { v in appState.selectedTab?.showSeverity = v; appState.savePreferences() }
                ))
                Toggle("Show Date", isOn: Binding(
                    get:  { appState.selectedTab?.showDate ?? true },
                    set:  { v in appState.selectedTab?.showDate = v; appState.savePreferences() }
                ))
                Toggle("Show Time", isOn: Binding(
                    get:  { appState.selectedTab?.showTime ?? true },
                    set:  { v in appState.selectedTab?.showTime = v; appState.savePreferences() }
                ))
            } header: {
                Text("Default Columns").font(.headline)
            }
        }
        .formStyle(.grouped)
        .frame(height: 320)
    }
}

// MARK: - Font

private struct FontPrefsPane: View {

    @EnvironmentObject var appState: AppState
    @State private var searchText = ""

    private var selectedFamily: String {
        NSFont(name: appState.logFontName, size: appState.logFontSize)?.familyName
            ?? appState.logFontName
    }

    private var allFamilies: [String] {
        NSFontManager.shared.availableFontFamilies
    }

    private var filteredFamilies: [String] {
        searchText.isEmpty ? allFamilies
            : allFamilies.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Size
            HStack(spacing: 10) {
                Text("Size:")
                    .frame(width: 36, alignment: .leading)
                Button {
                    appState.logFontSize = max(8, appState.logFontSize - 1)
                    appState.savePreferences()
                } label: { Image(systemName: "minus") }
                .buttonStyle(.bordered)

                Text("\(Int(appState.logFontSize)) pt")
                    .frame(width: 44, alignment: .center)
                    .monospacedDigit()

                Button {
                    appState.logFontSize = min(36, appState.logFontSize + 1)
                    appState.savePreferences()
                } label: { Image(systemName: "plus") }
                .buttonStyle(.bordered)

                Spacer()

                Button("Reset") {
                    appState.logFontName = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular).fontName
                    appState.logFontSize = 11
                    appState.savePreferences()
                }
                .buttonStyle(.bordered)
            }

            // Search
            TextField("Search fonts…", text: $searchText)
                .textFieldStyle(.roundedBorder)

            // Font list
            List(filteredFamilies, id: \.self) { family in
                HStack {
                    Text(family)
                        .font(.custom(family, size: 13))
                    Spacer()
                    if family == selectedFamily {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { selectFamily(family) }
            }
            .listStyle(.bordered)

            // Preview
            Divider()
            Text("The quick brown fox jumps  1234567890")
                .font(appState.logFont)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }
        .frame(height: 380)
    }

    private func selectFamily(_ family: String) {
        let descriptor = NSFontDescriptor(fontAttributes: [.family: family])
        if let font = NSFont(descriptor: descriptor, size: appState.logFontSize) {
            appState.logFontName = font.fontName
            appState.savePreferences()
        }
    }
}

// MARK: - Highlight Rules

private struct HighlightRulesPane: View {

    @EnvironmentObject var appState: AppState
    @State private var selectedRuleID: UUID?
    @State private var pendingRule:    HighlightRule?   // non-nil → sheet is open
    @State private var pendingIsNew:   Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Rule list
            List(selection: $selectedRuleID) {
                ForEach($appState.highlightRules) { $rule in
                    HighlightRuleRow(rule: $rule, onEdit: {
                        pendingRule  = rule
                        pendingIsNew = false
                    }, onDelete: {
                        appState.deleteHighlightRule(id: rule.id)
                    })
                    .tag(rule.id)
                }
                .onMove { appState.moveHighlightRules(from: $0, to: $1) }
            }
            .listStyle(.bordered)
            .frame(minHeight: 200)

            // Toolbar
            HStack {
                Button {
                    let preset = HighlightRule.presetColors[
                        appState.highlightRules.count % HighlightRule.presetColors.count
                    ]
                    pendingRule  = HighlightRule.makeNew(r: preset.r, g: preset.g, b: preset.b)
                    pendingIsNew = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add rule")

                Button {
                    if let id = selectedRuleID { appState.deleteHighlightRule(id: id) }
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedRuleID == nil)
                .help("Remove selected rule")

                Spacer()

                Text("Drag rows to reorder. First matching rule wins.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(height: 360)
        .sheet(item: $pendingRule) { rule in
            HighlightRuleEditor(rule: rule, isNew: pendingIsNew) { saved in
                if pendingIsNew {
                    appState.addHighlightRule(saved)
                } else {
                    appState.updateHighlightRule(saved)
                }
                pendingRule = nil
            } onCancel: {
                pendingRule = nil
            }
        }
    }
}

// MARK: - HighlightRuleRow

private struct HighlightRuleRow: View {
    @Binding var rule: HighlightRule
    @EnvironmentObject var appState: AppState
    var onEdit:   () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Color swatch
            RoundedRectangle(cornerRadius: 4)
                .fill(rule.solidColor)
                .frame(width: 20, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )

            // Enable toggle
            Toggle("", isOn: $rule.isEnabled)
                .labelsHidden()
                .onChange(of: rule.isEnabled) { _ in appState.updateHighlightRule(rule) }

            // Name & pattern
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name.isEmpty ? "(unnamed)" : rule.name)
                    .font(.body)
                    .foregroundColor(rule.isEnabled ? .primary : .secondary)
                Text(rule.pattern.isEmpty ? "no pattern" : rule.pattern)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            // Badges
            if rule.useRegex {
                Text("RE")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.2))
                    .clipShape(Capsule())
            }
            if rule.isCaseSensitive {
                Text("Aa")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }

            Button("Edit") { onEdit() }
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(.vertical, 3)
        .contextMenu {
            Button("Edit Rule")   { onEdit() }
            Divider()
            Button("Delete Rule", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - HighlightRuleEditor (sheet)

private struct HighlightRuleEditor: View {
    @State private var rule:    HighlightRule
    let isNew:    Bool
    let onSave:   (HighlightRule) -> Void
    let onCancel: () -> Void

    @State private var pickerColor: Color

    init(rule: HighlightRule, isNew: Bool,
         onSave: @escaping (HighlightRule) -> Void,
         onCancel: @escaping () -> Void) {
        _rule       = State(initialValue: rule)
        self.isNew  = isNew
        self.onSave = onSave
        self.onCancel = onCancel
        _pickerColor = State(initialValue: rule.solidColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "Add Highlight Rule" : "Edit Highlight Rule")
                .font(.headline)

            Form {
                TextField("Name", text: $rule.name)

                TextField("Pattern", text: $rule.pattern)
                    .font(.system(.body, design: .monospaced))

                Toggle("Regular expression", isOn: $rule.useRegex)
                Toggle("Case sensitive",     isOn: $rule.isCaseSensitive)

                // Color picker + preset swatches
                HStack(spacing: 8) {
                    Text("Color")
                    ColorPicker("", selection: $pickerColor, supportsOpacity: false)
                        .labelsHidden()
                        .onChange(of: pickerColor) { newColor in
                            rule.setColor(newColor)
                        }
                    Spacer()
                    ForEach(HighlightRule.presetColors, id: \.name) { preset in
                        Circle()
                            .fill(Color(red: preset.r, green: preset.g, blue: preset.b))
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
                            .onTapGesture {
                                rule.colorRed   = preset.r
                                rule.colorGreen = preset.g
                                rule.colorBlue  = preset.b
                                pickerColor     = Color(red: preset.r, green: preset.g, blue: preset.b)
                            }
                    }
                }

                // Opacity slider
                HStack {
                    Text("Opacity")
                    Slider(value: $rule.colorAlpha, in: 0.05...0.60)
                    Text("\(Int(rule.colorAlpha * 100))%")
                        .frame(width: 36, alignment: .trailing)
                        .monospacedDigit()
                }

                // Preview
                Group {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(rule.pattern.isEmpty ? "Sample log line — 2026-04-10 12:34:56 INFO app started"
                                              : "Sample log line containing: \(rule.pattern)")
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(rule.color)
                        .cornerRadius(4)
                }
            }
            .formStyle(.grouped)

            // Buttons
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button(isNew ? "Add" : "Save") {
                    guard !rule.pattern.isEmpty else { return }
                    onSave(rule)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(rule.pattern.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

// MARK: - Shortcuts reference

private struct ShortcutsPane: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                shortcutSection("File", items: [
                    ("⌘ O",       "Open log file"),
                    ("⌘ T",       "New tab"),
                    ("⌘ W",       "Close tab"),
                    ("⌘ R",       "Reload file"),
                ])

                Divider()

                shortcutSection("Search & Filter", items: [
                    ("⌘ F",       "Focus search field"),
                    ("⌘ ↓",       "Next search match"),
                    ("⌘ ↑",       "Previous search match"),
                ])

                Divider()

                shortcutSection("Navigation", items: [
                    ("⌘ ⌥ ]",    "Next error / warning"),
                    ("⌘ ⌥ [",    "Previous error / warning"),
                ])

                Divider()

                shortcutSection("Display", items: [
                    ("⌘ ⌥ W",    "Toggle line wrap"),
                    ("⌘ ⇧ T",    "Open font picker"),
                    ("⌘ ,",       "Preferences"),
                ])
            }
            .padding()
        }
        .frame(height: 380)
    }

    private func shortcutSection(_ title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 2)
            ForEach(items, id: \.0) { key, desc in
                HStack(spacing: 12) {
                    Text(key)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                        .frame(width: 80, alignment: .leading)
                    Text(desc)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
