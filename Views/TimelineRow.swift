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
                .disabled(viewModel.timestampedLines.isEmpty)
                .onChange(of: sliderValue) { newValue in
                    viewModel.navigateTimeline(newValue)
                }
                .help(viewModel.timestampedLines.isEmpty
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

            // ── Jump to time ──────────────────────────────────────────────
            Text("Time:")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("HH:mm:ss", text: $jumpTime)
                .frame(width: 82)
                .multilineTextAlignment(.center)
                .onSubmit {
                    viewModel.jumpToTime(jumpTime)
                }

            // ── Jump to date ──────────────────────────────────────────────
            Text("Date:")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("yyyy-MM-dd", text: $jumpDate)
                .frame(width: 96)
                .multilineTextAlignment(.center)
                .onSubmit {
                    viewModel.jumpToDate(jumpDate)
                }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private func commitJumpLine() {
        if let n = Int(jumpLine) { viewModel.jumpToLine(n) }
    }
}
