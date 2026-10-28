import Foundation

/// Copy of the app-side SharedCandidates (Sources/Jev/Shared.swift): the
/// keyboard target compiles its own copy so both sides read the same
/// App Group defaults suite.
enum SharedCandidates {
    static let suiteName = "group.com.jev.ios"
    static let key = "latest_candidates"

    static func load() -> [String] {
        UserDefaults(suiteName: suiteName)?.stringArray(forKey: key) ?? []
    }
}
