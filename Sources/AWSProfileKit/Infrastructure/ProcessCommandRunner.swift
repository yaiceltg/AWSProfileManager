import Foundation

/// `AWSCommandRunner` that shells out to the real `aws` binary via `Process`.
///
/// Always runs `aws sso login --profile <name> --no-browser`, streams the
/// combined output to scrape the authorization URL and verification code,
/// surfaces them through `onPrompt`, and opens the URL with `open` (in the
/// chosen browser via `-a`, or the system default). The CLI keeps waiting on
/// its localhost callback until the user authorizes.
public struct ProcessCommandRunner: AWSCommandRunner {
    private let binaryPath: String?

    public init(binaryPath: String? = nil) {
        self.binaryPath = binaryPath
    }

    public func login(
        profileNamed name: String,
        browser: BrowserChoice?,
        onPrompt: @escaping @Sendable (LoginPrompt) -> Void
    ) async throws {
        guard let binary = binaryPath ?? AWSPaths.resolveAWSBinary() else {
            throw AWSCommandError.binaryNotFound
        }
        let appPath = browser?.appPath

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try Self.run(binary: binary, profile: name, browserAppPath: appPath, onPrompt: onPrompt)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func callerIdentity(profileNamed name: String) async throws -> CallerIdentity {
        guard let binary = binaryPath ?? AWSPaths.resolveAWSBinary() else {
            throw AWSCommandError.binaryNotFound
        }

        let json = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: binary)
                process.arguments = ["sts", "get-caller-identity", "--profile", name, "--output", "json"]

                var environment = ProcessInfo.processInfo.environment
                let existingPath = environment["PATH"] ?? ""
                environment["PATH"] = existingPath.isEmpty ? "/usr/bin:/bin" : existingPath + ":/usr/bin:/bin"
                process.environment = environment

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: AWSCommandError.binaryNotFound)
                    return
                }

                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    continuation.resume(returning: String(data: outData, encoding: .utf8) ?? "")
                } else {
                    let stderr = String(data: errData, encoding: .utf8) ?? ""
                    continuation.resume(throwing: AWSCommandError.nonZeroExit(
                        code: process.terminationStatus,
                        stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
            }
        }

        guard let identity = CallerIdentity(json: json) else {
            throw AWSCommandError.nonZeroExit(code: 0, stderr: "Could not parse get-caller-identity output.")
        }
        return identity
    }

    private static func run(
        binary: String,
        profile: String,
        browserAppPath: String?,
        onPrompt: @Sendable (LoginPrompt) -> Void
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["sso", "login", "--profile", profile, "--no-browser"]

        var environment = ProcessInfo.processInfo.environment
        let existingPath = environment["PATH"] ?? ""
        environment["PATH"] = existingPath.isEmpty ? "/usr/bin:/bin" : existingPath + ":/usr/bin:/bin"
        process.environment = environment

        // Merge stdout+stderr so the URL/code are caught regardless of stream.
        let combined = Pipe()
        process.standardOutput = combined
        process.standardError = combined

        do {
            try process.run()
        } catch {
            throw AWSCommandError.binaryNotFound
        }

        let handle = combined.fileHandleForReading
        var accumulated = ""
        var opened = false
        var reportedCode: String?

        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break } // EOF
            accumulated += String(data: chunk, encoding: .utf8) ?? ""

            let url = extractAuthorizationURL(from: accumulated)
            let code = extractUserCode(from: accumulated)

            if let url, !opened {
                onPrompt(LoginPrompt(verificationURL: url, userCode: code, rawOutput: accumulated))
                openURL(url, inAppAt: browserAppPath)
                opened = true
                reportedCode = code
            } else if opened, reportedCode == nil, let code {
                // Code arrived on a later line than the URL.
                onPrompt(LoginPrompt(
                    verificationURL: extractAuthorizationURL(from: accumulated),
                    userCode: code,
                    rawOutput: accumulated
                ))
                reportedCode = code
            }
        }

        process.waitUntilExit()
        guard process.terminationStatus != 0 else { return }
        throw AWSCommandError.nonZeroExit(
            code: process.terminationStatus,
            stderr: accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func openURL(_ url: String, inAppAt appPath: String?) {
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = appPath.map { ["-a", $0, url] } ?? [url]
        try? open.run()
        open.waitUntilExit()
    }

    // MARK: - Output parsing

    /// Pulls the SSO authorization URL out of the CLI's `--no-browser` output.
    static func extractAuthorizationURL(from text: String) -> String? {
        let urls = text
            .components(separatedBy: .whitespacesAndNewlines)
            .compactMap { token -> String? in
                guard let range = token.range(of: "https://") else { return nil }
                return trimTrailingPunctuation(String(token[range.lowerBound...]))
            }
        guard !urls.isEmpty else { return nil }
        // Prefer the autofill URL (carries ?user_code=…) so the user doesn't
        // have to type the code into the browser.
        if let autofill = urls.first(where: { $0.lowercased().contains("user_code") }) {
            return autofill
        }
        let preferred = urls.first { candidate in
            let lower = candidate.lowercased()
            return lower.contains("authorize") || lower.contains("oidc")
                || lower.contains("device") || lower.contains("amazonaws")
                || lower.contains("awsapps")
        }
        return preferred ?? urls.first
    }

    /// Matches an SSO device/confirmation code like `ABCD-EFGH`.
    static func extractUserCode(from text: String) -> String? {
        text.range(of: "[A-Z0-9]{4}-[A-Z0-9]{4}", options: .regularExpression)
            .map { String(text[$0]) }
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
