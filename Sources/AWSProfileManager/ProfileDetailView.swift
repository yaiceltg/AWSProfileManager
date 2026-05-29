import SwiftUI
import AWSProfileKit

struct ProfileDetailView: View {
    @Bindable var model: AppModel
    let profile: Profile
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let error = model.errorMessage { errorBanner(error) }
                details
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(profile.name)
        .toolbar {
            ToolbarItemGroup {
                Button { Task { await model.refresh(profileNamed: profile.name) } } label: {
                    Label("Refresh", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(model.refreshingProfiles.contains(profile.name) || !profile.isSSO)
            }
        }
        .alert("Delete \(profile.name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { model.delete(profileNamed: profile.name) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the profile from ~/.aws/config and ~/.aws/credentials. A backup is written first.")
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(profile.name).font(.title2.weight(.semibold))
                if model.defaultProfileName == profile.name {
                    tag("DEFAULT", color: .accentColor)
                }
                if profile.isSSO {
                    SessionStatusBadge(status: model.tokenStatus(for: profile))
                }
                DriftBadge(status: model.drift(for: profile.name))
            }

            HStack(spacing: 10) {
                if profile.isSSO {
                    Button {
                        Task { await model.refresh(profileNamed: profile.name) }
                    } label: {
                        if model.refreshingProfiles.contains(profile.name) {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Login / Refresh", systemImage: "globe")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.refreshingProfiles.contains(profile.name))
                }

                if model.defaultProfileName != profile.name {
                    Button("Make Default") { model.makeDefault(profileNamed: profile.name) }
                }
                Button {
                    Task { await model.verify(profileNamed: profile.name) }
                } label: {
                    if case .verifying = model.identity(for: profile.name) {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Verify")
                    }
                }
                .help("Run aws sts get-caller-identity to confirm the session")
                Button("Edit") { model.beginEdit(profileNamed: profile.name) }
                Button("Delete", role: .destructive) { confirmingDelete = true }
            }
        }
    }

    // MARK: Details

    private var details: some View {
        VStack(alignment: .leading, spacing: 18) {
            if profile.isSSO {
                section("SSO") {
                    field("Account ID", profile.accountId)
                    field("Role", profile.roleName)
                    field("Region", profile.region)
                    field("SSO start URL", profile.ssoStartURL)
                    field("SSO region", profile.ssoRegion)
                    field("SSO session", profile.ssoSessionName)
                }
            }
            if profile.hasStaticCredentials || profile.sessionToken != nil {
                section("Credentials") {
                    secretField("Access key ID", profile.accessKeyId)
                    secretField("Secret access key", profile.secretAccessKey)
                    secretField("Session token", profile.sessionToken)
                }
            }
            if let state = model.identity(for: profile.name) {
                identitySection(state)
            }
        }
    }

    @ViewBuilder
    private func identitySection(_ state: AppModel.VerifyState) -> some View {
        section("Identity (live)") {
            switch state {
            case .verifying:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Checking…").foregroundStyle(.secondary)
                }
                .font(.callout)
            case let .failed(message):
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red).font(.callout).textSelection(.enabled)
            case let .ok(identity):
                field("Account", identity.account)
                field("Type", identity.identityType)
                if identity.roleName != nil { field("Role", identity.roleName) }
                if identity.sessionName != nil { field("Session", identity.sessionName) }
                field("ARN", identity.arn)
                field("User ID", identity.userId)
                if identity.partition != nil { field("Partition", identity.partition) }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 6) { content() }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func field(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary).frame(width: 130, alignment: .leading)
            Text(value ?? "—").textSelection(.enabled)
            Spacer()
        }
        .font(.callout)
    }

    /// Masks secret values: shows presence, never the value.
    private func secretField(_ label: String, _ value: String?) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.secondary).frame(width: 130, alignment: .leading)
            Text(value?.isEmpty == false ? "•••••••• (set)" : "—")
                .foregroundStyle(value?.isEmpty == false ? .primary : .secondary)
            Spacer()
        }
        .font(.callout)
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.orange)
            .textSelection(.enabled)
    }
}
