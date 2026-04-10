import Foundation
import SwiftUI
import AppKit

// MARK: - SavedFilter

struct SavedFilter: Codable, Identifiable {
    var id               = UUID()
    var name:            String
    var filterText:      String
    var excludeText:     String
    var isCaseSensitive: Bool
    var useRegex:        Bool
}

// MARK: - Color scheme preference

enum ColorSchemePreference: String, CaseIterable, Identifiable {
    case system = "System"
    case dark   = "Dark"
    case light  = "Light"

    var id: String { rawValue }

    var swiftUIScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark:   return .dark
        case .light:  return .light
        }
    }
}

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {

    // MARK: Tabs
    @Published var tabs:          [LogTabViewModel] = []
    @Published var selectedTabID: UUID?

    // MARK: Saved filters
    @Published var savedFilters: [SavedFilter] = []
    private let savedFiltersKey = "LogSuperToolMacSavedFilters"

    // MARK: Highlight rules
    @Published var highlightRules: [HighlightRule] = []
    private let highlightRulesKey = "LogSuperToolMacHighlightRules"

    func addHighlightRule(_ rule: HighlightRule) {
        highlightRules.append(rule)
        persistHighlightRules()
    }

    func updateHighlightRule(_ rule: HighlightRule) {
        if let idx = highlightRules.firstIndex(where: { $0.id == rule.id }) {
            highlightRules[idx] = rule
            persistHighlightRules()
        }
    }

    func deleteHighlightRule(id: UUID) {
        highlightRules.removeAll { $0.id == id }
        persistHighlightRules()
    }

    func moveHighlightRules(from source: IndexSet, to destination: Int) {
        highlightRules.move(fromOffsets: source, toOffset: destination)
        persistHighlightRules()
    }

    private func persistHighlightRules() {
        if let data = try? JSONEncoder().encode(highlightRules) {
            UserDefaults.standard.set(data, forKey: highlightRulesKey)
        }
    }

    private func loadHighlightRules() {
        guard let data = UserDefaults.standard.data(forKey: highlightRulesKey),
              let rules = try? JSONDecoder().decode([HighlightRule].self, from: data)
        else { return }
        highlightRules = rules
    }

    func saveFilter(_ filter: SavedFilter) {
        savedFilters.removeAll { $0.id == filter.id }
        savedFilters.append(filter)
        persistSavedFilters()
    }

    func deleteFilter(id: UUID) {
        savedFilters.removeAll { $0.id == id }
        persistSavedFilters()
    }

    private func persistSavedFilters() {
        if let data = try? JSONEncoder().encode(savedFilters) {
            UserDefaults.standard.set(data, forKey: savedFiltersKey)
        }
    }

    private func loadSavedFilters() {
        guard let data = UserDefaults.standard.data(forKey: savedFiltersKey),
              let filters = try? JSONDecoder().decode([SavedFilter].self, from: data)
        else { return }
        savedFilters = filters
    }

    // MARK: Recent files
    @Published private(set) var recentFiles: [URL] = []
    private let recentFilesKey = "LogSuperToolMacRecentFiles"
    private let maxRecentFiles = 10

    // MARK: UI state
    @Published var isSidebarVisible:      Bool                  = false
    @Published var colorSchemePreference: ColorSchemePreference = .system
    @Published var logFontName: String  = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular).fontName
    @Published var logFontSize: CGFloat = 11

    var logNSFont: NSFont {
        NSFont(name: logFontName, size: logFontSize)
            ?? NSFont.monospacedSystemFont(ofSize: logFontSize, weight: .regular)
    }

    /// SwiftUI Font derived from logNSFont.
    var logFont: Font { Font(logNSFont) }

    var selectedTab: LogTabViewModel? {
        tabs.first { $0.id == selectedTabID }
    }

    // MARK: - Init

    init() {
        let initial   = LogTabViewModel()
        tabs          = [initial]
        selectedTabID = initial.id
        loadPreferences()
        loadRecentFiles()
        loadSavedFilters()
        loadHighlightRules()
    }

    // MARK: - File Opening

    func openFileDialog() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories    = false
        panel.title                   = "Open Log File"
        panel.prompt                  = "Open"
        // Accept any file type — logs may have unusual extensions
        panel.allowsOtherFileTypes    = true
        panel.treatsFilePackagesAsDirectories = false

        guard panel.runModal() == .OK else { return }
        for url in panel.urls { openFile(url: url) }
    }

    func openFile(url: URL) {
        addToRecentFiles(url)
        // Reuse the active tab if it has no file loaded
        if let empty = tabs.first(where: { $0.fileURL == nil }) {
            selectedTabID = empty.id
            Task { await empty.loadFile(url: url) }
        } else {
            let tab = LogTabViewModel(url: url)
            applyColumnPreferences(to: tab)
            tabs.append(tab)
            selectedTabID = tab.id
            Task { await tab.loadFile(url: url) }
        }
    }

    // MARK: - Recent Files

    func addToRecentFiles(_ url: URL) {
        var recents = recentFiles.filter { $0.path != url.path }
        recents.insert(url, at: 0)
        recentFiles = Array(recents.prefix(maxRecentFiles))
        saveRecentFiles()
    }

    func clearRecentFiles() {
        recentFiles = []
        UserDefaults.standard.removeObject(forKey: recentFilesKey)
    }

    private func saveRecentFiles() {
        let bookmarks = recentFiles.compactMap {
            try? $0.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarks, forKey: recentFilesKey)
    }

    private func loadRecentFiles() {
        guard let stored = UserDefaults.standard.array(forKey: recentFilesKey) as? [Data] else { return }
        recentFiles = stored.compactMap { data in
            var isStale = false
            return try? URL(resolvingBookmarkData: data, options: [],
                            relativeTo: nil, bookmarkDataIsStale: &isStale)
        }.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func addEmptyTab() {
        let tab = LogTabViewModel()
        applyColumnPreferences(to: tab)
        tabs.append(tab)
        selectedTabID = tab.id
    }

    func closeTab(id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[idx].closeFile()

        if tabs.count > 1 {
            tabs.remove(at: idx)
            let newIdx    = min(idx, tabs.count - 1)
            selectedTabID = tabs[newIdx].id
        }
        // Never remove the last tab — just clear it
    }

    func reloadSelectedTab() {
        Task { await selectedTab?.reload() }
    }

    // MARK: - Preferences

    private struct Preferences: Codable {
        var colorScheme:    String  = ColorSchemePreference.system.rawValue
        var showLineNumbers: Bool   = true
        var showSeverity:   Bool    = true
        var showDate:       Bool    = true
        var showTime:       Bool    = true
        var sidebarVisible: Bool    = false
        var logFontName:    String  = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular).fontName
        var logFontSize:    CGFloat = 11
    }

    private let prefsKey = "LogSuperToolMacPreferences"

    func savePreferences() {
        let tab  = selectedTab
        let prefs = Preferences(
            colorScheme:     colorSchemePreference.rawValue,
            showLineNumbers: tab?.showLineNumbers ?? true,
            showSeverity:    tab?.showSeverity    ?? true,
            showDate:        tab?.showDate        ?? true,
            showTime:        tab?.showTime        ?? true,
            sidebarVisible:  isSidebarVisible,
            logFontName:     logFontName,
            logFontSize:     logFontSize
        )
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: prefsKey)
        }
    }

    func loadPreferences() {
        guard let data  = UserDefaults.standard.data(forKey: prefsKey),
              let prefs = try? JSONDecoder().decode(Preferences.self, from: data)
        else { return }

        colorSchemePreference = ColorSchemePreference(rawValue: prefs.colorScheme) ?? .system
        isSidebarVisible      = prefs.sidebarVisible
        logFontName           = prefs.logFontName
        logFontSize           = prefs.logFontSize

        for tab in tabs { applyPrefs(prefs, to: tab) }
    }

    private func applyColumnPreferences(to tab: LogTabViewModel) {
        guard let data  = UserDefaults.standard.data(forKey: prefsKey),
              let prefs = try? JSONDecoder().decode(Preferences.self, from: data)
        else { return }
        applyPrefs(prefs, to: tab)
    }

    private func applyPrefs(_ prefs: Preferences, to tab: LogTabViewModel) {
        tab.showLineNumbers = prefs.showLineNumbers
        tab.showSeverity    = prefs.showSeverity
        tab.showDate        = prefs.showDate
        tab.showTime        = prefs.showTime
    }
}
