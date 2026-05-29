import SwiftUI
import AWSProfileKit

struct ContentView: View {
    let viewModel: ProfileViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }
            profileList
        }
        .frame(minWidth: 460, minHeight: 420)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.reload()
                } label: {
                    Label("Recargar", systemImage: "arrow.clockwise")
                }
                .help("Releer ~/.aws/config y el estado de los tokens")
            }
        }
        .onAppear { viewModel.reload() }
    }

    private var profileList: some View {
        List {
            ForEach(viewModel.groups) { resolved in
                Section {
                    ForEach(resolved.group.profiles) { profile in
                        ProfileRowView(
                            profile: profile,
                            isDefault: profile.name == viewModel.defaultProfileName,
                            onMakeDefault: { viewModel.makeDefault(profileNamed: profile.name) }
                        )
                    }
                } header: {
                    sectionHeader(for: resolved)
                }
            }
        }
        .listStyle(.inset)
    }

    private func sectionHeader(for resolved: LoadProfileGroups.ResolvedGroup) -> some View {
        HStack(spacing: 10) {
            Text(resolved.group.sessionName ?? "Sin sesión SSO")
                .font(.headline)
            SessionStatusBadge(status: resolved.tokenStatus)
            Spacer()
            if let sessionName = resolved.group.sessionName {
                refreshButton(sessionName: sessionName)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func refreshButton(sessionName: String) -> some View {
        let busy = viewModel.isRefreshing(sessionNamed: sessionName)
        Button {
            Task { await viewModel.refresh(sessionNamed: sessionName) }
        } label: {
            if busy {
                ProgressView().controlSize(.small)
            } else {
                Label("Login / Refresh", systemImage: "globe")
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(busy)
        .help("Lanza `aws sso login --sso-session \(sessionName)` y abre el browser")
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.callout)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(10)
        .background(Color.orange.opacity(0.12))
    }
}
