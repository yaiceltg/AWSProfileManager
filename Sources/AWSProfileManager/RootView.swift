import SwiftUI
import AWSProfileKit

/// Top-level PortKiller-style layout: sidebar + detail, with the add/edit and
/// login sheets and the main toolbar.
struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } detail: {
            DetailContainer(model: model)
                .navigationSplitViewColumnWidth(min: 420, ideal: 520)
        }
        .searchable(text: $model.searchText, placement: .sidebar, prompt: "Search profiles")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { model.beginAdd() } label: {
                    Label("Add Profile", systemImage: "plus")
                }
                .help("Create a new profile")

                Button { model.reload() } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .help("Re-read ~/.aws and token status")
            }
        }
        .sheet(item: $model.editing) { form in
            ProfileFormView(model: model, form: form)
        }
        .sheet(item: $model.activeLogin) { _ in
            LoginPromptView(model: model)
        }
        .onAppear { model.reload() }
        .frame(minWidth: 760, minHeight: 480)
    }
}

/// Routes the detail pane based on the current sidebar selection.
struct DetailContainer: View {
    @Bindable var model: AppModel

    var body: some View {
        switch model.selection {
        case let .profile(name):
            if let profile = model.profile(named: name) {
                ProfileDetailView(model: model, profile: profile)
            } else {
                ContentUnavailableView("Profile not found", systemImage: "questionmark.folder")
            }
        case .settings:
            SettingsPanelView(model: model)
        case nil:
            ContentUnavailableView(
                "Select a profile",
                systemImage: "person.crop.circle",
                description: Text("Pick a profile on the left, or add a new one.")
            )
        }
    }
}
