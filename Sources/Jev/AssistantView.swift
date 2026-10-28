import SwiftUI
import PhotosUI
import UIKit

struct AssistantView: View {
    @EnvironmentObject var store: AppState

    @State private var contactTitle: String = ""
    @State private var relationship: String = Presets.defaultRelationship
    @State private var pastedText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var analysis: Analysis?
    @State private var candidates: [Candidate] = []
    @State private var shownReplies: [String] = []
    @State private var isBusy = false
    @State private var statusText: String = ""
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("会话") {
                    TextField("对方名字 / 会话标题", text: $contactTitle)
                    TextField("关系（可改）", text: $relationship, axis: .vertical)
                }

                Section("把对话给助手读") {
                    TextEditor(text: $pastedText)
                        .frame(minHeight: 110)
                    HStack {
                        Button("解析粘贴") { parsePasted() }
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text("导入截图识别")
                        }
                    }
                    Text("粘贴格式：每行一条，「我：…」是我发的，其它默认对方。也可直接粘贴 WhatsApp 导出的聊天记录：上面的标题填对方名字，导出里另一个人默认是你。解析后点任意一条可翻转我/对方。")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                if !messages.isEmpty {
                    Section("对话（\(messages.count) 条）") {
                        ForEach(messages) { m in
                            HStack(alignment: .top) {
                                Text(m.speaker.label)
                                    .font(.caption).bold()
                                    .foregroundStyle(m.speaker == .me ? .blue : .orange)
                                    .frame(width: 34, alignment: .leading)
                                Text(m.text)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let i = messages.firstIndex(where: { $0.id == m.id }) {
                                    messages[i].flip()
                                }
                            }
                        }
                        .onDelete { messages.remove(atOffsets: $0) }
                    }
                }

                Section {
                    Button {
                        Task { await analyze() }
                    } label: {
                        HStack {
                            Text("判断并生成候选回复")
                            if isBusy { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isBusy || messages.isEmpty)
                    if !statusText.isEmpty {
                        Text(statusText).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if let a = analysis {
                    Section("判断") {
                        LabeledContent("真实意图", value: Self.intentLabel(a.trueIntent.choice) + "（\(Int(a.trueIntent.confidence * 100))%）")
                        LabeledContent("危险等级", value: "\(Int(a.dangerScore.rounded())) / 9")
                        LabeledContent("对方需要", value: Self.needsLabel(a.sheNeeds.choice))
                        LabeledContent("最佳动作", value: Self.actionLabel(a.bestAction.choice))
                        LabeledContent("该带实质内容", value: a.shouldReplyNow >= 0.5 ? "是" : "先别，缓一缓")
                        LabeledContent("紧张已解除", value: a.tensionResolved >= 0.5 ? "是" : "还没有")
                    }
                }

                if !candidates.isEmpty {
                    Section("候选回复（点复制，切回聊天粘贴发送）") {
                        ForEach(candidates) { c in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.text)
                                    Text("合适度 \(c.percent)%").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("复制") {
                                    UIPasteboard.general.string = c.text
                                    statusText = "已复制，去聊天里粘贴发送吧。本助手不会自动发送。"
                                }
                            }
                        }
                        Button("换一组") { Task { await regenerate() } }
                            .disabled(isBusy)
                    }
                }
            }
            .navigationTitle("Jev 助手")
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
        }
    }

    // MARK: - Input parsing

    private func parsePasted() {
        var out: [ChatMessage] = []
        let otherName = contactTitle.trimmingCharacters(in: .whitespaces)
        for raw in pastedText.split(separator: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            // WhatsApp exported chat lines start with a timestamp:
            // "[2026/10/28 18:00] Name: text" or "2026/10/28, 18:00 - Name: text".
            var fromExport = false
            if line.hasPrefix("["), let close = line.firstIndex(of: "]") {
                line = String(line[line.index(after: close)...]).trimmingCharacters(in: .whitespaces)
                fromExport = true
            } else if let dash = line.range(of: " - "),
                      line.distance(from: line.startIndex, to: dash.lowerBound) < 30 {
                line = String(line[dash.upperBound...]).trimmingCharacters(in: .whitespaces)
                fromExport = true
            }
            if line.hasPrefix("我：") || line.hasPrefix("我:") {
                out.append(ChatMessage(speaker: .me, text: String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
            } else if line.hasPrefix("对方：") || line.hasPrefix("对方:") {
                out.append(ChatMessage(speaker: .them, text: String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)))
            } else if let idx = line.firstIndex(of: "：") ?? line.firstIndex(of: ":") {
                let name = String(line[..<idx]).trimmingCharacters(in: .whitespaces)
                let text = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                // In an export, the title names the other person; any other
                // single sender in a 1:1 export is the user themself.
                let speaker: Speaker = (fromExport && !otherName.isEmpty && name != otherName) ? .me : .them
                out.append(ChatMessage(speaker: speaker, text: text))
            } else if var last = out.popLast() {
                last.text += "\n" + line
                out.append(last)
            } else {
                out.append(ChatMessage(speaker: .them, text: line))
            }
        }
        messages = out
        statusText = out.isEmpty ? "没解析出消息，检查一下粘贴内容。" : "已解析 \(out.count) 条，点任意一条可翻转我/对方。"
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                let found = try await ScreenshotOCR.recognize(image)
                if found.isEmpty {
                    statusText = "截图里没识别出文字。"
                } else {
                    messages = found
                    statusText = "截图识别出 \(found.count) 条，点任意一条可翻转我/对方。"
                }
            }
        } catch {
            statusText = "截图识别失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Engine flow: judge -> draft -> rank (same order as the original)

    private func analyze() async {
        guard prepareKeys() else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let contact = store.matchContact(title: contactTitle)
            let bg = store.background(relationship: relationship, contact: contact, messages: messages)
            let hist = store.history(for: contactTitle)
            let judge = JudgeClient(config: store.judge, key: store.judgeKey)
            let a = try await judge.judge(messages: messages, relationship: relationship, background: bg, history: hist)
            analysis = a

            let reply = ReplyClient(config: store.reply, key: store.effectiveReplyKey)
            let drafts = try await reply.draft(messages: messages, relationship: relationship, background: bg, history: hist, count: 3)
            shownReplies = drafts
            if drafts.count == 3 {
                candidates = try await judge.rank(messages: messages, relationship: relationship, background: bg, history: hist, candidates: drafts)
            } else {
                candidates = drafts.map { Candidate(text: $0) }
            }
            SharedCandidates.save(candidates.map { $0.text })
            store.appendHistory(contactName: contactTitle, messages: messages)
            statusText = "完成。点候选右侧的复制，切回聊天 App 粘贴发送。"
        } catch {
            statusText = error.localizedDescription
        }
    }

    private func regenerate() async {
        guard prepareKeys() else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let contact = store.matchContact(title: contactTitle)
            let bg = store.background(relationship: relationship, contact: contact, messages: messages)
            let hist = store.history(for: contactTitle)
            let reply = ReplyClient(config: store.reply, key: store.effectiveReplyKey)
            let drafts = try await reply.draft(messages: messages, relationship: relationship, background: bg, history: hist, count: 3, avoid: shownReplies)
            shownReplies += drafts
            if drafts.count == 3 {
                let judge = JudgeClient(config: store.judge, key: store.judgeKey)
                candidates = try await judge.rank(messages: messages, relationship: relationship, background: bg, history: hist, candidates: drafts)
            } else {
                candidates = drafts.map { Candidate(text: $0) }
            }
            SharedCandidates.save(candidates.map { $0.text })
        } catch {
            statusText = error.localizedDescription
        }
    }

    private func prepareKeys() -> Bool {
        if store.judgeKey.isEmpty {
            statusText = "先去「设置」里填判断接口的密钥。"
            return false
        }
        if store.effectiveReplyKey.isEmpty {
            statusText = "先去「设置」里填回复接口的密钥（或判断接口密钥，会自动继承）。"
            return false
        }
        return true
    }

    // MARK: - Display labels for judge choices

    static func intentLabel(_ k: String) -> String {
        switch k {
        case "confirm_you_care": return "确认你在不在乎"
        case "vent_anger": return "宣泄情绪"
        case "request_action": return "要你做事"
        case "seek_explanation": return "要解释"
        case "casual_chat": return "闲聊"
        case "close_topic": return "收尾"
        default: return k
        }
    }

    static func needsLabel(_ k: String) -> String {
        switch k {
        case "apology": return "道歉"
        case "action": return "行动"
        case "explanation": return "解释"
        case "care": return "在乎的证明"
        case "nothing": return "不需要了"
        default: return k
        }
    }

    static func actionLabel(_ k: String) -> String {
        switch k {
        case "check_history": return "先查记录"
        case "apologize": return "道歉"
        case "give_commitment": return "给承诺"
        case "explain": return "解释"
        case "acknowledge": return "回应情绪"
        case "say_less": return "少说"
        case "make_plan": return "做安排"
        default: return k
        }
    }
}
