import SwiftUI
import AWSProfileKit

/// Prefix/label-grouped profiles plus a Settings entry. Hovering a group header
/// reveals a pencil to rename the group's app-only label. Per-profile display
/// names are edited from the profile's Edit form.
struct SidebarView: View {
    @Bindable var model: AppModel
    @State private var hoveredGroup: String?
    @State private var renameTarget: String?
    @State private var renameText: String = ""

    var body: some View {
        List(selection: $model.selection) {
            ForEach(model.filteredGroups) { group in
                Section {
                    ForEach(group.items) { item in
                        row(for: item)
                            .tag(AppModel.Selection.profile(item.profile.name))
                    }
                } header: {
                    groupHeader(group)
                }
            }

            Section {
                Label("Settings", systemImage: "gearshape")
                    .tag(AppModel.Selection.settings)
            }
        }
        .listStyle(.sidebar)
        .sheet(isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            renameGroupSheet
        }
    }

    // MARK: Group header

    private func groupHeader(_ group: ProfileDisplayGroup) -> some View {
        HStack(spacing: 4) {
            Text(group.title)
            Spacer()
            Button {
                renameText = group.title
                renameTarget = group.title
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(.secondary)
            .help("Rename group")
            .opacity(hoveredGroup == group.title ? 1 : 0)
            .allowsHitTesting(hoveredGroup == group.title)
        }
        .padding(.vertical, 4)
        .padding(.trailing, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering { hoveredGroup = group.title }
            else if hoveredGroup == group.title { hoveredGroup = nil }
        }
    }

    // MARK: Profile row

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

    // MARK: Rename group sheet

    private var renameGroupSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename Group").font(.headline)
            Text("All profiles in this group will be relabeled. Auto-grouped profiles become manually grouped.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Group name", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(commitRename)

            HStack {
                Spacer()
                Button("Cancel") { renameTarget = nil }
                    .keyboardShortcut(.cancelAction)
                Button("Rename", action: commitRename)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func commitRename() {
        if let old = renameTarget { model.renameGroup(from: old, to: renameText) }
        renameTarget = nil
    }

    // MARK: Status dot

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
