import Foundation

// MARK: - Official Build marker

/// Tells an Official Build apart from a source build (Issue238, DISTRIBUTION-TERMS.md §1(b)).
/// The marker is bundled into Contents/Resources/Official/ only when the build phase
/// "Official Build Components" runs with FSNIPPET_OFFICIAL_BUILD=YES. The Apache-licensed code
/// here only reports what the bundle carries — it never claims official status by itself.
enum OfficialBuild {
    static let markerFileName = "official-build.txt"

    /// First non-blank line of the marker in `officialDirectory`, or nil when there is no marker.
    static func banner(officialDirectory: URL?) -> String? {
        guard let url = officialDirectory?.appendingPathComponent(markerFileName),
              FileManager.default.fileExists(atPath: url.path),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }

    /// Banner of the running bundle (nil for source builds).
    static var current: String? {
        banner(officialDirectory: Bundle.main.resourceURL?.appendingPathComponent("Official"))
    }
}
