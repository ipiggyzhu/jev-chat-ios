import UIKit

/// Jev keyboard: shows the latest candidates generated in the main app.
/// Tapping one inserts it into the host app's input box via the text
/// document proxy. It never sends: the host app's own send button stays
/// entirely under the user's finger, exactly as requested.
final class KeyboardViewController: UIInputViewController {
    private let stack = UIStackView()
    private var candidateButtons: [UIButton] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        rebuild()
    }

    private func rebuild() {
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        candidateButtons = []

        let header = UILabel()
        header.font = .systemFont(ofSize: 12, weight: .semibold)
        header.textColor = .secondaryLabel
        header.text = "Jev 候选 · 点一条填进输入框，你自己点发送"
        stack.addArrangedSubview(header)

        let candidates = SharedCandidates.load()
        if candidates.isEmpty {
            let hint = UILabel()
            hint.font = .systemFont(ofSize: 14)
            hint.numberOfLines = 3
            hint.text = "还没有候选。先打开 Jev，把对话粘贴或截图导入生成候选，再切回这里点选。"
            stack.addArrangedSubview(hint)
        } else {
            for text in candidates.prefix(3) {
                let b = UIButton(type: .system)
                b.setTitle(text, for: .normal)
                b.titleLabel?.font = .systemFont(ofSize: 16)
                b.titleLabel?.numberOfLines = 2
                b.titleLabel?.lineBreakMode = .byTruncatingTail
                b.contentHorizontalAlignment = .left
                b.backgroundColor = .secondarySystemBackground
                b.layer.cornerRadius = 8
                b.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
                b.addTarget(self, action: #selector(insertCandidate(_:)), for: .touchUpInside)
                stack.addArrangedSubview(b)
                candidateButtons.append(b)
            }
        }

        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        let globe = UIButton(type: .system)
        globe.setTitle("🌐 切换键盘", for: .normal)
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        row.addArrangedSubview(globe)
        let del = UIButton(type: .system)
        del.setTitle("⌫ 删除", for: .normal)
        del.addTarget(self, action: #selector(deleteBackward), for: .touchUpInside)
        row.addArrangedSubview(del)
        let space = UIButton(type: .system)
        space.setTitle("空格", for: .normal)
        space.addTarget(self, action: #selector(insertSpace), for: .touchUpInside)
        row.addArrangedSubview(space)
        stack.addArrangedSubview(row)
    }

    @objc private func insertCandidate(_ sender: UIButton) {
        guard let text = sender.title(for: .normal), !text.isEmpty else { return }
        textDocumentProxy.insertText(text)
    }

    @objc private func deleteBackward() {
        textDocumentProxy.deleteBackward()
    }

    @objc private func insertSpace() {
        textDocumentProxy.insertText(" ")
    }
}
