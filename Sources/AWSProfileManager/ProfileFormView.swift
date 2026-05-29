import SwiftUI
import AWSProfileKit

/// Add/edit sheet. SSO fields drive the deduped sso-session; credential fields
/// are written to ~/.aws/credentials. The name is fixed when editing.
struct ProfileFormView: View {
    @Bindable var model: AppModel
    @Bindable var form: ProfileFormModel

    var body: some View {
        VStack(spacing: 0) {
            Text(form.isNew ? "New Profile" : "Edit Profile")
                .font(.headline)
                .padding(.top, 16)

            Form {
                Section {
                    TextField("Profile name", text: $form.name)
                        .disabled(!form.isNew)
                        .help(form.isNew ? "The config key, e.g. fantaz-dev" : "Renaming isn't supported; delete and recreate instead.")

                    HStack(spacing: 6) {
                        TextField("Group", text: $form.group, prompt: Text("Automatic (by name prefix)"))
                        Menu {
                            ForEach(model.existingGroups, id: \.self) { group in
                                Button(group) { form.group = group }
                            }
                            if !model.existingGroups.isEmpty { Divider() }
                            Button("Automatic (by prefix)") { form.group = "" }
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .help("Choose an existing group or type a new one")
                    }
                } header: {
                    Text("Identity")
                } footer: {
                    Text("Group is an app-only label (stored in the manifest, not the config). Leave empty to group automatically by name prefix.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section {
                    TextField("SSO start URL", text: $form.ssoStartURL, prompt: Text("https://my-org.awsapps.com/start"))
                    TextField("SSO region", text: $form.ssoRegion, prompt: Text("us-east-1"))
                    TextField("Account ID", text: $form.accountId)
                    TextField("Role name", text: $form.roleName, prompt: Text("AWSAdministratorAccess"))
                    TextField("Default region", text: $form.region, prompt: Text("us-east-1"))
                } header: {
                    Text("SSO")
                } footer: {
                    Text("Start URL + region are required to refresh via SSO. Profiles sharing a start URL share one sso-session.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section {
                    TextField("Access key ID", text: $form.accessKeyId)
                    SecureField("Secret access key", text: $form.secretAccessKey)
                    SecureField("Session token", text: $form.sessionToken)
                } header: {
                    Text("Static credentials (optional)")
                } footer: {
                    Text("Written to ~/.aws/credentials with 0600 permissions. Leave blank for SSO-only profiles.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { model.editing = nil }
                    .keyboardShortcut(.cancelAction)
                Button(form.isNew ? "Create" : "Save") { model.save(form: form) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!form.isValid)
            }
            .padding(16)
        }
        .frame(width: 500, height: 600)
    }
}
