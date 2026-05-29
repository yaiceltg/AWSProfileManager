import SwiftUI
import AWSProfileKit

struct SettingsView: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        Form {
            Picker("Browser para el login SSO", selection: $model.selectedID) {
                Text("Sistema por defecto").tag(String?.none)
                Divider()
                ForEach(model.browsers) { browser in
                    Text(browser.name).tag(Optional(browser.id))
                }
            }
            .pickerStyle(.menu)

            Text("Al refrescar una sesión SSO, la página de autorización se abrirá en este browser. «Sistema por defecto» deja que el AWS CLI use el navegador predeterminado de macOS.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 160)
        .onAppear { model.reload() }
    }
}
