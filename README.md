# Jev iOS（可行版）

原项目 [jev-chat/jev-chat-jarvis](https://github.com/jev-chat/jev-chat-jarvis) 是 Android 应用，
靠无障碍服务读屏、悬浮面板、一键填入。iOS 不开放这些能力，本项目是同一套引擎逻辑的
iOS 可行形态移植（Swift / SwiftUI），原项目的判定协议与提示词按原文移植，
参考源码见 `Reference/`（原项目为 MIT 许可，见仓库根目录 LICENSE / NOTICE）。

## 和原版的对应关系

保留一致：
- 判断引擎：走 Jev 专用 decisions 协议（OpenRouter `/alpha/decisions`、
  博查 / TypeSafe / Vercel / OpenCode Zen 的 `/v1/systemone`），7 个判断问题
  （真实意图、危险等级 1-9、对方需要、该不该带实质内容、最佳动作、紧张是否解除、
  是否纯字面）与排序问题 `best_reply` 的英文原文一字不改。
- 候选回复：回复接口（OpenAI 兼容 `/chat/completions`）起草 3 条、判断模型排序给占比，
  支持「换一组」（避开已给过的回复）。
- 知识库与联系人：笔记（标签 / 常驻）、联系人档案、本地聊天历史，规则与原版一致。
- 三路接口配置：判断 / 回复 / 视觉分别可配，密钥只存 Keychain，留空自动继承。
- 永不自动发送。

按 iOS 平台改为手动：
- 读对话：复制粘贴文本进来（可逐条翻转我/对方），或导入聊天截图用本地 Vision OCR
  识别并按气泡左右分方。截图不上传。
- 放回回复：点候选「复制」后自己粘贴；或用自带的 **Jev 键盘**：主 App 里生成的候选
  会经 App Group 同步到键盘，在聊天 App 里切到 Jev 键盘、点一条即直接填进输入框，
  发送仍由你自己点聊天 App 的发送键。键盘不需要「完全访问」，不联网、读不到对话内容。
- 对话更新：重新粘贴即与历史比对，不做后台自动读屏。

## 构建 IPA（GitHub Actions）

仓库带 `.github/workflows/build-ipa.yml`：在 macOS runner 上用 XcodeGen 生成工程，
以 `CODE_SIGNING_ALLOWED=NO` 构建，再把 `.app` 打成无签名 IPA 作为 artifact 上传。
推到 main 或手动触发 workflow 即可，在 Actions 页面下载 `jev-unsigned-ipa`。

## 装机

无签名 IPA 需通过 AltStore / SideStore 用自己的 Apple ID 重签安装
（免费账号签名有效期 7 天，到期在 AltStore 里刷新）。装好后打开 App，
在「设置」里填判断接口密钥即可开始用（只填判断一把时，回复自动继承；
回复模型想换 DeepSeek / 通义可在回复卡里一键填入预设）。

启用候选键盘：系统「设置 → 通用 → 键盘 → 键盘 → 添加新键盘」选 Jev；
之后在微信 / QQ 等聊天里点地球键切到 Jev 键盘即可点选填入。

## 本地结构

- `project.yml` — XcodeGen 工程定义
- `Sources/Jev/` — App 源码（判断客户端、回复客户端、问题集、OCR、界面）
- `Reference/` — 原项目对应 Kotlin / Python 源码，仅作移植对照，不参与编译
