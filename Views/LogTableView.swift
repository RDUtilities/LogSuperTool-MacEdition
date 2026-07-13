import SwiftUI
import AppKit

// MARK: - LogTableView

struct LogTableView: View {

    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: LogTabViewModel
    @State private var selectedLines: Set<Int> = []

    var body: some View {
        ScrollViewReader { proxy in
            List(viewModel.visibleLines, id: \.lineNumber, selection: $selectedLines) { line in
                LogRowView(
                    line: line,
                    presentation: rowPresentation(for: line)
                )
                .equatable()
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .onAppear {
                viewModel.scrollToLineRequested = { lineNumber in
                    withAnimation(.none) {
                        proxy.scrollTo(lineNumber, anchor: .center)
                    }
                }
            }
            .onChange(of: selectedLines) { selection in
                viewModel.selectLine(lineNumber: selection.first)
            }
            .contextMenu(forSelectionType: Int.self) { items in
                if !items.isEmpty {
                    Button("Copy Lines") { copyLines(lineNumbers: items) }
                    Button("Copy as CSV") { copyLinesCSV(lineNumbers: items) }
                    Divider()
                    Button("Filter to Selection") { filterToSelection(lineNumbers: items) }
                    Divider()
                    if items.count == 1, let lineNum = items.first {
                        let isBookmarked = viewModel.bookmarkedLines.contains(lineNum)
                        Button(isBookmarked ? "Remove Bookmark" : "Add Bookmark") {
                            viewModel.toggleBookmark(lineNumber: lineNum)
                        }
                    }
                }
            }
        }
    }

    // MARK: Row background

    private func rowPresentation(for line: LogLine) -> LogRowPresentation {
        let background: LogRowBackground
        if viewModel.navigationHighlightLines.contains(line.lineNumber) {
            background = .navigation
        } else if viewModel.searchMatchSet.contains(line.lineNumber) {
            background = .search
        } else if let rule = appState.highlightRules.first(where: { $0.matches(line.text) }) {
            background = .custom(
                red: rule.colorRed, green: rule.colorGreen, blue: rule.colorBlue, alpha: rule.colorAlpha
            )
        } else {
            background = .severity(line.severity)
        }
        return LogRowPresentation(
            background: background,
            isBookmarked: viewModel.bookmarkedLines.contains(line.lineNumber),
            searchHighlight: viewModel.searchMatchSet.contains(line.lineNumber) ? viewModel.searchText : "",
            isCaseSensitive: viewModel.isCaseSensitive,
            useRegex: viewModel.useRegex,
            showLineNumbers: viewModel.showLineNumbers,
            showSeverity: viewModel.showSeverity,
            showDate: viewModel.showDate,
            showTime: viewModel.showTime,
            wrapLines: viewModel.wrapLines,
            fontName: appState.logFontName,
            fontSize: appState.logFontSize
        )
    }

    // MARK: Context menu actions

    private func copyLines(lineNumbers: Set<Int>) {
        let text = viewModel.visibleLines
            .filter { lineNumbers.contains($0.lineNumber) }
            .sorted { $0.lineNumber < $1.lineNumber }
            .map    { $0.text }
            .joined(separator: "\n")
        setPasteboard(text)
    }

    private func copyLinesCSV(lineNumbers: Set<Int>) {
        var rows = ["Line,Severity,Date,Time,Message"]
        viewModel.visibleLines
            .filter { lineNumbers.contains($0.lineNumber) }
            .sorted { $0.lineNumber < $1.lineNumber }
            .forEach { line in
                rows.append("\(line.lineNumber),\(LogLine.csvField(line.severity.rawValue)),"
                           + "\(LogLine.csvField(line.dateString)),\(LogLine.csvField(line.timeString)),\(LogLine.csvField(line.text))")
            }
        setPasteboard(rows.joined(separator: "\n"))
    }

    private func filterToSelection(lineNumbers: Set<Int>) {
        let texts = viewModel.visibleLines
            .filter { lineNumbers.contains($0.lineNumber) }
            .map    { $0.text }
        if let first = texts.first {
            viewModel.filterText = first
        }
    }

    private func setPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

// MARK: - LogRowView

private enum LogRowBackground: Equatable {
    case navigation
    case search
    case custom(red: Double, green: Double, blue: Double, alpha: Double)
    case severity(LogSeverity)

    var color: Color {
        switch self {
        case .navigation:
            return Color.accentColor.opacity(0.38)
        case .search:
            return Color.yellow.opacity(0.22)
        case let .custom(red, green, blue, alpha):
            return Color(red: red, green: green, blue: blue, opacity: alpha)
        case let .severity(severity):
            return severity.rowBackground
        }
    }
}

private struct LogRowPresentation: Equatable {
    let background: LogRowBackground
    let isBookmarked: Bool
    let searchHighlight: String
    let isCaseSensitive: Bool
    let useRegex: Bool
    let showLineNumbers: Bool
    let showSeverity: Bool
    let showDate: Bool
    let showTime: Bool
    let wrapLines: Bool
    let fontName: String
    let fontSize: CGFloat
}

private struct LogRowView: View, Equatable {

    let line: LogLine
    let presentation: LogRowPresentation

    static func == (lhs: LogRowView, rhs: LogRowView) -> Bool {
        lhs.line.lineNumber == rhs.line.lineNumber && lhs.presentation == rhs.presentation
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {

            if presentation.showLineNumbers {
                ZStack(alignment: .leading) {
                    Text("\(line.lineNumber)")
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                    if presentation.isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                            .offset(x: -2)
                    }
                }
                .frame(width: 50)
            }

            if presentation.showSeverity {
                Text(line.severity == .none ? "" : line.severity.rawValue)
                    .frame(width: 48, alignment: .center)
                    .foregroundColor(line.severity.labelColor)
                    .fontWeight(line.severity.isProblem ? .semibold : .regular)
            }

            if presentation.showDate {
                Text(line.dateString)
                    .frame(width: 88, alignment: .leading)
                    .foregroundColor(.secondary)
            }

            if presentation.showTime {
                Text(line.timeString)
                    .frame(width: 90, alignment: .leading)
                    .foregroundColor(.secondary)
            }

            HighlightedText(
                text:            line.text,
                highlight:       presentation.searchHighlight,
                isCaseSensitive: presentation.isCaseSensitive,
                useRegex:        presentation.useRegex
            )
            .lineLimit(presentation.wrapLines ? nil : 1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .padding(.vertical, 1)
        .font(Font(NSFont(name: presentation.fontName, size: presentation.fontSize)
                   ?? NSFont.monospacedSystemFont(ofSize: presentation.fontSize, weight: .regular)))
        .listRowBackground(presentation.background.color)
    }
}
