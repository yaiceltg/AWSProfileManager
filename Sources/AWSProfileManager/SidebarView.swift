import SwiftUI
import AWSProfileKit

/// Prefix-grouped profiles plus a Settings entry, driving the detail selection.
struct SidebarView: View {
    @Bindable var model: AppModel

    var body: some View {
        List(selection: $model.selection) {
            ForEach(model.filteredGroups) { group in
                Section(group.title) {
                    ForEach(group.items) { item in
                        row(for: item)
                            .tag(AppModel.Selection.profile(item.profile.name))
                    }
                }
            }

            Section {
                Label("Settings", systemImage: "gearshape")
                    .tag(AppModel.Selection.settings)
            }
        }
        .listStyle(.sidebar)
    }

    private func row(for item: ProfileDisplayItem) -> some View {
        let name = item.profile.name
        return HStack(spacing: 8) {
            Circle()
                .fill(dotColor(for: item.profile))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if model.defaultProfileName == name {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                    .help("Current default profile")
            }
        }
        .padding(.vertical, 2)
    }

    private func dotColor(for profile: Profile) -> Color {
        switch model.drift(for: profile.name) {
        case .broken, .removed: return .red
        case .modified: return .orange
        case .untracked: return .secondary
        case .ok:
            switch model.tokenStatus(for: profile) {
            case .valid: return .green
            case .expiringSoon: return .orange
            case .expired: return .red
            case .unknown: return .gray
            }
        }
    }
}
