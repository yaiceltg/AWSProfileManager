import SwiftUI
import AWSProfileKit

/// One profile row: identity on the left, default state / action on the right.
struct ProfileRowView: View {
    let profile: Profile
    let isDefault: Bool
    let onMakeDefault: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.body.weight(.medium))
                    if isDefault {
                        Text("DEFAULT")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isDefault {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .help("Este perfil es el default actual")
            } else {
                Button("Hacer default", action: onMakeDefault)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let account = profile.accountId { parts.append("acct \(account)") }
        if let role = profile.roleName { parts.append(role) }
        if let region = profile.region { parts.append(region) }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}
