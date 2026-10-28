import Foundation

/// Candidates shared from the main app to the Jev keyboard extension through
/// an App Group. The keyboard can only insert text into the host app's text
/// field; it cannot read the conversation, so generation stays in the app
/// and the keyboard picks up the latest ranked candidates from here.
enum SharedCandidates {
    static let suiteName = "group.com.jev.ios"
    static let key = "latest_candidates"

    static func save(_ texts: [String]) {
        UserDefaults(suiteName: suiteName)?.set(texts, forKey: key)
    }

    static func load() -> [String] {
        UserDefaults(suiteName: suiteName)?.stringArray(forKey: key) ?? []
    }
}
