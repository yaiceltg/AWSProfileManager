import SwiftUI
import AWSProfileKit

/// Traffic-light badge for a session's token: green (valid), amber (expiring),
/// red (expired), gray (unknown).
struct SessionStatusBadge: View {
    let status: TokenStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
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
        case let .valid(remaining): return "Activo · \(Self.format(remaining))"
        case let .expiringSoon(remaining): return "Expira pronto · \(Self.format(remaining))"
        case .expired: return "Expirado"
        case .unknown: return "Sin token"
        }
    }

    private var helpText: String {
        switch status {
        case .valid, .expiringSoon: return "Token SSO vigente. Tiempo restante hasta la expiración."
        case .expired: return "El token SSO expiró. Hacé login para refrescar."
        case .unknown: return "No hay token en cache para esta sesión."
        }
    }

    /// Formats a duration as `2h 15m` / `45m` / `<1m`.
    static func format(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        if totalMinutes < 1 { return "<1m" }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        return "\(hours)h \(minutes)m"
    }
}
