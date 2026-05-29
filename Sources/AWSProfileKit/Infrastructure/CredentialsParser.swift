import Foundation

/// Parses `~/.aws/credentials`, where each section header is the bare profile
/// name (no `profile ` prefix) and holds static access keys.
struct CredentialsParser {
    struct Entry: Equatable {
        let accessKeyId: String?
        let secretAccessKey: String?
        let sessionToken: String?
    }

    func parse(_ text: String) -> [String: Entry] {
        let document = INIDocument(text)
        var result: [String: Entry] = [:]
        for section in document.sections {
            let name = section.rawHeader
            result[name] = Entry(
                accessKeyId: section.value(for: "aws_access_key_id"),
                secretAccessKey: section.value(for: "aws_secret_access_key"),
                sessionToken: section.value(for: "aws_session_token")
            )
        }
        return result
    }
}
