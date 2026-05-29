import SwiftUI
import AWSProfileKit

/// Inline settings (visible in the detail pane, not a separate ⌘, window).
struct SettingsPanelView: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings").font(.title2.weight(.semibold))

                section("SSO Login") {
                    Picker("Browser for SSO login", selection: $model.selectedBrowserID) {
                        Text("System default").tag(String?.none)
                        Divider()
                        ForEach(model.browsers) { browser in
                            Text(browser.name).tag(Optional(browser.id))
                        }
                    }
                    .pickerStyle(.menu)
                    Text("The SSO authorization page opens in this browser when you refresh a profile. “System default” lets the AWS CLI use the macOS default browser.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                section("Sync") {
                    Text("The app tracks which profiles it manages and flags ones changed, removed, or broken outside the app.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Adopt current config as baseline") { model.adoptAll() }
                        .help("Records every current profile as “in sync”, clearing modified/untracked flags.")
                }
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .navigationTitle("Settings")
        .onAppear { model.refreshBrowsers() }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
