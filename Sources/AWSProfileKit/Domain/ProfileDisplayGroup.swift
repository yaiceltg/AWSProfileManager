import Foundation

/// An app-only presentation grouping of profiles. The config key is never
/// altered — these names exist purely for display.
public struct ProfileDisplayGroup: Identifiable, Equatable, Sendable {
    public var id: String { title }
    /// Group heading, e.g. "Fantaz" (capitalized prefix of the keys).
    public let title: String
    public let items: [ProfileDisplayItem]

    public init(title: String, items: [ProfileDisplayItem]) {
        self.title = title
        self.items = items
    }
}

public struct ProfileDisplayItem: Identifiable, Equatable, Sendable {
    public var id: String { profile.name }
    public let profile: Profile
    /// Shortened label, e.g. "dev" for the key "fantaz-dev".
    public let displayName: String

    public init(profile: Profile, displayName: String) {
        self.profile = profile
        self.displayName = displayName
    }
}

/// Groups profiles for display, preserving the order groups and profiles first
/// appear in. A manual `assignments` entry (name → group) wins; otherwise the
/// group is the capitalized prefix of the key (the segment before the first "-").
public enum ProfileGrouping {
    /// Convenience: pure auto-by-prefix grouping (no manual assignments).
    public static func byPrefix(_ profiles: [Profile]) -> [ProfileDisplayGroup] {
        grouped(profiles, assignments: [:])
    }

    public static func grouped(
        _ profiles: [Profile],
        assignments: [String: String]
    ) -> [ProfileDisplayGroup] {
        var orderedTitles: [String] = []
        var buckets: [String: [ProfileDisplayItem]] = [:]

        for profile in profiles {
            let title: String
            let displayName: String
            if let assigned = assignments[profile.name], !assigned.isEmpty {
                // Manual group: the prefix is no longer meaningful, show full key.
                title = assigned
                displayName = profile.name
            } else {
                let (prefix, remainder) = split(profile.name)
                title = titleCase(prefix)
                displayName = remainder
            }

            if buckets[title] == nil {
                buckets[title] = []
                orderedTitles.append(title)
            }
            buckets[title]?.append(ProfileDisplayItem(profile: profile, displayName: displayName))
        }

        return orderedTitles.map { title in
            ProfileDisplayGroup(title: title, items: buckets[title] ?? [])
        }
    }

    /// Splits "fantaz-prod-admin" into ("fantaz", "prod-admin"). Keys without a
    /// "-" become their own group with the whole name as the display name.
    private static func split(_ name: String) -> (prefix: String, remainder: String) {
        guard let dash = name.firstIndex(of: "-") else { return (name, name) }
        let prefix = String(name[..<dash])
        let remainder = String(name[name.index(after: dash)...])
        return (prefix, remainder.isEmpty ? name : remainder)
    }

    private static func titleCase(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
    }
}
