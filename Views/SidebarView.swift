import SwiftUI

// MARK: - SidebarView

struct SidebarView: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Header ────────────────────────────────────────────────
                HStack(alignment: .top) {
                    Image("LogSuperToolLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 180)
                    Spacer()
                    Button {
                        withAnimation { appState.isSidebarVisible = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text("Help & Settings")
                    .font(.headline)

                Divider()

                // ── Appearance ────────────────────────────────────────────
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Appearance")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Picker("Theme", selection: $appState.colorSchemePreference) {
                            ForEach(ColorSchemePreference.allCases) { pref in
                                Text(pref.rawValue).tag(pref)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: appState.colorSchemePreference) { _ in
                            appState.savePreferences()
                        }
                    }
                    .padding(.vertical, 4)
                }

                // ── Keyboard Shortcuts ────────────────────────────────────
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Keyboard Shortcuts")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.bottom, 2)

                        shortcutRow("⌘ O",        "Open file")
                        shortcutRow("⌘ R",        "Reload")
                        shortcutRow("⌘ W",        "Close tab")
                        shortcutRow("⌘ T",        "New tab")
                        shortcutRow("⌘ P",        "Print")
                        shortcutRow("⌘ F",        "Focus search")
                        shortcutRow("⌘ ↓",        "Next match")
                        shortcutRow("⌘ ↑",        "Previous match")
                        shortcutRow("⌘ ⌥ ]",     "Next error")
                        shortcutRow("⌘ ⌥ [",     "Previous error")
                        shortcutRow("⌘ ⌥ W",     "Toggle line wrap")
                    }
                    .padding(.vertical, 4)
                }

                // ── Navigation Tips ───────────────────────────────────────
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Navigation Tips")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.bottom, 2)

                        tip("Drag & drop log files onto the window to open them.")
                        tip("Use the Timeline slider to jump to a relative position in time.")
                        tip("'Only Errors' shows just Error and Warning lines.")
                        tip("Tail mode monitors the file for new content in real time.")
                        tip("Right-click rows to copy, filter, or add a bookmark.")
                        tip("Tab badge shows the number of errors & warnings found.")
                        tip("Regex is supported in Search, Filter, and Exclude fields.")
                        tip("Custom highlight rules can be set in Preferences › Highlights.")
                        tip("Saved filters let you recall common filter combos instantly.")
                    }
                    .padding(.vertical, 4)
                }

                // ── Severity Legend ───────────────────────────────────────
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Severity Colors")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.bottom, 2)

                        legendRow(.error, "fatal / exception / error / failed")
                        legendRow(.warn,  "warn / timeout")
                        legendRow(.info,  "info")
                        legendRow(.debug, "debug")
                        legendRow(.trace, "trace")
                    }
                    .padding(.vertical, 4)
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Sub-views

    private func shortcutRow(_ keys: String, _ description: String) -> some View {
        HStack(spacing: 8) {
            Text(keys)
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
                .frame(width: 72, alignment: .leading)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text("•").font(.caption).foregroundColor(.secondary)
            Text(text).font(.caption).foregroundColor(.secondary)
        }
    }

    private func legendRow(_ severity: LogSeverity, _ keywords: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(severity.rowBackground)
                .frame(width: 14, height: 14)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(severity.labelColor.opacity(0.5), lineWidth: 1))
            Text(severity.rawValue)
                .font(.caption)
                .foregroundColor(severity.labelColor)
                .frame(width: 42, alignment: .leading)
            Text(keywords)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
