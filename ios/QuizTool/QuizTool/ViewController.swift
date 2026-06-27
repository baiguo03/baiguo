import UIKit

final class ViewController: UIViewController {
    private struct Option {
        let key: String
        let text: String
    }

    private struct Question {
        let prompt: String
        let options: [Option]
        let answer: Set<String>
        let explanation: String
        let kind: String
    }

    private enum Page: Int {
        case home = 0
        case practice = 1
        case importText = 2
        case wrong = 3
        case settings = 4
    }

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let tabStack = UIStackView()
    private var importTextView: UITextView?

    private var questions: [Question] = [
        Question(
            prompt: "\u{6e29}\u{6297}\u{4f53}\u{578b}\u{81ea}\u{8eab}\u{514d}\u{75ab}\u{6027}\u{6eb6}\u{8840}\u{6027}\u{8d2b}\u{8840}\u{7684}\u{6297}\u{4f53}\u{7c7b}\u{578b}\u{901a}\u{5e38}\u{4e3a}\u{ff08} \u{ff09}",
            options: [
                Option(key: "A", text: "IgA"),
                Option(key: "B", text: "IgM"),
                Option(key: "C", text: "IgD"),
                Option(key: "D", text: "IgG")
            ],
            answer: Set(["D"]),
            explanation: "\u{6e29}\u{6297}\u{4f53}\u{578b}\u{81ea}\u{8eab}\u{514d}\u{75ab}\u{6027}\u{6eb6}\u{8840}\u{6027}\u{8d2b}\u{8840}\u{591a}\u{4e3a} IgG \u{578b}\u{6297}\u{4f53}\u{3002}",
            kind: "\u{5355}\u{9009}\u{9898}"
        ),
        Question(
            prompt: "AI \u{89e3}\u{6790}\u{540e}\u{7684}\u{9898}\u{76ee}\u{4ecd}\u{9700}\u{8981}\u{4eba}\u{5de5}\u{6821}\u{5bf9}\u{540e}\u{518d}\u{53d1}\u{5e03}\u{3002}",
            options: [
                Option(key: "A", text: "\u{6b63}\u{786e}"),
                Option(key: "B", text: "\u{9519}\u{8bef}")
            ],
            answer: Set(["A"]),
            explanation: "AI \u{8f93}\u{51fa}\u{9700}\u{8981}\u{4eba}\u{5de5}\u{6821}\u{5bf9}\u{3002}",
            kind: "\u{5224}\u{65ad}\u{9898}"
        )
    ]

    private var wrongQuestions: [Question] = []
    private var order: [Int] = [0, 1]
    private var currentIndex = 0
    private var selectedAnswers = Set<String>()
    private var modeTitle = "\u{987a}\u{5e8f}\u{7ec3}\u{4e60}"
    private var page: Page = .home
    private var autoTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemGroupedBackground
        configureLayout()
        render()
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        tabStack.translatesAutoresizingMaskIntoConstraints = false

        contentStack.axis = .vertical
        contentStack.spacing = 14

        tabStack.axis = .horizontal
        tabStack.distribution = .fillEqually
        tabStack.spacing = 6
        tabStack.backgroundColor = UIColor.secondarySystemGroupedBackground
        tabStack.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        tabStack.isLayoutMarginsRelativeArrangement = true

        view.addSubview(scrollView)
        view.addSubview(tabStack)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: tabStack.topAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 18),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -18),
            tabStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            tabStack.heightAnchor.constraint(equalToConstant: 64)
        ])
    }

    private func render() {
        clearStack(contentStack)
        renderTabs()
        switch page {
        case .home:
            renderHome()
        case .practice:
            renderPractice()
        case .importText:
            renderImport()
        case .wrong:
            renderWrong()
        case .settings:
            renderSettings()
        }
    }

    private func clearStack(_ stack: UIStackView) {
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    private func renderTabs() {
        clearStack(tabStack)
        let items: [(Page, String)] = [
            (.home, "\u{9996}\u{9875}"),
            (.practice, "\u{7ec3}\u{4e60}"),
            (.importText, "\u{5bfc}\u{5165}"),
            (.wrong, "\u{9519}\u{9898}"),
            (.settings, "\u{8bbe}\u{7f6e}")
        ]
        for item in items {
            let button = makeButton(item.1, style: item.0 == page ? .primary : .secondary)
            button.tag = item.0.rawValue
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabStack.addArrangedSubview(button)
        }
    }

    private func renderHome() {
        addTitle("\u{4e91}\u{9898} V5", "\u{539f}\u{751f} UIKit \u{7248}\u{672c}\u{ff0c}\u{4e0d}\u{518d}\u{4f7f}\u{7528} WebView\u{3002}\u{6784}\u{5efa}\u{6807}\u{8bb0}\u{ff1a}native-v5\u{3002}")
        addCard([
            makeText("\u{9898}\u{5e93}\u{ff1a}\(questions.count) \u{9898}"),
            makeText("\u{9519}\u{9898}\u{ff1a}\(wrongQuestions.count) \u{9898}")
        ])

        let sequential = makeButton("\u{5f00}\u{59cb}\u{987a}\u{5e8f}\u{7ec3}\u{4e60}", style: .primary)
        sequential.addTarget(self, action: #selector(startSequential), for: .touchUpInside)
        contentStack.addArrangedSubview(sequential)

        let random = makeButton("\u{5f00}\u{59cb}\u{968f}\u{673a}\u{7ec3}\u{4e60}", style: .secondary)
        random.addTarget(self, action: #selector(startRandom), for: .touchUpInside)
        contentStack.addArrangedSubview(random)
    }

    private func renderPractice() {
        guard !questions.isEmpty else {
            addTitle("\u{7ec3}\u{4e60}", "\u{6682}\u{65e0}\u{9898}\u{76ee}\u{3002}")
            return
        }
        let question = questions[order[currentIndex]]
        addTitle("\u{7ec3}\u{4e60}", "\(modeTitle)  \(currentIndex + 1) / \(order.count)")
        addCard([
            makeText(question.kind),
            makeText(question.prompt)
        ])
        for option in question.options {
            let selected = selectedAnswers.contains(option.key)
            let button = makeButton("\(option.key). \(option.text)", style: selected ? .primary : .plain)
            button.contentHorizontalAlignment = .left
            button.accessibilityIdentifier = option.key
            button.addTarget(self, action: #selector(answerTapped(_:)), for: .touchUpInside)
            contentStack.addArrangedSubview(button)
        }
        let submit = makeButton("\u{63d0}\u{4ea4}", style: .primary)
        submit.addTarget(self, action: #selector(submitAnswer), for: .touchUpInside)
        contentStack.addArrangedSubview(submit)

        let next = makeButton("\u{4e0b}\u{4e00}\u{9898}", style: .secondary)
        next.addTarget(self, action: #selector(nextQuestion), for: .touchUpInside)
        contentStack.addArrangedSubview(next)
    }

    private func renderImport() {
        addTitle("\u{5bfc}\u{5165}", "\u{4ece} PDF \u{6216} Word \u{590d}\u{5236}\u{9898}\u{76ee}\u{6587}\u{672c}\u{540e}\u{7c98}\u{8d34}\u{5230}\u{8fd9}\u{91cc}\u{3002}")
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = UIColor.secondarySystemGroupedBackground
        textView.layer.cornerRadius = 14
        textView.text = "1. \u{793a}\u{4f8b}\u{9898}\u{5e72} A. \u{9009}\u{9879}A B. \u{9009}\u{9879}B C. \u{9009}\u{9879}C D. \u{9009}\u{9879}D"
        textView.heightAnchor.constraint(equalToConstant: 220).isActive = true
        importTextView = textView
        contentStack.addArrangedSubview(textView)

        let parse = makeButton("\u{5bfc}\u{5165}\u{4e3a}\u{6837}\u{672c}\u{9898}", style: .primary)
        parse.addTarget(self, action: #selector(importTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(parse)
    }

    private func renderWrong() {
        addTitle("\u{9519}\u{9898}", "\u{7b54}\u{9519}\u{7684}\u{9898}\u{4f1a}\u{8bb0}\u{5f55}\u{5728}\u{8fd9}\u{91cc}\u{3002}")
        if wrongQuestions.isEmpty {
            addCard([makeText("\u{6682}\u{65e0}\u{9519}\u{9898}\u{3002}")])
        } else {
            for question in wrongQuestions {
                addCard([makeText(question.prompt)])
            }
        }
    }

    private func renderSettings() {
        addTitle("\u{8bbe}\u{7f6e}", "\u{7248}\u{672c}\u{6807}\u{8bb0}\u{ff1a}\u{4e91}\u{9898} V5 / build 6")
        addCard([
            makeText("\u{5e94}\u{7528}\u{540d}\u{ff1a}\u{4e91}\u{9898} V5"),
            makeText("\u{8fd0}\u{884c}\u{65b9}\u{5f0f}\u{ff1a}\u{539f}\u{751f} UIKit"),
            makeText("\u{517c}\u{5bb9}\u{ff1a}iOS 16.0 \u{53ca}\u{4ee5}\u{4e0a}"),
            makeText("\u{5df2}\u{79fb}\u{9664} WebView\u{ff0c}\u{907f}\u{514d}\u{767d}\u{5c4f}\u{3002}")
        ])
    }

    private func addTitle(_ title: String, _ subtitle: String) {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.numberOfLines = 0
        contentStack.addArrangedSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 15)
        subtitleLabel.textColor = UIColor.secondaryLabel
        subtitleLabel.numberOfLines = 0
        contentStack.addArrangedSubview(subtitleLabel)
    }

    private func addCard(_ views: [UIView]) {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = 10
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.backgroundColor = UIColor.secondarySystemGroupedBackground
        stack.layer.cornerRadius = 16
        contentStack.addArrangedSubview(stack)
    }

    private func makeText(_ value: String) -> UILabel {
        let label = UILabel()
        label.text = value
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 0
        return label
    }

    private enum ButtonStyle {
        case primary
        case secondary
        case plain
    }

    private func makeButton(_ title: String, style: ButtonStyle) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        button.titleLabel?.numberOfLines = 0
        button.layer.cornerRadius = 14
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        switch style {
        case .primary:
            button.backgroundColor = UIColor.systemBlue
            button.tintColor = UIColor.white
        case .secondary:
            button.backgroundColor = UIColor.tertiarySystemFill
            button.tintColor = UIColor.label
        case .plain:
            button.backgroundColor = UIColor.secondarySystemGroupedBackground
            button.tintColor = UIColor.label
        }
        return button
    }

    @objc private func tabTapped(_ sender: UIButton) {
        autoTimer?.invalidate()
        page = Page(rawValue: sender.tag) ?? .home
        render()
    }

    @objc private func startSequential() {
        modeTitle = "\u{987a}\u{5e8f}\u{7ec3}\u{4e60}"
        order = Array(questions.indices)
        currentIndex = 0
        selectedAnswers.removeAll()
        page = .practice
        render()
    }

    @objc private func startRandom() {
        modeTitle = "\u{968f}\u{673a}\u{7ec3}\u{4e60}"
        order = Array(questions.indices).shuffled()
        currentIndex = 0
        selectedAnswers.removeAll()
        page = .practice
        render()
    }

    @objc private func answerTapped(_ sender: UIButton) {
        guard let key = sender.accessibilityIdentifier else { return }
        selectedAnswers = Set([key])
        render()
    }

    @objc private func submitAnswer() {
        guard !questions.isEmpty else { return }
        let question = questions[order[currentIndex]]
        let correct = selectedAnswers == question.answer
        if !correct {
            wrongQuestions.append(question)
        }
        let title = correct ? "\u{6b63}\u{786e}" : "\u{9519}\u{8bef}"
        let message = correct ? "\u{7b54}\u{5bf9}\u{540e}\u{5df2}\u{81ea}\u{52a8}\u{8fdb}\u{5165}\u{4e0b}\u{4e00}\u{9898}\u{3002}" : question.explanation
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "\u{77e5}\u{9053}\u{4e86}", style: .default))
        present(alert, animated: true)
        if correct && currentIndex < order.count - 1 {
            autoTimer?.invalidate()
            autoTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
                self?.nextQuestion()
            }
        }
    }

    @objc private func nextQuestion() {
        guard !order.isEmpty else { return }
        currentIndex = min(currentIndex + 1, order.count - 1)
        selectedAnswers.removeAll()
        page = .practice
        render()
    }

    @objc private func importTapped() {
        let text = importTextView?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let prompt = text.isEmpty ? "\u{5bfc}\u{5165}\u{7684}\u{6837}\u{672c}\u{9898}\u{ff1f}" : text
        questions = [
            Question(
                prompt: prompt,
                options: [
                    Option(key: "A", text: "\u{9009}\u{9879}A"),
                    Option(key: "B", text: "\u{9009}\u{9879}B"),
                    Option(key: "C", text: "\u{9009}\u{9879}C"),
                    Option(key: "D", text: "\u{9009}\u{9879}D")
                ],
                answer: Set(["A"]),
                explanation: "\u{5bfc}\u{5165}\u{9898}\u{9ed8}\u{8ba4}\u{7b54}\u{6848}\u{4e3a} A\u{ff0c}\u{540e}\u{7eed}\u{4f1a}\u{7ee7}\u{7eed}\u{8865}\u{5145}\u{6821}\u{5bf9}\u{529f}\u{80fd}\u{3002}",
                kind: "\u{5bfc}\u{5165}\u{9898}"
            )
        ]
        wrongQuestions.removeAll()
        startSequential()
    }
}
