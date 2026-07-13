import SwiftUI

// MARK: - TimelineRow

struct TimelineRow: View {

    @ObservedObject var viewModel: LogTabViewModel

    @State private var sliderValue:  Double = 0
    @State private var jumpLine:     String = ""
    @State private var jumpTime:     String = ""
    @State private var jumpDate:     String = ""

    var body: some View {
        HStack(spacing: 10) {

            // ── Timeline slider ───────────────────────────────────────────
            Text("Timeline:")
                .font(.caption)
                .foregroundColor(.secondary)

            Slider(value: $sliderValue, in: 0...1)
                .frame(minWidth: 120, maxWidth: 260)
                .disabled(viewModel.timestampedLineNumbers.isEmpty)
                .onChange(of: sliderValue) { newValue in
                    viewModel.navigateTimeline(newValue)
                }
                .help(viewModel.timestampedLineNumbers.isEmpty
                      ? "No timestamps detected in this file"
                      : "Drag to navigate by time")

            Divider().frame(height: 20)

            // ── Jump to line ──────────────────────────────────────────────
            Text("Go to line:")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Line #", text: $jumpLine)
                .frame(width: 68)
                .multilineTextAlignment(.center)
                .onSubmit { commitJumpLine() }
            Button("Go") { commitJumpLine() }
                .controlSize(.small)
                .disabled(Int(jumpLine.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
                .help("Go to the requested line")

            // ── Jump to time ──────────────────────────────────────────────
            Text("Time:")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("HH:mm:ss", text: $jumpTime)
                .frame(width: 82)
                .multilineTextAlignment(.center)
                .onSubmit { commitJumpTime() }
            Button("Go") { commitJumpTime() }
                .controlSize(.small)
                .disabled(jumpTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Go to the first matching time")

            // ── Jump to date ──────────────────────────────────────────────
            Text("Date:")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("yyyy-MM-dd", text: $jumpDate)
                .frame(width: 96)
                .multilineTextAlignment(.center)
                .onSubmit { commitJumpDate() }
            Button("Go") { commitJumpDate() }
                .controlSize(.small)
                .disabled(jumpDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Go to the first matching date")

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private func commitJumpLine() {
        if let n = Int(jumpLine.trimmingCharacters(in: .whitespacesAndNewlines)) {
            viewModel.jumpToLine(n)
        }
    }

    private func commitJumpTime() {
        viewModel.jumpToTime(jumpTime)
    }

    private func commitJumpDate() {
        viewModel.jumpToDate(jumpDate)
    }
}
