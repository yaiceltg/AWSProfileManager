import Foundation

/// `ManifestStore` backed by a JSON file under Application Support.
public struct JSONManifestStore: ManifestStore {
    private let fileURL: URL

    /// - Parameter fileURL: override for tests; defaults to
    ///   `~/Library/Application Support/AWSProfileManager/manifest.json`.
    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first ?? FileManager.default.temporaryDirectory
            self.fileURL = base
                .appendingPathComponent("AWSProfileManager", isDirectory: true)
                .appendingPathComponent("manifest.json", isDirectory: false)
        }
    }

    public func load() -> ProfileManifest {
        guard
            let data = try? Data(contentsOf: fileURL),
            let manifest = try? JSONDecoder().decode(ProfileManifest.self, from: data)
        else {
            return ProfileManifest()
        }
        return manifest
    }

    public func save(_ manifest: ProfileManifest) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(manifest) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}
