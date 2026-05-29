import SwiftUI
import AppKit
import AWSProfileKit

/// Shows the SSO verification URL and code during a `--no-browser` login, with
/// copy buttons and the raw CLI output as a fallback.
struct LoginPromptView: View {
    @Bindable var model: AppModel
    @State private var copiedCode = false
    @State private var showRawOutput = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline)

            switch model.activeLogin?.phase {
            case .starting, .none:
                ProgressView("Starting sign-in…")
                    .frame(maxWidth: .infinity, alignment: .center)
            case let .prompt(prompt):
                promptBody(prompt)
            case .success:
                statusLine("Signed in successfully.", icon: "checkmark.circle.fill", color: .green)
            case let .failed(message):
                statusLine(message, icon: "exclamationmark.triangle.fill", color: .red)
            }

            Divider()
            HStack {
                Spacer()
                Button(isDone ? "Done" : "Close") { model.activeLogin = nil }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 540)
    }

    private var title: String {
        "SSO Login — \(model.activeLogin?.profileName ?? "")"
    }

    private var isDone: Bool {
        switch model.activeLogin?.phase {
        case .success, .failed: return true
        default: return false
        }
    }

    @ViewBuilder
    private func promptBody(_ prompt: LoginPrompt) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Confirm this code in your browser, then approve the request:")
                .font(.callout).foregroundStyle(.secondary)

            if let code = prompt.userCode {
                HStack(spacing: 12) {
                    Text(code)
                        .font(.system(.title, design: .monospaced).weight(.bold))
                        .textSelection(.enabled)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    Button {
                        copy(code); copiedCode = true
                    } label: {
                        Label(copiedCode ? "Copied" : "Copy code", systemImage: copiedCode ? "checkmark" : "doc.on.doc")
                    }
                }
            } else {
                Text("No code detected — check the output below and copy it manually.")
                    .font(.callout).foregroundStyle(.orange)
            }

            if let url = prompt.verificationURL {
                HStack(spacing: 8) {
                    Text(url).font(.caption).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                    Spacer()
                    Button("Copy URL") { copy(url) }
                    Button("Open") { openInBrowser(url) }
                }
            }

            DisclosureGroup("CLI output", isExpanded: $showRawOutput) {
                ScrollView {
                    Text(prompt.rawOutput.isEmpty ? "(waiting…)" : prompt.rawOutput)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 120)
            }

            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Waiting for authorization…").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func statusLine(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .foregroundStyle(color)
            .textSelection(.enabled)
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func openInBrowser(_ url: String) {
        guard let parsed = URL(string: url) else { return }
        NSWorkspace.shared.open(parsed)
    }
}
