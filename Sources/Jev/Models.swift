import Foundation

enum Speaker: String, Codable {
    case me
    case them

    var label: String { self == .me ? "我" : "对方" }
    /// Wire value in the Jev decisions protocol state.
    var wire: String { self == .me ? "me" : "other" }
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var speaker: Speaker
    var text: String

    mutating func flip() {
        speaker = (speaker == .me) ? .them : .me
    }
}

/// Mirrors the original Analysis: choices carry a probability distribution,
/// scores carry value + confidence, noul questions carry a 0-1 probability.
struct ChoiceAnswer: Codable, Equatable {
    var choice: String = ""
    var confidence: Double = 0
    var probabilities: [String: Double] = [:]
}

struct Analysis: Codable, Equatable {
    var trueIntent: ChoiceAnswer = ChoiceAnswer()
    var dangerScore: Double = 0
    var dangerConfidence: Double = 0
    var sheNeeds: ChoiceAnswer = ChoiceAnswer()
    var shouldReplyNow: Double = 0       // noul probability
    var bestAction: ChoiceAnswer = ChoiceAnswer()
    var tensionResolved: Double = 0      // noul probability
    var literalQuestion: Double = 0      // noul probability
}

struct Candidate: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var percent: Int = 0                 // ranking probability from the judge, 0-100
}

struct Note: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var content: String
    var tags: String = ""
    var pinned: Bool = false
}

struct Contact: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var aliases: String = ""
    var relationship: String = ""
    var remark: String = ""
}

enum JudgeProvider: String, Codable, CaseIterable {
    case openrouter
    case bocha
    case typesafe
    case vercel
    case zen
    case custom

    var displayName: String {
        switch self {
        case .openrouter: return "OpenRouter"
        case .bocha: return "博查 Jev"
        case .typesafe: return "TypeSafe 直连"
        case .vercel: return "Vercel"
        case .zen: return "OpenCode Zen"
        case .custom: return "自定义"
        }
    }

    func endpoint(baseURL: String) -> String {
        let base = baseURL.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch self {
        case .bocha, .typesafe, .vercel, .zen:
            return base + "/v1/systemone"
        case .custom:
            return baseURL.trimmingCharacters(in: .whitespaces)
        case .openrouter:
            return base + "/alpha/decisions"
        }
    }
}

struct JudgePreset {
    var provider: JudgeProvider
    var baseURL: String
    var model: String
}

enum Presets {
    static let judge: [JudgePreset] = [
        JudgePreset(provider: .openrouter, baseURL: "https://openrouter.ai/api", model: "typesafe/jev-1.13"),
        JudgePreset(provider: .bocha, baseURL: "https://jev.bocha.cn", model: "bocha-jev-v1"),
        JudgePreset(provider: .typesafe, baseURL: "https://api.typesafe.ai", model: "jev-latest"),
        JudgePreset(provider: .vercel, baseURL: "https://ai-gateway.vercel.sh/typesafe", model: "typesafe-ai/jev"),
        JudgePreset(provider: .zen, baseURL: "https://opencode.ai/zen", model: "jev-1.13"),
        JudgePreset(provider: .custom, baseURL: "", model: ""),
    ]

    static let replyBase = "https://openrouter.ai/api/v1"
    static let replyModel = "deepseek/deepseek-chat-v3.1"
    static let deepseekBase = "https://api.deepseek.com/v1"
    static let deepseekModel = "deepseek-chat"
    static let dashscopeBase = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    static let dashscopeModel = "qwen-plus"

    static let defaultRelationship = "对方是我的伴侣；from=me 的是我发的，from=other 的是对方发的"
}

/// Non-secret channel settings. API keys live in the Keychain, never here.
struct JudgeConfig: Codable, Equatable {
    var provider: JudgeProvider = .openrouter
    var baseURL: String = "https://openrouter.ai/api"
    var model: String = "typesafe/jev-1.13"
}

struct ChannelConfig: Codable, Equatable {
    var baseURL: String = ""
    var model: String = ""
}
