import SwiftUI
import AppKit
import AWSProfileKit

/// The menu bar panel (`MenuBarExtra` window style): profiles with status and
/// quick Make Default / Refresh, plus the SSO verification code shown inline so
/// the user never has to open the main window to sign in.
struct MenuBarView: View {
    @Bindable var model: AppModel
    let onOpenWindow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if let login = model.activeLogin {
                loginBanner(login)
                Divider()
            }

            if model.groups.isEmpty {
                Text("No profiles found in ~/.aws/config")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(12)
            } else {
                profileList
            }

            Divider()
            footer
        }
        .frame(width: 320)
        .onAppear { model.reload() }
    }

    // MARK: Header / footer

    private var header: some View {
        HStack {
            Label("AWS Profiles", systemImage: "rectangle.stack.fill")
                .font(.headline)
            Spacer()
            Button {
                model.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Reload")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            Button("Open Window") { onOpenWindow() }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Profiles

    private var profileList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.groups) { group in
                    Text(group.title.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8).padding(.bottom, 2)

                    ForEach(group.items) { item in
                        profileRow(item)
                    }
                }
            }
            .padding(.bottom, 6)
        }
        .frame(maxHeight: 340)
    }

    private func profileRow(_ item: ProfileDisplayItem) -> some View {
        let name = item.profile.name
        let isDefault = model.defaultProfileName == name
        return HStack(spacing: 8) {
            Circle().fill(dotColor(for: item.profile)).frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                Text(name).font(.caption2).foregroundStyle(.tertiary)
            }

            Spacer()

            if isDefault {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
                    .help("Current default")
            } else {
                Button {
                    model.makeDefault(profileNamed: name)
                } label: {
                    Image(systemName: "star")
                }
                .buttonStyle(.borderless)
                .help("Make default")
            }

            if item.profile.isSSO {
                Button {
                    Task { await model.refresh(profileNamed: name) }
                } label: {
                    if model.refreshingProfiles.contains(name) {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(model.refreshingProfiles.contains(name))
                .help("Login / Refresh")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    // MARK: Login banner (inline verification code)

    @ViewBuilder
    private func loginBanner(_ login: LoginSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SSO Login — \(login.profileName)").font(.caption.weight(.semibold))

            switch login.phase {
            case .starting:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Starting…").font(.caption).foregroundStyle(.secondary)
                }
            case let .prompt(prompt):
                if let code = prompt.userCode {
                    HStack(spacing: 8) {
                        Text(code)
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                            .textSelection(.enabled)
                        Button("Copy") { copy(code) }
                            .buttonStyle(.borderless)
                    }
                }
                if let url = prompt.verificationURL {
                    Button("Open in browser") { openURL(url) }
                        .buttonStyle(.borderless)
                }
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Waiting for authorization…").font(.caption).foregroundStyle(.secondary)
                }
            case .success:
                Label("Signed in", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            case let .failed(message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.red)
            }

            if case .prompt = login.phase {} else {
                Button("Dismiss") { model.activeLogin = nil }.buttonStyle(.borderless)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Helpers

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func openURL(_ url: String) {
        if let parsed = URL(string: url) { NSWorkspace.shared.open(parsed) }
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
