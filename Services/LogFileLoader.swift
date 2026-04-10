import Foundation

// MARK: - LineBatch

struct LineBatch: Sendable {
    let lines:     [LogLine]
    let bytesRead: Int64   // cumulative bytes read so far in this stream
}

// MARK: - TailReadBatch

struct TailReadBatch {
    let nextOffset:   Int64
    let lines:        [LogLine]
    let wasTruncated: Bool
}

// MARK: - LogFileLoader

final class LogFileLoader: @unchecked Sendable {

    private static let readBufferSize  = 8 * 1_024 * 1_024   // 8 MB per read
    private static let streamBatchSize = 10_000               // lines per yield

    // Timestamp regexes — compiled once at class load time
    private static let isoDateRx   = try! NSRegularExpression(pattern: #"(\d{4}-\d{2}-\d{2})"#)
    private static let slashDateRx = try! NSRegularExpression(pattern: #"(\d{1,2}/\d{1,2}/\d{4})"#)
    private static let monthNameRx = try! NSRegularExpression(pattern: #"(\d{1,2}-[A-Za-z]{3}-\d{4})"#)
    private static let timeRx      = try! NSRegularExpression(pattern: #"\b(\d{2}:\d{2}:\d{2}(?:[.,]\d+)?)\b"#)

    private static let dateFormats = [
        "yyyy-MM-dd HH:mm:ss.SSS",
        "yyyy-MM-dd HH:mm:ss,SSS",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd",
        "MM/dd/yyyy HH:mm:ss.SSS",
        "MM/dd/yyyy HH:mm:ss",
        "MM/dd/yyyy",
        "dd-MMM-yyyy HH:mm:ss.SSS",
        "dd-MMM-yyyy HH:mm:ss",
        "dd-MMM-yyyy",
    ]

    // MARK: - Public API

    /// Stream lines from a large file in batches without ever loading the whole
    /// file as a String.  Yields LineBatch values (~10 000 lines each) so the
    /// UI can display the first results within milliseconds and show progress.
    func streamLines(from url: URL) -> AsyncThrowingStream<LineBatch, Error> {
        AsyncThrowingStream { continuation in
            Task.detached(priority: .userInitiated) {
                let formatters = LogFileLoader.makeDateFormatters()
                do {
                    let fh = try FileHandle(forReadingFrom: url)
                    defer { try? fh.close() }

                    var lineNumber  = 1
                    var bytesRead: Int64 = 0
                    var pending    = Data()
                    pending.reserveCapacity(LogFileLoader.readBufferSize + 4_096)
                    var batch = [LogLine]()
                    batch.reserveCapacity(LogFileLoader.streamBatchSize)

                    while true {
                        if Task.isCancelled { continuation.finish(); return }
                        let chunk = fh.readData(ofLength: LogFileLoader.readBufferSize)
                        if chunk.isEmpty { break }
                        bytesRead += Int64(chunk.count)
                        pending.append(contentsOf: chunk)

                        // Drain all complete lines from pending
                        var start = pending.startIndex
                        while let nlIdx = pending[start...].firstIndex(of: UInt8(ascii: "\n")) {
                            let lineBytes = pending[start..<nlIdx]
                            start = pending.index(after: nlIdx)

                            guard let raw = String(bytes: lineBytes, encoding: .utf8)
                                         ?? String(bytes: lineBytes, encoding: .isoLatin1)
                            else { lineNumber += 1; continue }

                            let text = raw.last == "\r" ? String(raw.dropLast()) : raw
                            guard !text.isEmpty else { lineNumber += 1; continue }

                            let sev = LogFileLoader.detectSeverity(text)
                            let (ts, dateS, timeS) = LogFileLoader.extractTimestamp(text, formatters: formatters)
                            batch.append(LogLine(lineNumber: lineNumber, text: text,
                                                 severity: sev, timestamp: ts,
                                                 dateString: dateS, timeString: timeS))
                            lineNumber += 1

                            if batch.count >= LogFileLoader.streamBatchSize {
                                continuation.yield(LineBatch(lines: batch, bytesRead: bytesRead))
                                batch = []
                                batch.reserveCapacity(LogFileLoader.streamBatchSize)
                            }
                        }
                        // Keep only unprocessed bytes (typically < one line)
                        if start > pending.startIndex {
                            pending = Data(pending[start...])
                        }
                    }

                    // Handle final partial line (file not ending with \n)
                    if !pending.isEmpty,
                       let raw = String(bytes: pending, encoding: .utf8)
                              ?? String(bytes: pending, encoding: .isoLatin1) {
                        let text = raw.last == "\r" ? String(raw.dropLast()) : raw
                        if !text.isEmpty {
                            let sev = LogFileLoader.detectSeverity(text)
                            let (ts, dateS, timeS) = LogFileLoader.extractTimestamp(text, formatters: formatters)
                            batch.append(LogLine(lineNumber: lineNumber, text: text,
                                                 severity: sev, timestamp: ts,
                                                 dateString: dateS, timeString: timeS))
                        }
                    }

                    if !batch.isEmpty { continuation.yield(LineBatch(lines: batch, bytesRead: bytesRead)) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Read only newly appended bytes since `offset` (for tail mode).
    func readAppendedLines(from url: URL,
                           offset: Int64,
                           startLineNumber: Int) async throws -> TailReadBatch
    {
        return try await Task.detached(priority: .utility) {
            let fh   = try FileHandle(forReadingFrom: url)
            let size = Int64(fh.seekToEndOfFile())
            let formatters = LogFileLoader.makeDateFormatters()

            if offset > size {
                fh.seek(toFileOffset: 0)
                let data = fh.readDataToEndOfFile()
                fh.closeFile()
                let lines = LogFileLoader.parseBytes(data, startLine: 1, formatters: formatters)
                return TailReadBatch(nextOffset: size, lines: lines, wasTruncated: true)
            }
            guard offset < size else {
                fh.closeFile()
                return TailReadBatch(nextOffset: size, lines: [], wasTruncated: false)
            }
            fh.seek(toFileOffset: UInt64(offset))
            let data = fh.readDataToEndOfFile()
            fh.closeFile()
            let lines = LogFileLoader.parseBytes(data, startLine: startLineNumber, formatters: formatters)
            return TailReadBatch(nextOffset: size, lines: lines, wasTruncated: false)
        }.value
    }

    // MARK: - Private helpers

    private static func parseBytes(_ data: Data, startLine: Int,
                                   formatters: [DateFormatter]) -> [LogLine] {
        var result = [LogLine]()
        var lineNumber = startLine
        var start = data.startIndex

        while let nlIdx = data[start...].firstIndex(of: UInt8(ascii: "\n")) {
            let bytes = data[start..<nlIdx]
            start = data.index(after: nlIdx)
            guard let raw = String(bytes: bytes, encoding: .utf8)
                         ?? String(bytes: bytes, encoding: .isoLatin1) else {
                lineNumber += 1; continue
            }
            let text = raw.last == "\r" ? String(raw.dropLast()) : raw
            guard !text.isEmpty else { lineNumber += 1; continue }
            let sev = detectSeverity(text)
            let (ts, dateS, timeS) = extractTimestamp(text, formatters: formatters)
            result.append(LogLine(lineNumber: lineNumber, text: text,
                                  severity: sev, timestamp: ts,
                                  dateString: dateS, timeString: timeS))
            lineNumber += 1
        }
        let remaining = data[start...]
        if !remaining.isEmpty,
           let raw = String(bytes: remaining, encoding: .utf8)
                  ?? String(bytes: remaining, encoding: .isoLatin1) {
            let text = raw.last == "\r" ? String(raw.dropLast()) : raw
            if !text.isEmpty {
                let sev = detectSeverity(text)
                let (ts, dateS, timeS) = extractTimestamp(text, formatters: formatters)
                result.append(LogLine(lineNumber: lineNumber, text: text,
                                      severity: sev, timestamp: ts,
                                      dateString: dateS, timeString: timeS))
            }
        }
        return result
    }

    private static func detectSeverity(_ text: String) -> LogSeverity {
        let opts: String.CompareOptions = [.caseInsensitive, .literal]
        if text.range(of: "fatal",     options: opts) != nil { return .error }
        if text.range(of: "exception", options: opts) != nil { return .error }
        if text.range(of: "error",     options: opts) != nil { return .error }
        if text.range(of: "failed",    options: opts) != nil { return .error }
        if text.range(of: "warn",      options: opts) != nil { return .warn }
        if text.range(of: "timeout",   options: opts) != nil { return .warn }
        if text.range(of: "info",      options: opts) != nil { return .info }
        if text.range(of: "debug",     options: opts) != nil { return .debug }
        if text.range(of: "trace",     options: opts) != nil { return .trace }
        return .none
    }

    private static func extractTimestamp(_ text: String,
                                         formatters: [DateFormatter]) -> (Date?, String, String) {
        let ns    = text as NSString
        let range = NSRange(location: 0, length: ns.length)

        var dateStr = ""
        if let m = isoDateRx.firstMatch(in: text, range: range) {
            dateStr = ns.substring(with: m.range(at: 1))
        } else if let m = slashDateRx.firstMatch(in: text, range: range) {
            dateStr = ns.substring(with: m.range(at: 1))
        } else if let m = monthNameRx.firstMatch(in: text, range: range) {
            dateStr = ns.substring(with: m.range(at: 1))
        }

        var timeStr = ""
        if let m = timeRx.firstMatch(in: text, range: range) {
            timeStr = ns.substring(with: m.range(at: 1))
        }

        guard !dateStr.isEmpty else { return (nil, "", timeStr) }
        let combined = timeStr.isEmpty ? dateStr : "\(dateStr) \(timeStr)"
        let date = parseDate(combined, formatters: formatters)
        return (date, dateStr, timeStr)
    }

    private static func parseDate(_ s: String, formatters: [DateFormatter]) -> Date? {
        for fmt in formatters {
            if let d = fmt.date(from: s) { return d }
        }
        return nil
    }

    /// Create one DateFormatter per supported format. Call once per parse session,
    /// not once per line.
    private static func makeDateFormatters() -> [DateFormatter] {
        dateFormats.map { format in
            let f = DateFormatter()
            f.locale     = Locale(identifier: "en_US_POSIX")
            f.dateFormat = format
            return f
        }
    }
}
