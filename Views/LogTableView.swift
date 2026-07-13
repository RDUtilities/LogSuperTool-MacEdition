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
                LogRowView(line: line, viewModel: viewModel)
                    .id(line.lineNumber)
                    .listRowBackground(rowBackground(for: line))
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

    private func rowBackground(for line: LogLine) -> some View {
        Group {
            if viewModel.navigationHighlightLines.contains(line.lineNumber) {
                Color.accentColor.opacity(0.38)
            } else if viewModel.searchMatchSet.contains(line.lineNumber) {
                Color.yellow.opacity(0.22)
            } else if let rule = appState.highlightRules.first(where: { $0.matches(line.text) }) {
                rule.color
            } else {
                line.severity.rowBackground
            }
        }
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

struct LogRowView: View {

    let line: LogLine
    @ObservedObject var viewModel: LogTabViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 8) {

            if viewModel.showLineNumbers {
                ZStack(alignment: .leading) {
                    Text("\(line.lineNumber)")
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                    if viewModel.bookmarkedLines.contains(line.lineNumber) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                            .offset(x: -2)
                    }
                }
                .frame(width: 50)
            }

            if viewModel.showSeverity {
                Text(line.severity == .none ? "" : line.severity.rawValue)
                    .frame(width: 48, alignment: .center)
                    .foregroundColor(line.severity.labelColor)
                    .fontWeight(line.severity.isProblem ? .semibold : .regular)
            }

            if viewModel.showDate {
                Text(line.dateString)
                    .frame(width: 88, alignment: .leading)
                    .foregroundColor(.secondary)
            }

            if viewModel.showTime {
                Text(line.timeString)
                    .frame(width: 90, alignment: .leading)
                    .foregroundColor(.secondary)
            }

            HighlightedText(
                text:            line.text,
                highlight:       viewModel.searchText,
                isCaseSensitive: viewModel.isCaseSensitive,
                useRegex:        viewModel.useRegex
            )
            .lineLimit(viewModel.wrapLines ? nil : 1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
        .padding(.vertical, 1)
        .font(appState.logFont)
    }
}
