# LogSuperTool — Mac Edition

A fast, native macOS log viewer built with Swift and SwiftUI. Designed for developers and sysadmins who need to quickly open, search, filter, and analyze large log files.

![Platform](https://img.shields.io/badge/platform-macOS-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

### Performance
- **Chunked file reader** — reads and indexes logs progressively, so the interface stays responsive while a file loads
- **Background filtering** — search and filter run off the main thread with 250ms debounce
- **Progressive loading** — first lines appear immediately with a live progress bar

### Viewing
- **Multi-tab** — open multiple log files side by side
- **Auto severity detection** — color-codes ERROR, WARN, INFO, DEBUG, TRACE lines automatically
- **Custom highlight rules** — define your own pattern-based row colors (plain text or regex)
- **Line wrap toggle** — wrap or truncate long lines on demand (`⌘⌥W`)
- **Column visibility** — show/hide Line #, Severity, Date, Time independently
- **Font picker** — choose any system font and size; persisted across sessions

### Search & Filter
- **Search with highlight** — matches highlighted in yellow with next/prev navigation
- **Include filter** — show only lines matching a pattern
- **Exclude filter** — hide lines matching a pattern
- **Regex support** — full NSRegularExpression in search, filter, and exclude fields
- **Case-sensitive toggle**
- **Saved filters** — name and save filter combos, recall them instantly

### Navigation
- **Bookmarks** — mark lines with `bookmark.fill`, navigate with Prev/Next Mark
- **Error navigation** — jump between ERROR/WARN lines (`⌘⌥[` / `⌘⌥]`)
- **Timeline slider** — scrub through timestamped lines by relative position
- **Jump to line / time / date**
- **Tail mode** — monitors the file for new content every 500ms

### File Handling
- **Drag & drop** — drop a log file onto the window to open it
- **Recent files** — Open Recent menu with sandboxed bookmark storage
- **File association** — `.log`, `.out`, `.err`, `.trace`, `.debug` files open in LogSuperTool by default
- **Export** — save visible (filtered) lines as plain text or CSV

### Printing
- **Print button** — renders visible lines to a paginated PDF and opens it in Preview for printing

### UI
- **Status bar** — selected line detail (line #, severity, timestamp, message)
- **Error state** — clear error screen with retry when a file fails to load
- **About window** — standard macOS About panel
- **Preferences (`⌘,`)** — General, Font, Highlights, and Shortcuts tabs
- **Dark/Light/System** appearance preference

---

## Requirements

| Requirement | Version |
|-------------|---------|
| macOS       | 13 Ventura or later |
| Xcode       | 16.0 or later |
| Swift       | 6.0 |

---

## Building

```bash
git clone https://github.com/RDUtilities/LogSuperTool-MacEdition.git
cd LogSuperTool-MacEdition
open LogSuperToolMacEdition.xcodeproj
```

Select the **LogSuperToolMacEdition** scheme and press `⌘R` to build and run.

To build a Release binary from the command line:

```bash
xcodebuild -scheme LogSuperToolMacEdition -configuration Release build
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘ O` | Open file |
| `⌘ T` | New tab |
| `⌘ W` | Close tab |
| `⌘ R` | Reload file |
| `⌘ P` | Print |
| `⌘ F` | Focus search |
| `⌘ ↓` | Next search match |
| `⌘ ↑` | Previous search match |
| `⌘ ⌥ ]` | Next error / warning |
| `⌘ ⌥ [` | Previous error / warning |
| `⌘ ⌥ W` | Toggle line wrap |
| `⌘ ⇧ T` | Open font picker |
| `⌘ ,` | Preferences |

---

## Architecture

```
LogSuperToolMacEdition/
├── LogSuperToolMacEditionApp.swift   # App entry, menu commands, Settings scene
├── AppState.swift                    # Global state: tabs, font, recent files, saved filters, highlight rules
├── Models/
│   ├── LogLine.swift                 # LogLine struct + LogSeverity enum
│   └── HighlightRule.swift           # Custom highlight rule model
├── Services/
│   └── LogFileLoader.swift           # AsyncThrowingStream file reader (8MB chunks)
├── ViewModels/
│   └── LogTabViewModel.swift         # Per-tab state, filter engine, bookmarks, tail
├── Views/
│   ├── ContentView.swift             # Root layout + drag & drop
│   ├── LogTabView.swift              # Per-tab view (loading, error, empty, table)
│   ├── LogTableView.swift            # List + LogRowView
│   ├── ToolbarRow.swift              # File/nav/print actions + font picker
│   ├── SearchFilterBar.swift         # Search, filter, exclude, saved filters
│   ├── StatusBarView.swift           # File path / selected line detail
│   ├── TabBarView.swift              # Tab strip
│   ├── SidebarView.swift             # Help, shortcuts, severity legend
│   ├── TimelineRow.swift             # Timestamp scrubber
│   └── PreferencesView.swift         # ⌘, preferences window
└── Controls/
    └── HighlightedText.swift         # SwiftUI view with inline search highlighting
```

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

*Built with Swift & SwiftUI • Inspired by the Windows C# WPF original*
