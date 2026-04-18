import Foundation

/// Removes common German filler words from a transcription.
///
/// Safe-by-design: only strips tokens that are unambiguous fillers. Does NOT
/// touch `um` (Präposition) or `er` (Pronomen), even though they appear in
/// English filler lists.
enum FillerCleaner {

    /// Pattern matches: `äh`, `öh`, `ähm`, `öhm`, `ääh`, `ähhh`, `mhm`, `hmm`,
    /// `uhm`, `uhh` — with arbitrary trailing `h` / `m` repetitions.
    /// Case-insensitive, word-bounded, swallows trailing comma + whitespace.
    private static let pattern = #"(?i)\b(?:ä+h+m*|ö+h+m*|m+h+m+|h+m+m+|u+h+m*)\b[,]?\s*"#

    static func clean(_ text: String) -> String {
        var result = text

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result, options: [], range: range, withTemplate: ""
            )
        }

        // Collapse double commas left over ("…, ähm, …" → "…, …" → "…,…" → "…, …")
        result = result.replacingOccurrences(
            of: #",\s*,"#, with: ",", options: .regularExpression
        )
        // Whitespace before punctuation ("… ,") → no space
        result = result.replacingOccurrences(
            of: #"\s+([,.!?;:])"#, with: "$1", options: .regularExpression
        )
        // Collapse multiple spaces
        result = result.replacingOccurrences(
            of: #"\s{2,}"#, with: " ", options: .regularExpression
        )
        // Comma directly followed by end of string → drop it
        result = result.replacingOccurrences(
            of: #",\s*$"#, with: "", options: .regularExpression
        )

        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fix lowercase start if the first word was a filler
        if let first = result.first, first.isLowercase {
            result = first.uppercased() + result.dropFirst()
        }
        return result
    }
}
