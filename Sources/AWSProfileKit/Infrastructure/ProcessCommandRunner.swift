import Foundation

/// `AWSCommandRunner` that shells out to the real `aws` binary via `Process`.
///
/// Two flows:
/// - System default browser → `aws sso login --sso-session X` (CLI opens it).
/// - Specific browser → `aws sso login --sso-session X --no-browser`; the runner
///   scrapes the authorization URL from the CLI's output and opens it with
///   `open -a <app>`, while the CLI keeps waiting on its localhost callback.
public struct ProcessCommandRunner: AWSCommandRunner {
    /// Explicit binary path; when nil it is resolved from known locations.
    private let binaryPath: String?

    public init(binaryPath: String? = nil) {
        self.binaryPath = binaryPath
    }

    public func login(ssoSessionNamed name: String, browser: BrowserChoice?) async throws {
        guard let binary = binaryPath ?? AWSPaths.resolveAWSBinary() else {
            throw AWSCommandError.binaryNotFound
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            // Process/Pipe are not Sendable, so everything stays on this queue;
            // only `continuation` and value-type inputs cross the boundary.
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    if let browser {
                        try Self.runCapturingBrowser(binary: binary, session: name, browser: browser)
                    } else {
                        try Self.runDefaultBrowser(binary: binary, session: name)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Flows

    private static func runDefaultBrowser(binary: String, session: String) throws {
        let process = makeProcess(binary: binary, arguments: ["sso", "login", "--sso-session", session])
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()

        try run(process)
        let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try throwIfFailed(process, stderr: String(data: data, encoding: .utf8) ?? "")
    }

    private static func runCapturingBrowser(binary: String, session: String, browser: BrowserChoice) throws {
        let process = makeProcess(
            binary: binary,
            arguments: ["sso", "login", "--sso-session", session, "--no-browser"]
        )
        // Merge stdout+stderr so the URL is captured regardless of which stream
        // the CLI prints it to.
        let combined = Pipe()
        process.standardOutput = combined
        process.standardError = combined

        try run(process)

        let handle = combined.fileHandleForReading
        var accumulated = ""
        var opened = false
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break } // EOF
            accumulated += String(data: chunk, encoding: .utf8) ?? ""
            if !opened, let url = extractAuthorizationURL(from: accumulated) {
                openURL(url, inAppAt: browser.appPath)
                opened = true
            }
        }
        process.waitUntilExit()
        // Exit 0 without a URL means the token was already valid — not an error.
        try throwIfFailed(process, stderr: accumulated)
    }

    // MARK: - Process helpers

    private static func makeProcess(binary: String, arguments: [String]) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments

        // A GUI app has a minimal PATH; ensure the CLI and `open` reach helpers.
        var environment = ProcessInfo.processInfo.environment
        let existingPath = environment["PATH"] ?? ""
        environment["PATH"] = existingPath.isEmpty
            ? "/usr/bin:/bin"
            : existingPath + ":/usr/bin:/bin"
        process.environment = environment
        return process
    }

    private static func run(_ process: Process) throws {
        do {
            try process.run()
        } catch {
            throw AWSCommandError.binaryNotFound
        }
    }

    private static func throwIfFailed(_ process: Process, stderr: String) throws {
        guard process.terminationStatus != 0 else { return }
        throw AWSCommandError.nonZeroExit(
            code: process.terminationStatus,
            stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func openURL(_ url: String, inAppAt appPath: String) {
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-a", appPath, url]
        try? open.run()
        open.waitUntilExit()
    }

    // MARK: - URL extraction

    /// Pulls the SSO authorization URL out of the CLI's `--no-browser` output.
    /// Prefers an AWS auth URL when several links appear; trims trailing
    /// punctuation that may follow the URL in prose.
    static func extractAuthorizationURL(from text: String) -> String? {
        let separators = CharacterSet.whitespacesAndNewlines
        let urls = text
            .components(separatedBy: separators)
            .compactMap { token -> String? in
                // Extract from "https://" onward so leading punctuation
                // (e.g. an opening paren) doesn't disqualify the token.
                guard let range = token.range(of: "https://") else { return nil }
                return trimTrailingPunctuation(String(token[range.lowerBound...]))
            }

        guard !urls.isEmpty else { return nil }
        let preferred = urls.first { candidate in
            let lower = candidate.lowercased()
            return lower.contains("authorize")
                || lower.contains("oidc")
                || lower.contains("user_code")
                || lower.contains("device")
                || lower.contains("amazonaws")
        }
        return preferred ?? urls.first
    }

    private static func trimTrailingPunctuation(_ value: String) -> String {
        let trailing: Set<Character> = [".", ",", ")", "]", ">", "\"", "'"]
        var result = value
        while let last = result.last, trailing.contains(last) {
            result.removeLast()
        }
        return result
    }
}
