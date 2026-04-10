import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - ToolbarRow

struct ToolbarRow: View {

    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: LogTabViewModel

    @State private var showExportSheet  = false
    @State private var showExportFormat = false
    @State private var showFontPicker   = false

    var body: some View {
        HStack(spacing: 6) {
            // ── File actions ─────────────────────────────────────────────
            Group {
                toolbarButton("Open", systemImage: "folder.badge.plus") {
                    appState.openFileDialog()
                }
                .keyboardShortcut("o", modifiers: .command)

                toolbarButton("Reload", systemImage: "arrow.clockwise") {
                    Task { await viewModel.reload() }
                }
                .disabled(viewModel.fileURL == nil)
                .keyboardShortcut("r", modifiers: .command)

                toolbarButton("Close", systemImage: "xmark.circle") {
                    viewModel.closeFile()
                }
                .disabled(viewModel.fileURL == nil)

                toolbarButton("Export", systemImage: "square.and.arrow.up") {
                    showExportFormat = true
                }
                .disabled(viewModel.visibleLines.isEmpty)
                .confirmationDialog("Export visible lines as…",
                                    isPresented: $showExportFormat,
                                    titleVisibility: .visible) {
                    Button("Plain Text (.log)") { exportAs(.plainText) }
                    Button("CSV (.csv)")        { exportAs(.commaSeparatedText) }
                }

                toolbarButton("Print", systemImage: "printer") {
                    printLog()
                }
                .disabled(viewModel.visibleLines.isEmpty)
            }

            divider()

            // ── Problem navigation ────────────────────────────────────────
            Group {
                toolbarButton("Prev Err", systemImage: "chevron.up.circle") {
                    viewModel.prevError()
                }
                .disabled(viewModel.problemLines.isEmpty)
                .keyboardShortcut("[", modifiers: [.command, .option])

                toolbarButton("Next Err", systemImage: "chevron.down.circle") {
                    viewModel.nextError()
                }
                .disabled(viewModel.problemLines.isEmpty)
                .keyboardShortcut("]", modifiers: [.command, .option])
            }

            divider()

            // ── Bookmark navigation ───────────────────────────────────────
            Group {
                toolbarButton("Prev Mark", systemImage: "bookmark.fill") {
                    viewModel.prevBookmark()
                }
                .disabled(viewModel.bookmarkedLines.isEmpty)
                .help("Previous bookmark")

                toolbarButton("Next Mark", systemImage: "bookmark") {
                    viewModel.nextBookmark()
                }
                .disabled(viewModel.bookmarkedLines.isEmpty)
                .help("Next bookmark")
            }

            divider()

            // ── Tail / AutoScroll / Only Errors ───────────────────────────
            Toggle(isOn: $viewModel.isTailing) {
                Label("Tail", systemImage: "eye")
            }
            .toggleStyle(.checkbox)
            .disabled(viewModel.fileURL == nil)
            .help("Monitor file for new content")

            Toggle(isOn: $viewModel.autoScroll) {
                Text("Auto Scroll")
            }
            .toggleStyle(.checkbox)
            .disabled(!viewModel.isTailing)
            .help("Scroll to new lines automatically")

            Toggle(isOn: $viewModel.onlyErrors) {
                Text("Only Errors")
            }
            .toggleStyle(.checkbox)
            .help("Show only Error and Warning lines")

            Spacer()

            // ── Column visibility ─────────────────────────────────────────
            Menu {
                Toggle("Line #",   isOn: $viewModel.showLineNumbers)
                Toggle("Severity", isOn: $viewModel.showSeverity)
                Toggle("Date",     isOn: $viewModel.showDate)
                Toggle("Time",     isOn: $viewModel.showTime)
            } label: {
                Label("Columns", systemImage: "list.bullet.indent")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
            .help("Toggle columns")
            .onChange(of: viewModel.showLineNumbers) { _ in appState.savePreferences() }
            .onChange(of: viewModel.showSeverity)    { _ in appState.savePreferences() }
            .onChange(of: viewModel.showDate)        { _ in appState.savePreferences() }
            .onChange(of: viewModel.showTime)        { _ in appState.savePreferences() }

            // ── Line wrap ─────────────────────────────────────────────────
            Button {
                viewModel.wrapLines.toggle()
            } label: {
                Image(systemName: viewModel.wrapLines ? "text.word.spacing" : "text.alignleft")
            }
            .buttonStyle(.bordered)
            .help(viewModel.wrapLines ? "Wrap lines: On" : "Wrap lines: Off")
            .keyboardShortcut("w", modifiers: [.command, .option])

            divider()

            // ── Font picker ───────────────────────────────────────────────
            Button {
                showFontPicker = true
            } label: {
                Label("Font", systemImage: "textformat")
            }
            .buttonStyle(.bordered)
            .help("Choose font and size  ⌘⇧T")
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .popover(isPresented: $showFontPicker, arrowEdge: .bottom) {
                FontPickerView()
                    .environmentObject(appState)
            }

            divider()

            // ── Sidebar toggle ────────────────────────────────────────────
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    appState.isSidebarVisible.toggle()
                    appState.savePreferences()
                }
            } label: {
                Image(systemName: appState.isSidebarVisible
                      ? "sidebar.right"
                      : "sidebar.right")
                    .symbolVariant(appState.isSidebarVisible ? .fill : .none)
            }
            .buttonStyle(.bordered)
            .help("Toggle Help & Settings sidebar")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: Helpers

    @ViewBuilder
    private func toolbarButton(_ label: String,
                                systemImage: String,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
        .help(label)
    }

    private func divider() -> some View {
        Divider().frame(height: 22)
    }

    // MARK: Export

    private func exportAs(_ type: UTType) {

        let content  = type == .commaSeparatedText ? viewModel.exportCSV() : viewModel.exportText()
        let ext      = type == .commaSeparatedText ? "csv" : "log"
        let baseName = viewModel.fileURL?.deletingPathExtension().lastPathComponent ?? "export"

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(baseName).\(ext)"
        panel.allowedContentTypes  = [type]
        panel.title                = "Export Log View"

        guard panel.runModal() == .OK, let dest = panel.url else { return }
        try? content.write(to: dest, atomically: true, encoding: .utf8)
    }

    private func printLog() {
        let printFont = NSFont(name: appState.logFontName, size: max(9, appState.logFontSize - 1))
                     ?? NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)

        // Build print content respecting column visibility
        let text = viewModel.visibleLines.map { line -> String in
            var parts: [String] = []
            if viewModel.showLineNumbers {
                parts.append(String(format: "%5d", line.lineNumber))
            }
            if viewModel.showSeverity {
                let sev = line.severity == .none ? "" : line.severity.rawValue
                parts.append(sev.padding(toLength: 6, withPad: " ", startingAt: 0))
            }
            if viewModel.showDate && !line.dateString.isEmpty { parts.append(line.dateString) }
            if viewModel.showTime && !line.timeString.isEmpty { parts.append(line.timeString) }
            parts.append(line.text)
            return parts.joined(separator: "  ")
        }.joined(separator: "\n")

        // US Letter in points (72 pt = 1 inch)
        let pageW: CGFloat  = 612
        let pageH: CGFloat  = 792
        let margin: CGFloat = 36
        let contentRect = CGRect(x: margin, y: margin,
                                 width:  pageW - margin * 2,
                                 height: pageH - margin * 2)

        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineSpacing = 1
        let attrStr = NSAttributedString(string: text, attributes: [
            .font:            printFont,
            .foregroundColor: NSColor.black,
            .paragraphStyle:  paraStyle
        ])

        // Write a multi-page PDF to a temp file using Core Text
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LogSuperTool_\(Int(Date().timeIntervalSince1970)).pdf")

        var mediaBox = CGRect(origin: .zero, size: CGSize(width: pageW, height: pageH))
        guard let pdfCtx = CGContext(tmpURL as CFURL, mediaBox: &mediaBox, nil) else { return }

        let framesetter = CTFramesetterCreateWithAttributedString(attrStr as CFAttributedString)
        let totalLen    = attrStr.length
        var charOffset  = 0

        while charOffset < totalLen {
            pdfCtx.beginPDFPage(nil)

            let path  = CGPath(rect: contentRect, transform: nil)
            let frame = CTFramesetterCreateFrame(
                framesetter, CFRangeMake(charOffset, 0), path, nil)
            CTFrameDraw(frame, pdfCtx)

            let visible = CTFrameGetVisibleStringRange(frame)
            pdfCtx.endPDFPage()

            if visible.length == 0 { break }       // safety: nothing fit
            charOffset += visible.length
        }

        pdfCtx.closePDF()

        // Open in Preview so the user gets a full macOS print dialog (⌘P from Preview)
        NSWorkspace.shared.open(tmpURL)
    }
}

// MARK: - FontPickerView

private struct FontPickerView: View {

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
        guard !searchText.isEmpty else { return allFamilies }
        return allFamilies.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Size control ──────────────────────────────────────────────
            HStack(spacing: 8) {
                Text("Size:")
                    .frame(width: 34, alignment: .leading)
                Button {
                    appState.logFontSize = max(8, appState.logFontSize - 1)
                    appState.savePreferences()
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.bordered)

                Text("\(Int(appState.logFontSize)) pt")
                    .frame(width: 40, alignment: .center)
                    .monospacedDigit()

                Button {
                    appState.logFontSize = min(36, appState.logFontSize + 1)
                    appState.savePreferences()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(12)

            Divider()

            // ── Font search ───────────────────────────────────────────────
            TextField("Search fonts…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // ── Font list ─────────────────────────────────────────────────
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
            .listStyle(.plain)

            Divider()

            // ── Preview ───────────────────────────────────────────────────
            Text("The quick brown fox jumps  1234567890")
                .font(appState.logFont)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .frame(width: 280, height: 400)
    }

    private func selectFamily(_ family: String) {
        let descriptor = NSFontDescriptor(fontAttributes: [.family: family])
        if let font = NSFont(descriptor: descriptor, size: appState.logFontSize) {
            appState.logFontName = font.fontName
            appState.savePreferences()
        }
    }
}
