import SwiftUI
import Foundation

// MARK: - HighlightRule

struct HighlightRule: Codable, Identifiable {
    var id               = UUID()
    var name:            String
    var pattern:         String
    var colorRed:        Double
    var colorGreen:      Double
    var colorBlue:       Double
    var colorAlpha:      Double = 0.30
    var useRegex:        Bool   = false
    var isCaseSensitive: Bool   = false
    var isEnabled:       Bool   = true

    // SwiftUI Color derived from stored components
    var color: Color {
        Color(red: colorRed, green: colorGreen, blue: colorBlue, opacity: colorAlpha)
    }

    // Full-opacity version for swatches / ColorPicker
    var solidColor: Color {
        Color(red: colorRed, green: colorGreen, blue: colorBlue)
    }

    // Binding<Color> helper: reading solid color, writing back RGB
    mutating func setColor(_ newColor: Color) {
        let resolved = NSColor(newColor).usingColorSpace(.deviceRGB) ?? .yellow
        colorRed   = Double(resolved.redComponent)
        colorGreen = Double(resolved.greenComponent)
        colorBlue  = Double(resolved.blueComponent)
    }

    /// Returns true if `text` matches this rule's pattern.
    func matches(_ text: String) -> Bool {
        guard isEnabled, !pattern.isEmpty else { return false }
        if useRegex {
            guard let rx = try? NSRegularExpression(
                pattern: pattern,
                options: isCaseSensitive ? [] : .caseInsensitive
            ) else { return false }
            let ns = text as NSString
            return rx.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) != nil
        } else {
            let opts: String.CompareOptions = isCaseSensitive ? [.literal] : [.caseInsensitive, .literal]
            return text.range(of: pattern, options: opts) != nil
        }
    }
}

// MARK: - Preset palette

extension HighlightRule {
    static let presetColors: [(name: String, r: Double, g: Double, b: Double)] = [
        ("Yellow",  1.00, 0.90, 0.20),
        ("Orange",  1.00, 0.60, 0.10),
        ("Red",     0.95, 0.30, 0.30),
        ("Pink",    1.00, 0.50, 0.80),
        ("Purple",  0.70, 0.40, 1.00),
        ("Blue",    0.30, 0.65, 1.00),
        ("Teal",    0.20, 0.85, 0.75),
        ("Green",   0.35, 0.85, 0.40),
    ]

    static func makeNew(name: String = "New Rule",
                        pattern: String = "",
                        r: Double = 1.00, g: Double = 0.90, b: Double = 0.20) -> HighlightRule {
        HighlightRule(name: name, pattern: pattern,
                      colorRed: r, colorGreen: g, colorBlue: b)
    }
}
