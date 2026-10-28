import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppState
    @State private var judgeKeyDraft: String = ""
    @State private var replyKeyDraft: String = ""
    @State private var visionKeyDraft: String = ""
    @State private var testResult: String = ""
    @State private var testing = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("服务商", selection: $store.judge.provider) {
                        ForEach(JudgeProvider.allCases, id: \.self) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .onChange(of: store.judge.provider) { _, p in
                        if let preset = Presets.judge.first(where: { $0.provider == p }), !preset.baseURL.isEmpty {
                            store.judge.baseURL = preset.baseURL
                            store.judge.model = preset.model
                        }
                    }
                    TextField("地址", text: $store.judge.baseURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("模型", text: $store.judge.model)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("密钥", text: $judgeKeyDraft)
                        .onChange(of: judgeKeyDraft) { _, v in store.judgeKey = v }
                } header: {
                    Text("判断接口")
                } footer: {
                    Text("只需要填这一把密钥也能用，回复和视觉会继承。判断走 Jev 专用 decisions 协议，不是普通聊天接口。")
                }

                Section {
                    TextField("地址", text: $store.reply.baseURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("模型", text: $store.reply.model)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("密钥（留空继承判断）", text: $replyKeyDraft)
                        .onChange(of: replyKeyDraft) { _, v in store.replyKey = v }
                    HStack {
                        Button("填 DeepSeek 官方") {
                            store.reply.baseURL = Presets.deepseekBase
                            store.reply.model = Presets.deepseekModel
                        }
                        Spacer()
                        Button("填通义兼容") {
                            store.reply.baseURL = Presets.dashscopeBase
                            store.reply.model = Presets.dashscopeModel
                        }
                    }
                    Button {
                        Task { await testReply() }
                    } label: {
                        HStack {
                            Text("连通测试（回复接口）")
                            if testing { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(testing)
                    if !testResult.isEmpty {
                        Text(testResult).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("回复接口")
                } footer: {
                    Text("OpenAI 兼容的 /chat/completions 接口。测试会真实发一句「请只回复两个字：收到」。")
                }

                Section {
                    TextField("地址", text: $store.vision.baseURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("模型", text: $store.vision.model)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("密钥（留空继承回复）", text: $visionKeyDraft)
                        .onChange(of: visionKeyDraft) { _, v in store.visionKey = v }
                } header: {
                    Text("视觉接口")
                } footer: {
                    Text("第一版的截图识别用手机本地 OCR，不走视觉接口；这张卡先留着，和原版三卡结构保持一致。")
                }
            }
            .navigationTitle("设置")
            .onAppear {
                judgeKeyDraft = store.judgeKey
                replyKeyDraft = store.replyKey
                visionKeyDraft = store.visionKey
            }
        }
    }

    private func testReply() async {
        testing = true
        defer { testing = false }
        do {
            let client = ReplyClient(config: store.reply, key: store.effectiveReplyKey)
            let got = try await client.ping()
            testResult = got.isEmpty ? "连通，但回复为空。" : "连通成功，对方回复：\(got)"
        } catch {
            testResult = error.localizedDescription
        }
    }
}
