import SwiftUI
import AppKit

// MARK: - HighlightedText

/// Renders `text` with all occurrences of `highlight` marked with a yellow background.
/// Uses AttributedString so highlighting works cleanly within SwiftUI Text.
struct HighlightedText: View {

    let text:            String
    let highlight:       String
    let isCaseSensitive: Bool
    let useRegex:        Bool

    var body: some View {
        Text(attributedText)
    }

    // MARK: - AttributedString builder

    private var attributedText: AttributedString {
        guard !highlight.isEmpty else { return AttributedString(text) }

        let ns = NSMutableAttributedString(string: text)
        for range in findMatchRanges() {
            let nsRange = NSRange(range, in: text)
            ns.addAttribute(.backgroundColor, value: NSColor.yellow,         range: nsRange)
            ns.addAttribute(.foregroundColor, value: NSColor.black,          range: nsRange)
        }

        return (try? AttributedString(ns, including: \.appKit)) ?? AttributedString(text)
    }

    // MARK: - Match detection

    private func findMatchRanges() -> [Range<String.Index>] {
        useRegex ? regexRanges() : literalRanges()
    }

    private func literalRanges() -> [Range<String.Index>] {
        var results: [Range<String.Index>] = []
        let opts: String.CompareOptions    = isCaseSensitive ? [] : .caseInsensitive
        var search = text.startIndex..<text.endIndex

        while let range = text.range(of: highlight, options: opts, range: search) {
            results.append(range)
            guard range.upperBound < text.endIndex else { break }
            search = range.upperBound..<text.endIndex
        }
        return results
    }

    private func regexRanges() -> [Range<String.Index>] {
        guard let rx = LogRegex.expression(pattern: highlight, isCaseSensitive: isCaseSensitive) else { return [] }

        let ns      = text as NSString
        let nsRange = NSRange(location: 0, length: ns.length)
        return rx.matches(in: text, range: nsRange).compactMap { Range($0.range, in: text) }
    }
}
