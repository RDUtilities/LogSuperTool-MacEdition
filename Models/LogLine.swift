import Foundation
import SwiftUI

// MARK: - LogSeverity

enum LogSeverity: String, CaseIterable, Equatable {
    case none  = "None"
    case trace = "Trace"
    case debug = "Debug"
    case info  = "Info"
    case warn  = "Warn"
    case error = "Error"

    var rowBackground: Color {
        switch self {
        case .error: return Color(red: 1.0, green: 0.706, blue: 0.663).opacity(0.18)
        case .warn:  return Color(red: 1.0, green: 0.835, blue: 0.541).opacity(0.18)
        case .info:  return Color(red: 0.722, green: 0.882, blue: 1.0).opacity(0.18)
        default:     return .clear
        }
    }

    var labelColor: Color {
        switch self {
        case .error: return Color(red: 1.0,   green: 0.706, blue: 0.663)
        case .warn:  return Color(red: 1.0,   green: 0.835, blue: 0.541)
        case .info:  return Color(red: 0.722, green: 0.882, blue: 1.0)
        default:     return .secondary
        }
    }

    var isProblem: Bool { self == .error || self == .warn }
}

// MARK: - LogLine

struct LogLine: Identifiable, Sendable {
    var id: Int { lineNumber }
    let lineNumber:  Int
    let text:        String
    let severity:    LogSeverity
    /// Whether the parser found a recognizable date. The timeline only needs
    /// this flag; eagerly constructing a Date for every record is expensive
    /// and does not add anything to the current UI.
    let hasTimestamp: Bool
    let dateString:  String
    let timeString:  String

    init(lineNumber: Int,
         text:       String,
         severity:   LogSeverity = .none,
         hasTimestamp: Bool      = false,
         dateString: String      = "",
         timeString: String      = "")
    {
        self.lineNumber = lineNumber
        self.text       = text
        self.severity   = severity
        self.hasTimestamp = hasTimestamp
        self.dateString = dateString
        self.timeString = timeString
    }
}

extension LogLine {
    static func csvField(_ value: String) -> String {
        let firstNonWhitespace = value.drop(while: { $0 == " " || $0 == "\t" })
        let safeValue: String
        if let first = firstNonWhitespace.first, ["=", "+", "-", "@"].contains(first) {
            safeValue = "'" + value
        } else {
            safeValue = value
        }
        return "\"\(safeValue.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
