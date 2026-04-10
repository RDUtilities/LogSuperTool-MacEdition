import SwiftUI
import UniformTypeIdentifiers

// MARK: - EmptyTabView

private struct EmptyTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var isDragTargeted = false

    var body: some View {
        VStack(spacing: 18) {
            Image("LogSuperToolLogo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 360)
                .opacity(isDragTargeted ? 0.5 : 0.88)
            Text(isDragTargeted ? "Drop to Open" : "Open a log file to get started")
                .font(.title2)
                .foregroundColor(isDragTargeted ? .accentColor : .secondary)
            Button("Open File…") { appState.openFileDialog() }
                .buttonStyle(.borderedProminent)
        }
        .animation(.easeInOut(duration: 0.15), value: isDragTargeted)
        .onDrop(of: [UTType.fileURL], isTargeted: $isDragTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        DispatchQueue.main.async { appState.openFile(url: url) }
                    }
                }
            }
            return true
        }
    }
}

// MARK: - LogTabView

/// The full content area for one open log file tab.
struct LogTabView: View {

    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: LogTabViewModel

    var body: some View {
        VStack(spacing: 0) {
            ToolbarRow(viewModel: viewModel)
            Divider()
            SearchFilterBar(viewModel: viewModel)
            Divider()
            TimelineRow(viewModel: viewModel)
            Divider()
            bodyContent
            Divider()
            StatusBarView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        if viewModel.isLoading {
            VStack(spacing: 14) {
                if viewModel.loadProgress > 0 {
                    ProgressView(value: viewModel.loadProgress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 320)
                } else {
                    ProgressView()
                }
                Text("Loading \(viewModel.tabTitle)… \(viewModel.allLines.count.formatted()) lines")
                    .foregroundColor(.secondary)
                    .font(.callout)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else if let errorMsg = viewModel.loadError {
            // File load failed
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red.opacity(0.8))
                Text("Failed to open file")
                    .font(.title2)
                    .foregroundColor(.primary)
                Text(errorMsg)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                HStack(spacing: 12) {
                    Button("Try Again") {
                        Task { await viewModel.reload() }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Open Different File…") {
                        appState.openFileDialog()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else if viewModel.fileURL == nil {
            // Empty / welcome state — also accepts drops
            EmptyTabView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else if viewModel.visibleLines.isEmpty {
            Text("No lines match the current filter")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else {
            LogTableView(viewModel: viewModel)
        }
    }
}
