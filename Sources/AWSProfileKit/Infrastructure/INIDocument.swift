import Foundation

/// A minimal INI parser tailored to AWS config files.
///
/// Beyond logical sections it preserves each section's line range in the
/// original text, enabling surgical edits (e.g. replacing only `[default]`)
/// without reserializing — comments and whitespace elsewhere stay untouched.
public struct INIDocument: Equatable, Sendable {
    public struct KeyValue: Equatable, Sendable {
        public let key: String
        public let value: String
    }

    public struct Section: Equatable, Sendable {
        /// First token of the header (`default`, `profile`, `sso-session`).
        public let type: String
        /// Remaining tokens joined (the profile or session name); nil for `default`.
        public let name: String?
        public let pairs: [KeyValue]
        /// Half-open line range `[start, end)` in the original line array.
        public let lineRange: Range<Int>

        public func value(for key: String) -> String? {
            pairs.first { $0.key == key }?.value
        }
    }

    public let lines: [String]
    public let sections: [Section]

    public init(_ text: String) {
        let rawLines = text.components(separatedBy: "\n")
        self.lines = rawLines

        var parsed: [Section] = []
        var currentHeader: (type: String, name: String?, start: Int)?
        var currentPairs: [KeyValue] = []

        func flush(end: Int) {
            guard let header = currentHeader else { return }
            parsed.append(
                Section(
                    type: header.type,
                    name: header.name,
                    pairs: currentPairs,
                    lineRange: header.start..<end
                )
            )
            currentPairs = []
        }

        for (index, rawLine) in rawLines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") {
                continue
            }
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                flush(end: index)
                let inner = String(trimmed.dropFirst().dropLast())
                    .trimmingCharacters(in: .whitespaces)
                let tokens = inner.split(whereSeparator: { $0 == " " || $0 == "\t" })
                let type = tokens.first.map(String.init) ?? ""
                let name = tokens.count > 1
                    ? tokens.dropFirst().joined(separator: " ")
                    : nil
                currentHeader = (type: type, name: name, start: index)
            } else if let eq = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<eq]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: eq)...])
                    .trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    currentPairs.append(KeyValue(key: key, value: value))
                }
            }
        }
        flush(end: rawLines.count)

        self.sections = parsed
    }

    public func section(type: String, name: String?) -> Section? {
        sections.first { $0.type == type && $0.name == name }
    }
}
