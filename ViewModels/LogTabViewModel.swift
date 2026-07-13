import Foundation
import Combine
import SwiftUI

// MARK: - Filter helpers (value types, Sendable)

private struct FilterSnapshot: Sendable {
    let lines:           [LogLine]
    let searchText:      String
    let filterText:      String
    let excludeText:     String
    let isCaseSensitive: Bool
    let useRegex:        Bool
    let onlyErrors:      Bool
}

private struct FilterResult: Sendable {
    let lines:             [LogLine]
    let matchLineNumbers:  [Int]
}

// MARK: - LogTabViewModel

@MainActor
final class LogTabViewModel: ObservableObject, Identifiable {

    let id = UUID()

    // MARK: File state
    @Published var tabTitle:  String = "Untitled"
    @Published var fileURL:   URL?   = nil
    @Published var isLoading: Bool   = false
    @Published private(set) var loadProgress: Double = 0   // 0…1 during load, 1 when done
    @Published private(set) var isFiltering: Bool = false
    @Published private(set) var loadError: String? = nil   // non-nil when file failed to load

    // MARK: Lines
    @Published private(set) var allLines:     [LogLine] = []
    @Published private(set) var visibleLines: [LogLine] = []

    // MARK: Search
    @Published var searchText:      String = "" { didSet { scheduleFilter() } }
    @Published var filterText:      String = "" { didSet { scheduleFilter() } }
    @Published var excludeText:     String = "" { didSet { scheduleFilter() } }
    @Published var isCaseSensitive: Bool   = false { didSet { scheduleFilter() } }
    @Published var useRegex:        Bool   = false { didSet { scheduleFilter() } }
    @Published var onlyErrors:      Bool   = false { didSet { scheduleFilter() } }

    @Published private(set) var searchMatchCount:       Int      = 0
    @Published private(set) var searchMatchSet:         Set<Int> = []
    @Published private(set) var currentSearchMatchIndex: Int     = -1
    private var searchMatchLineNumbers: [Int] = []

    // MARK: Selection
    @Published private(set) var selectedLine: LogLine? = nil

    func selectLine(lineNumber: Int?) {
        guard let n = lineNumber else { selectedLine = nil; return }
        selectedLine = visibleLines.first { $0.lineNumber == n }
    }

    // MARK: Bookmarks
    @Published private(set) var bookmarkedLines: Set<Int> = []

    // MARK: Problem navigation
    @Published private(set) var problemLineNumbers:  [Int] = []
    @Published private(set) var currentProblemIndex: Int       = -1

    // MARK: Tail
    @Published var isTailing:  Bool = false { didSet { isTailing ? startTailing() : stopTailing() } }
    @Published var autoScroll: Bool = false

    // MARK: Timeline
    @Published private(set) var timestampedLineNumbers: [Int] = []

    // MARK: Column visibility
    @Published var showLineNumbers: Bool = true
    @Published var showSeverity:    Bool = true
    @Published var showDate:        Bool = true
    @Published var showTime:        Bool = true

    // MARK: Display options
    @Published var wrapLines: Bool = false

    // MARK: Callbacks
    var scrollToLineRequested: ((Int) -> Void)?
    var newProblemDetected:    ((LogLine) -> Void)?

    // MARK: Private
    private let loader    = LogFileLoader()
    private var loadTask: Task<Void, Never>?
    private var tailTask: Task<Void, Never>?
    private var filterTask: Task<Void, Never>?
    private var lastOffset: Int64 = 0
    private var operationID = UUID()
    private var firstLineByTime: [String: Int] = [:]
    private var firstLineByDate: [String: Int] = [:]

    // MARK: - Init

    init() {}
    init(url: URL) { self.fileURL = url; self.tabTitle = url.lastPathComponent }

    // MARK: - File Operations

    func loadFile(url: URL) async {
        let operationID = UUID()
        self.operationID = operationID
        let resumeTailing = isTailing
        loadTask?.cancel()
        filterTask?.cancel()
        stopTailing()

        fileURL          = url
        tabTitle         = url.lastPathComponent
        isLoading        = true
        loadProgress     = 0
        allLines         = []
        visibleLines     = []
        searchMatchSet   = []
        searchMatchCount = 0
        searchMatchLineNumbers = []
        problemLineNumbers = []
        timestampedLineNumbers = []
        firstLineByTime = [:]
        firstLineByDate = [:]
        lastOffset       = 0

        loadTask = Task {
            let totalBytes = fileSizeOf(url)
            loadError = nil
            do {
                var isFirstBatch = true
                for try await batch in loader.streamLines(
                    from: url,
                    deferUnterminatedFinalLine: resumeTailing
                ) {
                    guard !Task.isCancelled, operationID == self.operationID else { return }
                    allLines.append(contentsOf: batch.lines)
                    lastOffset = batch.tailOffset
                    if totalBytes > 0 {
                        loadProgress = min(Double(batch.bytesRead) / Double(totalBytes), 0.99)
                    }
                    if isFirstBatch {
                        isFirstBatch = false
                        applySearchAndFilter()
                    }
                }
                guard !Task.isCancelled, operationID == self.operationID else { return }
                loadProgress = 1.0
                applySearchAndFilter()
                rebuildProblemLines()
                rebuildTimestampedLines()
            } catch {
                if operationID == self.operationID {
                    loadError = error.localizedDescription
                    print("[LogTabViewModel] load error: \(error)")
                }
            }
            guard operationID == self.operationID else { return }
            if !resumeTailing { lastOffset = fileSizeOf(url) }
            isLoading = false
            if resumeTailing && !Task.isCancelled { startTailLoop(operationID: operationID) }
        }
        await loadTask?.value
    }

    func reload() async {
        guard let url = fileURL else { return }
        await loadFile(url: url)
    }

    func closeFile() {
        operationID = UUID()
        loadTask?.cancel()
        filterTask?.cancel()
        stopTailing()
        fileURL          = nil
        tabTitle         = "Untitled"
        allLines         = []
        visibleLines     = []
        searchMatchSet   = []
        searchMatchCount = 0
        searchMatchLineNumbers = []
        problemLineNumbers = []
        timestampedLineNumbers = []
        firstLineByTime = [:]
        firstLineByDate = [:]
        excludeText      = ""
        lastOffset       = 0
        loadError        = nil
    }

    // MARK: - Search & Filter

    /// Immediate (no debounce) — used by load / reload paths.
    func applySearchAndFilter() {
        filterTask?.cancel()
        let snap = makeSnapshot()
        filterTask = Task {
            isFiltering = true
            let result  = await Self.computeFilter(snap)
            guard !Task.isCancelled else { isFiltering = false; return }
            applyFilterResult(result)
            isFiltering = false
        }
    }

    /// Debounced — used when the user types in search/filter fields.
    private func scheduleFilter() {
        filterTask?.cancel()
        let snap = makeSnapshot()
        filterTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)   // 250 ms
            guard !Task.isCancelled else { return }
            isFiltering = true
            let result  = await Self.computeFilter(snap)
            guard !Task.isCancelled else { isFiltering = false; return }
            applyFilterResult(result)
            isFiltering = false
        }
    }

    private func applyFilterResult(_ result: FilterResult) {
        visibleLines     = result.lines
        searchMatchSet   = Set(result.matchLineNumbers)
        searchMatchCount = result.matchLineNumbers.count
        searchMatchLineNumbers = result.matchLineNumbers
        if result.matchLineNumbers.isEmpty {
            currentSearchMatchIndex = -1
        } else if currentSearchMatchIndex >= result.matchLineNumbers.count {
            currentSearchMatchIndex = result.matchLineNumbers.count - 1
        }
    }

    private func makeSnapshot() -> FilterSnapshot {
        FilterSnapshot(lines: allLines, searchText: searchText,
                       filterText: filterText, excludeText: excludeText,
                       isCaseSensitive: isCaseSensitive,
                       useRegex: useRegex, onlyErrors: onlyErrors)
    }

    /// Runs entirely off the main actor.
    private static func computeFilter(_ snap: FilterSnapshot) async -> FilterResult {
        await Task.detached(priority: .userInitiated) {
            let filterRegex = snap.useRegex && !snap.filterText.isEmpty
                ? LogRegex.expression(pattern: snap.filterText, isCaseSensitive: snap.isCaseSensitive)
                : nil
            let excludeRegex = snap.useRegex && !snap.excludeText.isEmpty
                ? LogRegex.expression(pattern: snap.excludeText, isCaseSensitive: snap.isCaseSensitive)
                : nil
            let searchRegex = snap.useRegex && !snap.searchText.isEmpty
                ? LogRegex.expression(pattern: snap.searchText, isCaseSensitive: snap.isCaseSensitive)
                : nil

            // An invalid regex must not silently become a literal filter.
            if snap.useRegex && ((!snap.filterText.isEmpty && filterRegex == nil)
                || (!snap.excludeText.isEmpty && excludeRegex == nil)) {
                return FilterResult(lines: [], matchLineNumbers: [])
            }
            if !snap.onlyErrors && snap.filterText.isEmpty && snap.excludeText.isEmpty && snap.searchText.isEmpty {
                return FilterResult(lines: snap.lines, matchLineNumbers: [])
            }
            let options: String.CompareOptions = snap.isCaseSensitive
                ? [.literal] : [.caseInsensitive, .literal]
            var lines = [LogLine]()
            lines.reserveCapacity(snap.lines.count)
            var matchLineNumbers = [Int]()

            // Perform all predicates in one pass. The previous chain of filters
            // allocated and scanned the complete collection up to four times.
            for line in snap.lines {
                if snap.onlyErrors && !line.severity.isProblem { continue }

                let text = line.text
                let includesFilter: Bool
                if snap.filterText.isEmpty {
                    includesFilter = true
                } else if let regex = filterRegex {
                    includesFilter = regex.firstMatch(
                        in: text,
                        range: NSRange(location: 0, length: (text as NSString).length)
                    ) != nil
                } else {
                    includesFilter = text.range(of: snap.filterText, options: options) != nil
                }
                guard includesFilter else { continue }

                let isExcluded: Bool
                if snap.excludeText.isEmpty {
                    isExcluded = false
                } else if let regex = excludeRegex {
                    isExcluded = regex.firstMatch(
                        in: text,
                        range: NSRange(location: 0, length: (text as NSString).length)
                    ) != nil
                } else {
                    isExcluded = text.range(of: snap.excludeText, options: options) != nil
                }
                guard !isExcluded else { continue }

                lines.append(line)
                if !snap.searchText.isEmpty {
                    let matches: Bool
                    if snap.useRegex, let regex = searchRegex {
                        matches = regex.firstMatch(
                            in: text,
                            range: NSRange(location: 0, length: (text as NSString).length)
                        ) != nil
                    } else if snap.useRegex {
                        matches = false
                    } else {
                        matches = text.range(of: snap.searchText, options: options) != nil
                    }
                    if matches { matchLineNumbers.append(line.lineNumber) }
                }
            }

            return FilterResult(lines: lines, matchLineNumbers: matchLineNumbers)
        }.value
    }

    // MARK: - Search Navigation

    func findNext() {
        let matches = searchMatchLineNumbers
        guard !matches.isEmpty else { return }
        currentSearchMatchIndex = (currentSearchMatchIndex + 1) % matches.count
        scrollToLineRequested?(matches[currentSearchMatchIndex])
    }

    func findPrev() {
        let matches = searchMatchLineNumbers
        guard !matches.isEmpty else { return }
        currentSearchMatchIndex = currentSearchMatchIndex < 0
            ? matches.count - 1
            : (currentSearchMatchIndex - 1 + matches.count) % matches.count
        scrollToLineRequested?(matches[currentSearchMatchIndex])
    }

    // MARK: - Problem Navigation

    private func rebuildProblemLines() {
        problemLineNumbers = allLines.compactMap { $0.severity.isProblem ? $0.lineNumber : nil }
    }

    func nextError() {
        guard !problemLineNumbers.isEmpty else { return }
        let curLine = currentProblemIndex >= 0 ? problemLineNumbers[currentProblemIndex] : 0
        if let idx = problemLineNumbers.firstIndex(where: { $0 > curLine }) {
            currentProblemIndex = idx
        } else {
            currentProblemIndex = 0
        }
        scrollToLineRequested?(problemLineNumbers[currentProblemIndex])
    }

    func prevError() {
        guard !problemLineNumbers.isEmpty else { return }
        let curLine = currentProblemIndex >= 0 ? problemLineNumbers[currentProblemIndex] : Int.max
        if let idx = problemLineNumbers.lastIndex(where: { $0 < curLine }) {
            currentProblemIndex = idx
        } else {
            currentProblemIndex = problemLineNumbers.count - 1
        }
        scrollToLineRequested?(problemLineNumbers[currentProblemIndex])
    }

    // MARK: - Timeline

    private func rebuildTimestampedLines() {
        timestampedLineNumbers = allLines.compactMap { $0.hasTimestamp ? $0.lineNumber : nil }
        rebuildJumpIndexes()
    }

    private func updateDerivedStateAfterTailAppend(_ lines: [LogLine]) {
        guard !lines.isEmpty else { return }

        problemLineNumbers.append(contentsOf: lines.compactMap { $0.severity.isProblem ? $0.lineNumber : nil })
        timestampedLineNumbers.append(contentsOf: lines.compactMap { $0.hasTimestamp ? $0.lineNumber : nil })
        addToJumpIndexes(lines)

        if !filterText.isEmpty || !excludeText.isEmpty || onlyErrors {
            applySearchAndFilter()
            return
        }

        visibleLines.append(contentsOf: lines)
        guard !searchText.isEmpty else { return }

        let matches: (LogLine) -> Bool
        if useRegex {
            guard let regex = LogRegex.expression(pattern: searchText, isCaseSensitive: isCaseSensitive) else { return }
            matches = { line in
                let range = NSRange(location: 0, length: (line.text as NSString).length)
                return regex.firstMatch(in: line.text, range: range) != nil
            }
        } else {
            let options: String.CompareOptions = isCaseSensitive ? [.literal] : [.caseInsensitive, .literal]
            matches = { $0.text.range(of: self.searchText, options: options) != nil }
        }

        for line in lines where matches(line) {
            searchMatchSet.insert(line.lineNumber)
        }
        searchMatchCount = searchMatchSet.count
    }

    func navigateTimeline(_ position: Double) {
        guard !timestampedLineNumbers.isEmpty else { return }
        let idx = min(Int(position * Double(timestampedLineNumbers.count - 1)),
                      timestampedLineNumbers.count - 1)
        scrollToLineRequested?(timestampedLineNumbers[max(0, idx)])
    }

    func jumpToLine(_ lineNumber: Int) {
        guard !visibleLines.isEmpty else { return }
        let insertion = visibleLines.partitioningIndex { $0.lineNumber < lineNumber }
        if insertion < visibleLines.count, visibleLines[insertion].lineNumber == lineNumber {
            scrollToLineRequested?(lineNumber)
        } else if insertion == 0 {
            scrollToLineRequested?(visibleLines[0].lineNumber)
        } else if insertion == visibleLines.count {
            scrollToLineRequested?(visibleLines[visibleLines.count - 1].lineNumber)
        } else {
            let previous = visibleLines[insertion - 1].lineNumber
            let next = visibleLines[insertion].lineNumber
            scrollToLineRequested?(abs(previous - lineNumber) <= abs(next - lineNumber) ? previous : next)
        }
    }

    func jumpToTime(_ timeString: String) {
        guard let lineNumber = firstLineByTime[timeString] else { return }
        jumpToLine(lineNumber)
    }

    func jumpToDate(_ dateString: String) {
        guard let lineNumber = firstLineByDate[dateString] else { return }
        jumpToLine(lineNumber)
    }

    // MARK: - Tail

    private func startTailing() {
        guard let url = fileURL else { return }
        Task { await loadFile(url: url) }
    }

    private func startTailLoop(operationID: UUID) {
        guard let url = fileURL, isTailing else { return }
        tailTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled, operationID == self.operationID else { break }
                do {
                    let batch = try await loader.readAppendedLines(
                        from:            url,
                        offset:          lastOffset,
                        startLineNumber: (allLines.last?.lineNumber ?? 0) + 1
                    )
                    guard !Task.isCancelled, operationID == self.operationID else { break }

                    if batch.wasTruncated {
                        allLines   = batch.lines
                        lastOffset = batch.nextOffset
                        applySearchAndFilter()
                        rebuildProblemLines()
                        rebuildTimestampedLines()
                    } else {
                        lastOffset = batch.nextOffset
                        if !batch.lines.isEmpty {
                            allLines.append(contentsOf: batch.lines)
                            for line in batch.lines where line.severity.isProblem {
                                newProblemDetected?(line)
                            }
                            updateDerivedStateAfterTailAppend(batch.lines)
                        }
                    }

                    if autoScroll, let last = visibleLines.last {
                        scrollToLineRequested?(last.lineNumber)
                    }
                } catch {
                    print("[LogTabViewModel] tail error: \(error)")
                }
            }
        }
    }

    private func stopTailing() {
        tailTask?.cancel()
        tailTask = nil
    }

    private func rebuildJumpIndexes() {
        firstLineByTime = [:]
        firstLineByDate = [:]
        addToJumpIndexes(allLines)
    }

    private func addToJumpIndexes(_ lines: [LogLine]) {
        for line in lines {
            if !line.dateString.isEmpty, firstLineByDate[line.dateString] == nil {
                firstLineByDate[line.dateString] = line.lineNumber
            }
            let timeKey = String(line.timeString.prefix(8))
            if !timeKey.isEmpty, firstLineByTime[timeKey] == nil {
                firstLineByTime[timeKey] = line.lineNumber
            }
        }
    }

    // MARK: - Bookmark Navigation

    func toggleBookmark(lineNumber: Int) {
        if bookmarkedLines.contains(lineNumber) {
            bookmarkedLines.remove(lineNumber)
        } else {
            bookmarkedLines.insert(lineNumber)
        }
    }

    func nextBookmark() {
        guard !bookmarkedLines.isEmpty else { return }
        let sorted = bookmarkedLines.sorted()
        let currentTop = visibleLines.first?.lineNumber ?? 0
        if let next = sorted.first(where: { $0 > currentTop }) {
            scrollToLineRequested?(next)
        } else {
            scrollToLineRequested?(sorted[0])
        }
    }

    func prevBookmark() {
        guard !bookmarkedLines.isEmpty else { return }
        let sorted = bookmarkedLines.sorted()
        let currentTop = visibleLines.first?.lineNumber ?? Int.max
        if let prev = sorted.last(where: { $0 < currentTop }) {
            scrollToLineRequested?(prev)
        } else {
            scrollToLineRequested?(sorted[sorted.count - 1])
        }
    }

    func clearBookmarks() {
        bookmarkedLines = []
    }

    // MARK: - Export

    func exportText() -> String {
        visibleLines.map { $0.text }.joined(separator: "\n")
    }

    func exportCSV() -> String {
        var rows = ["Line,Severity,Date,Time,Message"]
        for line in visibleLines {
            rows.append(
                "\(line.lineNumber),\(LogLine.csvField(line.severity.rawValue)),"
                + "\(LogLine.csvField(line.dateString)),\(LogLine.csvField(line.timeString)),\(LogLine.csvField(line.text))"
            )
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func fileSizeOf(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
    }
}

// MARK: - Safe subscript helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }

    func partitioningIndex(where predicate: (Element) -> Bool) -> Int {
        var lower = startIndex
        var upper = endIndex
        while lower < upper {
            let middle = index(lower, offsetBy: distance(from: lower, to: upper) / 2)
            if predicate(self[middle]) {
                lower = index(after: middle)
            } else {
                upper = middle
            }
        }
        return lower
    }
}
