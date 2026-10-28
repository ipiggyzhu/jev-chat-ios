import Foundation

/// The Jev judgment route only: the 7 judgment questions in one call, and the
/// ranking question over already-drafted candidates. Ported from JudgeClient.kt.
struct JudgeClient {
    var config: JudgeConfig
    var key: String

    func judge(messages: [ChatMessage], relationship: String, background: String = "", history: [ChatMessage] = []) async throws -> Analysis {
        let answers = try await postDecisions(
            messages: messages, relationship: relationship,
            background: background, history: history,
            questions: JudgeQuestions.judge()
        )
        var a = Analysis()
        a.trueIntent = Self.parseChoice(answers["true_intent"])
        if let d = answers["danger_level"] as? [String: Any] {
            a.dangerScore = Self.double(d["score"])
            a.dangerConfidence = Self.double(d["confidence"])
        }
        a.sheNeeds = Self.parseChoice(answers["she_needs"])
        a.shouldReplyNow = Self.noul(answers["should_reply_now"])
        a.bestAction = Self.parseChoice(answers["best_action"])
        a.tensionResolved = Self.noul(answers["tension_resolved"])
        a.literalQuestion = Self.noul(answers["literal_question"])
        return a
    }

    /// Ask Jev which of the candidate replies is best; returns candidates
    /// sorted by ranking probability (percent), best first.
    func rank(messages: [ChatMessage], relationship: String, background: String = "", history: [ChatMessage] = [], candidates: [String]) async throws -> [Candidate] {
        let questions: [String: Any] = ["best_reply": JudgeQuestions.rankQuestion(candidates: candidates)]
        let answers = try await postDecisions(
            messages: messages, relationship: relationship,
            background: background, history: history,
            questions: questions
        )
        let best = answers["best_reply"] as? [String: Any]
        let probs = best?["probabilities"] as? [String: Any] ?? [:]
        let keys = ["reply_a", "reply_b", "reply_c"]
        let ranked = candidates.enumerated().map { (i, text) -> Candidate in
            let p = i < keys.count ? Self.double(probs[keys[i]]) : 0
            return Candidate(text: text, percent: Int((p * 100).rounded()))
        }
        return ranked.sorted { $0.percent > $1.percent }
    }

    /// POST one decisions request. Defensive retry, as in the original: if a
    /// request carrying background/history comes back 4xx, send it once more
    /// without them, so an unverified field degrades but never breaks analysis.
    private func postDecisions(messages: [ChatMessage], relationship: String, background: String, history: [ChatMessage], questions: [String: Any]) async throws -> [String: Any] {
        let enriched = !background.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !history.isEmpty
        do {
            let state = JudgeQuestions.buildState(messages: messages, relationship: relationship, background: background, history: history)
            return try await send(state: state, questions: questions)
        } catch let e as ApiException {
            if enriched, let s = e.status, (400...499).contains(s) {
                let plain = JudgeQuestions.buildState(messages: messages, relationship: relationship)
                return try await send(state: plain, questions: questions)
            }
            throw e
        }
    }

    private func send(state: [String: Any], questions: [String: Any]) async throws -> [String: Any] {
        let url = config.provider.endpoint(baseURL: config.baseURL)
        let body: [String: Any] = [
            "model": config.model,
            "state": state,
            "questions": questions,
        ]
        let resp = try await HttpJson.post(url: url, key: key, body: body, route: "判断接口")
        return resp["answers"] as? [String: Any] ?? [:]
    }

    static func parseChoice(_ any: Any?) -> ChoiceAnswer {
        guard let o = any as? [String: Any] else { return ChoiceAnswer() }
        var probs: [String: Double] = [:]
        if let p = o["probabilities"] as? [String: Any] {
            for (k, v) in p { probs[k] = double(v) }
        }
        return ChoiceAnswer(
            choice: o["choice"] as? String ?? "",
            confidence: double(o["confidence"]),
            probabilities: probs
        )
    }

    static func noul(_ any: Any?) -> Double {
        guard let o = any as? [String: Any] else { return 0 }
        return double(o["noul"])
    }

    static func double(_ any: Any?) -> Double {
        switch any {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s) ?? 0
        default: return 0
        }
    }
}
