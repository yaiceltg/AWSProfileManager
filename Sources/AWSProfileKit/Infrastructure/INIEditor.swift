import Foundation

/// Surgical INI editing by section header. Replaces or removes a single section
/// while leaving every other line — comments, blanks, ordering — untouched.
enum INIEditor {
    /// Upserts `[header]` with the given key/value lines. Replaces the section's
    /// content if it exists; otherwise appends it after a blank separator.
    static func upsert(header: String, pairs: [(String, String)], in text: String) -> String {
        let document = INIDocument(text)
        var lines = document.lines
        let block = renderBlock(header: header, pairs: pairs)

        if let section = document.sections.first(where: { $0.rawHeader == header }) {
            let range = effectiveContentRange(of: section, in: lines)
            lines.replaceSubrange(range, with: block)
        } else {
            while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.removeLast()
            }
            if !lines.isEmpty { lines.append("") }
            lines.append(contentsOf: block)
        }
        return lines.joined(separator: "\n")
    }

    /// Removes the `[header]` section entirely (header line through the line
    /// before the next section). No-op if the section is absent.
    static func remove(header: String, in text: String) -> String {
        let document = INIDocument(text)
        guard let section = document.sections.first(where: { $0.rawHeader == header }) else {
            return text
        }
        var lines = document.lines
        lines.removeSubrange(section.lineRange)
        return lines.joined(separator: "\n")
    }

    private static func renderBlock(header: String, pairs: [(String, String)]) -> [String] {
        ["[\(header)]"] + pairs.map { "\($0.0) = \($0.1)" }
    }

    /// Narrows a section's full line range to exclude trailing blank/comment
    /// lines, so separators before the next section survive a replace.
    private static func effectiveContentRange(
        of section: INIDocument.Section,
        in lines: [String]
    ) -> Range<Int> {
        var end = section.lineRange.upperBound
        while end - 1 > section.lineRange.lowerBound {
            let candidate = lines[end - 1].trimmingCharacters(in: .whitespaces)
            if candidate.isEmpty || candidate.hasPrefix("#") || candidate.hasPrefix(";") {
                end -= 1
            } else {
                break
            }
        }
        return section.lineRange.lowerBound..<end
    }
}
