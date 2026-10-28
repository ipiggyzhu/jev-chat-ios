import Foundation
import SwiftUI

/// App-wide state: channel configs (non-secret parts in UserDefaults,
/// keys in Keychain), knowledge base, contacts, and per-contact history.
@MainActor
final class AppState: ObservableObject {
    // Channel configs
    @Published var judge: JudgeConfig {
        didSet { saveCodable(judge, key: "judge_config") }
    }
    @Published var reply: ChannelConfig {
        didSet { saveCodable(reply, key: "reply_config") }
    }
    @Published var vision: ChannelConfig {
        didSet { saveCodable(vision, key: "vision_config") }
    }

    // Knowledge base & contacts (JSON file in Documents)
    @Published var notes: [Note] = [] { didSet { saveKB() } }
    @Published var contacts: [Contact] = [] { didSet { saveKB() } }

    // Chat history per contact name (opt-in, local only), mirrors the original.
    @Published var recordHistory: Bool = UserDefaults.standard.bool(forKey: "record_history") {
        didSet { UserDefaults.standard.set(recordHistory, forKey: "record_history") }
    }
    @Published var historyCount: Int = {
        let v = UserDefaults.standard.integer(forKey: "history_count")
        return v == 0 ? 30 : v
    }() {
        didSet { UserDefaults.standard.set(historyCount, forKey: "history_count") }
    }

    init() {
        judge = Self.loadCodable("judge_config") ?? JudgeConfig()
        reply = Self.loadCodable("reply_config") ?? ChannelConfig(baseURL: Presets.replyBase, model: Presets.replyModel)
        vision = Self.loadCodable("vision_config") ?? ChannelConfig(baseURL: Presets.replyBase, model: "qwen/qwen2.5-vl-72b-instruct")
        loadKB()
    }

    // MARK: - Keys (Keychain, with the original fallback chain)

    var judgeKey: String {
        get { Keychain.get("judge_key") }
        set { Keychain.set(newValue, account: "judge_key"); objectWillChange.send() }
    }
    var replyKey: String {
        get { Keychain.get("reply_key") }
        set { Keychain.set(newValue, account: "reply_key"); objectWillChange.send() }
    }
    var visionKey: String {
        get { Keychain.get("vision_key") }
        set { Keychain.set(newValue, account: "vision_key"); objectWillChange.send() }
    }
    var effectiveReplyKey: String { replyKey.isEmpty ? judgeKey : replyKey }
    var effectiveVisionKey: String { visionKey.isEmpty ? effectiveReplyKey : visionKey }

    // MARK: - Knowledge context

    /// Build the background string for a conversation, mirroring the original
    /// rules: relationship + matched contact + pinned notes + notes whose tag
    /// or title appears in the recent messages (max 5 notes).
    func background(relationship: String, contact: Contact?, messages: [ChatMessage]) -> String {
        var parts: [String] = []
        if !relationship.isEmpty { parts.append("关系背景：\(relationship)") }
        if let c = contact {
            parts.append("联系人：\(c.name)" + (c.relationship.isEmpty ? "" : "（\(c.relationship)）"))
            if !c.remark.isEmpty { parts.append("联系人备注：\(c.remark)") }
        }
        let recentText = messages.suffix(6).map { $0.text }.joined(separator: "\n")
        var included: [Note] = []
        for note in notes where note.pinned { included.append(note) }
        for note in notes where !note.pinned {
            if included.count >= 5 { break }
            let tags = note.tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if recentText.contains(note.title) || tags.contains(where: { !$0.isEmpty && recentText.contains($0) }) {
                included.append(note)
            }
        }
        for note in included.prefix(5) {
            parts.append("笔记《\(note.title)》：\(note.content)")
        }
        return parts.joined(separator: "\n")
    }

    func matchContact(title: String) -> Contact? {
        let t = title.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty else { return nil }
        return contacts.first { c in
            if t.contains(c.name.lowercased()) { return true }
            return c.aliases.split(separator: "\n").contains { t.contains($0.trimmingCharacters(in: .whitespaces).lowercased()) }
        }
    }

    // MARK: - History (local JSON, one array per contact name)

    func history(for contactName: String) -> [ChatMessage] {
        guard recordHistory, !contactName.isEmpty else { return [] }
        let all = Self.loadCodable("history_all") ?? [String: [ChatMessage]]()
        return all[contactName] ?? []
    }

    func appendHistory(contactName: String, messages: [ChatMessage]) {
        guard recordHistory, !contactName.isEmpty else { return }
        var all = Self.loadCodable("history_all") ?? [String: [ChatMessage]]()
        var existing = all[contactName] ?? []
        // De-duplicate against what is already shown in the current snippet.
        let shown = Set(messages.map { $0.text })
        existing.removeAll { shown.contains($0.text) }
        all[contactName] = existing + messages
        saveCodable(all, key: "history_all")
    }

    func clearKnowledgeAndHistory() {
        notes = []
        contacts = []
        saveCodable([String: [ChatMessage]](), key: "history_all")
    }

    // MARK: - Persistence helpers

    private static func loadCodable<T: Codable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func saveCodable<T: Codable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private struct KBFile: Codable {
        var notes: [Note]
        var contacts: [Contact]
    }

    private func kbURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("knowledge.json")
    }

    private func loadKB() {
        guard let data = try? Data(contentsOf: kbURL()),
              let kb = try? JSONDecoder().decode(KBFile.self, from: data) else { return }
        notes = kb.notes
        contacts = kb.contacts
    }

    private func saveKB() {
        let kb = KBFile(notes: notes, contacts: contacts)
        if let data = try? JSONEncoder().encode(kb) {
            try? data.write(to: kbURL(), options: .atomic)
        }
    }
}
