import Foundation

/// The generative route: any OpenAI-compatible /chat/completions endpoint.
/// Drafts the 3 candidate replies. Ported from ReplyClient.kt (prompts verbatim).
struct ReplyClient {
    var config: ChannelConfig
    var key: String

    func draft(messages: [ChatMessage], relationship: String, background: String = "", history: [ChatMessage] = [], count: Int = 3, avoid: [String] = []) async throws -> [String] {
        let n = min(max(count, 1), 3)
        let convo = messages.suffix(10).map { ($0.speaker == .me ? "我" : "对方") + "：" + $0.text }.joined(separator: "\n")
        let sys = "你是即时通讯回复助手。只输出一个 JSON 数组，含且仅含 \(n) 条候选回复文本，"
            + (n > 1 ? "各条策略要有区别（例如：一条稳妥承接、一条给具体行动或承诺、一条简短低姿态）。" : "给出最稳妥、最自然的一条。")
            + "回复语言跟随对方最近一条消息：对方用英文就用自然的英文回复，用中文就用中文回复。"
            + "每条不超过 40 字（英文不超过 30 个单词），口语、自然、像真人在聊天软件里发消息。不要解释，不要加引号以外的内容，直接输出 JSON 数组。"
        var user = ""
        if !background.isEmpty || !history.isEmpty {
            user += "以下是关于我和对方的背景与知识库，回复必须与之一致，可以直接引用其中事实，不要编造知识库里没有的事实。\n"
            if !background.isEmpty { user += background + "\n" }
            if !history.isEmpty {
                user += "\n更早的聊天记录（越靠下越新）：\n"
                for m in history.suffix(30) {
                    user += (m.speaker == .me ? "我：" : "对方：") + m.text + "\n"
                }
            }
            user += "\n"
        }
        user += "关系：\(relationship)\n\n最近对话：\n\(convo)\n\n"
        if !avoid.isEmpty {
            user += "下面这些回复已经给过，不要重复，也不要只是换个说法：\n"
                + avoid.map { "- \($0)" }.joined(separator: "\n") + "\n\n"
        }
        user += "请给出 \(n) 条候选回复。"
        let content = try await chat(system: sys, user: user, temperature: avoid.isEmpty ? 0.8 : 0.95)
        return Self.parseN(content, n: n)
    }

    /// One plain chat round trip for the settings connectivity test.
    func ping() async throws -> String {
        try await chat(system: "你是连通性测试助手，只按要求回答，不要解释。", user: "请只回复两个字：收到", temperature: 0.0)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func chat(system: String, user: String, temperature: Double) async throws -> String {
        let base = config.baseURL.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let url = base + "/chat/completions"
        let body: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "temperature": temperature,
            "stream": false,
        ]
        let resp = try await HttpJson.post(url: url, key: key, body: body, route: "回复接口")
        let choices = resp["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return message?["content"] as? String ?? ""
    }

    /// Up to n non-blank replies; fewer when the model gave fewer.
    static func parseN(_ content: String, n: Int) -> [String] {
        if let start = content.firstIndex(of: "["), let end = content.lastIndex(of: "]"), start < end {
            let slice = String(content[start...end])
            if let data = slice.data(using: .utf8),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                let out = arr.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                if !out.isEmpty { return Array(out.prefix(n)) }
            }
        }
        let lines = content.split(separator: "\n")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "-*123. \"")) }
            .filter { !$0.isEmpty && $0 != "[" && $0 != "]" }
        return Array(lines.prefix(n))
    }
}
