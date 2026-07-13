import SwiftUI

// MARK: - StatusBarView

struct StatusBarView: View {

    @ObservedObject var viewModel: LogTabViewModel

    var body: some View {
        HStack(spacing: 10) {

            // Selected line detail (left side — replaces file path when a line is selected)
            if let line = viewModel.selectedLine {
                selectedLineDetail(line)
            } else if let url = viewModel.fileURL {
                Image(systemName: "doc.text")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(url.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("No file open")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Search matches
            if viewModel.searchMatchCount > 0 {
                Label("\(viewModel.searchMatchCount) matches",
                      systemImage: "magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.secondary)
                statusDivider()
            }

            // Line count
            if viewModel.visibleLines.count != viewModel.allLines.count {
                Text("\(viewModel.visibleLines.count) / \(viewModel.allLines.count) lines")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("\(viewModel.allLines.count) lines")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Problem count
            if !viewModel.problemLineNumbers.isEmpty {
                statusDivider()
                Label("\(viewModel.problemLineNumbers.count) problems",
                      systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Tail indicator
            if viewModel.isTailing {
                statusDivider()
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("Tailing")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private func selectedLineDetail(_ line: LogLine) -> some View {
        HStack(spacing: 6) {
            // Line number
            Text("L\(line.lineNumber)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)

            // Severity badge (only when meaningful)
            if line.severity != .none {
                Text(line.severity.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(line.severity.labelColor.opacity(0.25))
                    .foregroundColor(line.severity.labelColor)
                    .clipShape(Capsule())
            }

            // Timestamp
            if !line.dateString.isEmpty || !line.timeString.isEmpty {
                statusDivider()
                Text([line.dateString, line.timeString].filter { !$0.isEmpty }.joined(separator: " "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            statusDivider()

            // Text snippet
            Text(line.text.trimmingCharacters(in: .whitespaces))
                .font(.caption)
                .foregroundColor(.primary.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func statusDivider() -> some View {
        Divider().frame(height: 12)
    }
}
