import Foundation

/// `ConsoleSignInService` using AWS's federation endpoint.
///
/// Flow: build a session JSON from the credentials → GET `getSigninToken` →
/// build the `login` URL with the returned token. Base64 tokens contain
/// `+`/`/`/`=`, which standard query encoding leaves alone, so values are
/// percent-encoded against an alphanumerics-only set.
public struct AWSConsoleFederation: ConsoleSignInService {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func signInURL(for credentials: TemporaryCredentials, region: String?) async throws -> URL {
        guard let token = credentials.sessionToken, !token.isEmpty else {
            throw ConsoleSignInError.requiresTemporaryCredentials
        }

        let sessionJSON = Self.sessionJSON(credentials: credentials, sessionToken: token)
        guard let tokenURL = Self.getSigninTokenURL(sessionJSON: sessionJSON) else {
            throw ConsoleSignInError.federationFailed
        }

        let (data, response) = try await session.data(from: tokenURL)
        guard
            let http = response as? HTTPURLResponse, http.statusCode == 200,
            let signinToken = Self.parseSigninToken(data),
            let url = URL(string: Self.loginURL(signinToken: signinToken, destination: Self.destination(region: region)))
        else {
            throw ConsoleSignInError.federationFailed
        }
        return url
    }

    // MARK: - Pure helpers (testable)

    static func sessionJSON(credentials: TemporaryCredentials, sessionToken: String) -> String {
        let object: [String: String] = [
            "sessionId": credentials.accessKeyId,
            "sessionKey": credentials.secretAccessKey,
            "sessionToken": sessionToken
        ]
        guard
            let data = try? JSONSerialization.data(withJSONObject: object),
            let json = String(data: data, encoding: .utf8)
        else { return "{}" }
        return json
    }

    /// Percent-encodes against alphanumerics only, so `+`, `/`, `=` are escaped.
    static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
    }

    static func getSigninTokenURL(sessionJSON: String) -> URL? {
        URL(string: "https://signin.aws.amazon.com/federation?Action=getSigninToken&Session=\(encode(sessionJSON))")
    }

    static func parseSigninToken(_ data: Data) -> String? {
        struct Response: Decodable { let SigninToken: String }
        return (try? JSONDecoder().decode(Response.self, from: data))?.SigninToken
    }

    static func destination(region: String?) -> String {
        if let region, !region.isEmpty {
            return "https://console.aws.amazon.com/console/home?region=\(region)"
        }
        return "https://console.aws.amazon.com/"
    }

    static func loginURL(signinToken: String, destination: String) -> String {
        let issuer = "https://github.com/yaiceltg/AWSProfileManager"
        return "https://signin.aws.amazon.com/federation"
            + "?Action=login"
            + "&Issuer=\(encode(issuer))"
            + "&Destination=\(encode(destination))"
            + "&SigninToken=\(encode(signinToken))"
    }
}
