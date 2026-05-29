import SwiftUI
import AWSProfileKit

/// Traffic-light badge for a session's token: green (valid), amber (expiring),
/// red (expired), gray (unknown).
struct SessionStatusBadge: View {
    let status: TokenStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .help(helpText)
    }

    private var color: Color {
        switch status {
        case .valid: return .green
        case .expiringSoon: return .orange
        case .expired: return .red
        case .unknown: return .gray
        }
    }

    private var label: String {
        switch status {
        case let .valid(remaining): return "Active · \(Self.format(remaining))"
        case let .expiringSoon(remaining): return "Expiring · \(Self.format(remaining))"
        case .expired: return "Expired"
        case .unknown: return "No token"
        }
    }

    private var helpText: String {
        switch status {
        case .valid, .expiringSoon: return "SSO token valid. Time remaining until expiry."
        case .expired: return "The SSO token expired. Refresh to sign in again."
        case .unknown: return "No cached token for this session."
        }
    }

    /// Formats a duration as `2h 15m` / `45m` / `<1m`.
    static func format(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        if totalMinutes < 1 { return "<1m" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours == 0 ? "\(minutes)m" : "\(hours)h \(minutes)m"
    }
}

/// Small indicator of a profile's drift status vs the app manifest.
struct DriftBadge: View {
    let status: DriftStatus

    var body: some View {
        if let descriptor {
            Label(descriptor.text, systemImage: descriptor.icon)
                .font(.caption2)
                .foregroundStyle(descriptor.color)
                .help(descriptor.help)
        }
    }

    private var descriptor: (text: String, icon: String, color: Color, help: String)? {
        switch status {
        case .ok:
            return nil // no badge when everything is in sync
        case .modified:
            return ("Modified", "pencil.circle", .orange, "Changed outside the app since it was last recorded.")
        case let .broken(reason):
            return ("Broken", "exclamationmark.triangle", .red, reason)
        case .removed:
            return ("Removed", "trash.circle", .red, "Tracked by the app but no longer in the config.")
        case .untracked:
            return ("Untracked", "questionmark.circle", .secondary, "Found in the config but not yet recorded by the app.")
        }
    }
}
