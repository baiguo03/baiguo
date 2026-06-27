import UIKit

final class ViewController: UIViewController {
    private enum Page: Int {
        case home = 0
        case practice = 1
        case importText = 2
        case wrong = 3
        case settings = 4
    }

    private enum ButtonStyle {
        case primary
        case secondary
        case plain
        case danger
    }

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let tabStack = UIStackView()
    private var importTextView: UITextView?
    private var feedbackText: String?
    private var feedbackIsPositive = true
    private var autoNextEnabled = true

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
        render(animated: false)
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        tabStack.translatesAutoresizingMaskIntoConstraints = false

        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.alignment = .fill

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

    private func render(animated: Bool = true) {
        let changes = {
            self.clearStack(self.contentStack)
            self.renderTabs()
            switch self.page {
            case .home:
                self.renderHome()
            case .practice:
                self.renderPractice()
            case .importText:
                self.renderImport()
            case .wrong:
                self.renderWrong()
            case .settings:
                self.renderSettings()
            }
            self.view.layoutIfNeeded()
        }

        if animated {
            UIView.transition(with: contentStack, duration: 0.22, options: [.transitionCrossDissolve, .allowUserInteraction], animations: changes)
        } else {
            changes()
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
            button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
            button.layer.cornerRadius = 12
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabStack.addArrangedSubview(button)
        }
    }

    private func renderHome() {
        addTitle("\u{4e91}\u{9898} V6", "\u{4e13}\u{6ce8}\u{7ec3}\u{4e60}\u{3001}\u{9519}\u{9898}\u{548c}\u{5bfc}\u{5165}\u{7684}\u{539f}\u{751f} iOS \u{7248}\u{672c}\u{3002}")
        addStatsRow()
        addSectionHeader("\u{5f00}\u{59cb}\u{7ec3}\u{4e60}")

        let sequential = makeLargeAction("\u{987a}\u{5e8f}\u{7ec3}\u{4e60}", subtitle: "\u{6309}\u{9898}\u{5e93}\u{987a}\u{5e8f}\u{7a33}\u{5b9a}\u{5237}\u{9898}", color: .systemBlue)
        sequential.addTarget(self, action: #selector(startSequential), for: .touchUpInside)
        contentStack.addArrangedSubview(sequential)

        let random = makeLargeAction("\u{968f}\u{673a}\u{7ec3}\u{4e60}", subtitle: "\u{6253}\u{4e71}\u{987a}\u{5e8f}\u{ff0c}\u{9002}\u{5408}\u{590d}\u{4e60}\u{9636}\u{6bb5}", color: .systemTeal)
        random.addTarget(self, action: #selector(startRandom), for: .touchUpInside)
        contentStack.addArrangedSubview(random)
    }

    private func renderPractice() {
        guard !questions.isEmpty else {
            addTitle("\u{7ec3}\u{4e60}", "\u{6682}\u{65e0}\u{9898}\u{76ee}\u{ff0c}\u{5148}\u{53bb}\u{5bfc}\u{5165}\u{3002}")
            return
        }
        let question = questions[order[currentIndex]]
        addTitle("\u{7ec3}\u{4e60}", "\(modeTitle)  \(currentIndex + 1) / \(order.count)")
        addProgress()
        if let feedbackText {
            addFeedback(feedbackText, positive: feedbackIsPositive)
        }
        addQuestionCard(question)
        for option in question.options {
            let selected = selectedAnswers.contains(option.key)
            let button = makeOptionButton(option, selected: selected)
            button.addTarget(self, action: #selector(answerTapped(_:)), for: .touchUpInside)
            contentStack.addArrangedSubview(button)
        }

        let submit = makeButton("\u{63d0}\u{4ea4}\u{7b54}\u{6848}", style: .primary)
        submit.addTarget(self, action: #selector(submitAnswer), for: .touchUpInside)
        contentStack.addArrangedSubview(submit)

        let next = makeButton("\u{4e0b}\u{4e00}\u{9898}", style: .secondary)
        next.addTarget(self, action: #selector(nextQuestion), for: .touchUpInside)
        contentStack.addArrangedSubview(next)
    }

    private func renderImport() {
        addTitle("\u{5bfc}\u{5165}", "\u{7c98}\u{8d34} PDF \u{6216} Word \u{91cc}\u{7684}\u{9898}\u{76ee}\u{6587}\u{672c}\u{ff0c}\u{652f}\u{6301}\u{201c}\u{7b54}\u{6848}\u{ff1a}A\u{201d}\u{548c}\u{201c}\u{89e3}\u{6790}\u{ff1a}\u{201d}\u{3002}")
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = UIColor.secondarySystemGroupedBackground
        textView.layer.cornerRadius = 16
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        textView.text = "1. \u{793a}\u{4f8b}\u{9898}\u{5e72} A. \u{9009}\u{9879}A B. \u{9009}\u{9879}B C. \u{9009}\u{9879}C D. \u{9009}\u{9879}D \u{7b54}\u{6848}\u{ff1a}A \u{89e3}\u{6790}\u{ff1a}\u{8fd9}\u{91cc}\u{662f}\u{89e3}\u{6790}"
        textView.heightAnchor.constraint(equalToConstant: 230).isActive = true
        importTextView = textView
        contentStack.addArrangedSubview(textView)

        let parse = makeButton("\u{89e3}\u{6790}\u{5e76}\u{5bfc}\u{5165}", style: .primary)
        parse.addTarget(self, action: #selector(importTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(parse)
    }

    private func renderWrong() {
        addTitle("\u{9519}\u{9898}", "\u{7b54}\u{9519}\u{7684}\u{9898}\u{4f1a}\u{81ea}\u{52a8}\u{6536}\u{5230}\u{8fd9}\u{91cc}\u{ff0c}\u{53ef}\u{91cd}\u{65b0}\u{7ec3}\u{3002}")
        if wrongQuestions.isEmpty {
            addEmptyState("\u{6682}\u{65e0}\u{9519}\u{9898}", "\u{4fdd}\u{6301}\u{8fd9}\u{4e2a}\u{72b6}\u{6001}\u{4e5f}\u{5f88}\u{4e0d}\u{9519}\u{3002}")
        } else {
            for question in wrongQuestions {
                addCard([makeText(question.prompt, size: 15, weight: .semibold), makeText(question.explanation, size: 13, weight: .regular, color: .secondaryLabel)])
            }
            let clear = makeButton("\u{6e05}\u{7a7a}\u{9519}\u{9898}", style: .danger)
            clear.addTarget(self, action: #selector(clearWrongQuestions), for: .touchUpInside)
            contentStack.addArrangedSubview(clear)
        }
    }

    private func renderSettings() {
        addTitle("\u{8bbe}\u{7f6e}", "\u{4e91}\u{9898} V6 / build 7")
        addSwitchRow(title: "\u{7b54}\u{5bf9}\u{540e}\u{81ea}\u{52a8}\u{4e0b}\u{4e00}\u{9898}", subtitle: "\u{6253}\u{5f00}\u{540e}\u{7b54}\u{5bf9}\u{4e0d}\u{5f39}\u{63d0}\u{793a}\u{ff0c}\u{76f4}\u{63a5}\u{6d41}\u{7545}\u{8df3}\u{8f6c}\u{3002}", isOn: autoNextEnabled, action: #selector(autoNextChanged(_:)))
        addCard([
            makeText("\u{5e94}\u{7528}\u{540d}\u{ff1a}\u{4e91}\u{9898} V6", size: 15, weight: .semibold),
            makeText("\u{8fd0}\u{884c}\u{65b9}\u{5f0f}\u{ff1a}\u{539f}\u{751f} UIKit", size: 15, weight: .semibold),
            makeText("\u{517c}\u{5bb9}\u{ff1a}iOS 16.0 \u{53ca}\u{4ee5}\u{4e0a}", size: 15, weight: .semibold),
            makeText("API \u{5165}\u{53e3}\u{ff1a}\u{4e0b}\u{4e00}\u{7248}\u{63a5}\u{5165}\u{914d}\u{7f6e}", size: 15, weight: .semibold)
        ])
    }

    private func addTitle(_ title: String, _ subtitle: String) {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 34, weight: .bold)
        titleLabel.numberOfLines = 0
        contentStack.addArrangedSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 15)
        subtitleLabel.textColor = UIColor.secondaryLabel
        subtitleLabel.numberOfLines = 0
        contentStack.addArrangedSubview(subtitleLabel)
    }

    private func addSectionHeader(_ text: String) {
        let label = makeText(text, size: 13, weight: .semibold, color: .secondaryLabel)
        label.text = text.uppercased()
        contentStack.addArrangedSubview(label)
    }

    private func addStatsRow() {
        let row = UIStackView(arrangedSubviews: [
            makeStatCard("\u{9898}\u{5e93}", "\(questions.count)"),
            makeStatCard("\u{9519}\u{9898}", "\(wrongQuestions.count)"),
            makeStatCard("\u{81ea}\u{52a8}", autoNextEnabled ? "ON" : "OFF")
        ])
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 10
        contentStack.addArrangedSubview(row)
    }

    private func makeStatCard(_ title: String, _ value: String) -> UIView {
        let valueLabel = makeText(value, size: 24, weight: .bold)
        let titleLabel = makeText(title, size: 12, weight: .medium, color: .secondaryLabel)
        let stack = UIStackView(arrangedSubviews: [valueLabel, titleLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center
        stack.layoutMargins = UIEdgeInsets(top: 14, left: 10, bottom: 14, right: 10)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.backgroundColor = UIColor.secondarySystemGroupedBackground
        stack.layer.cornerRadius = 16
        return stack
    }

    private func addQuestionCard(_ question: Question) {
        let chip = makeText(question.kind, size: 13, weight: .semibold, color: .systemBlue)
        let prompt = makeText(question.prompt, size: 20, weight: .bold)
        addCard([chip, prompt])
    }

    private func addProgress() {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progress = order.isEmpty ? 0 : Float(currentIndex + 1) / Float(order.count)
        progress.tintColor = UIColor.systemBlue
        progress.trackTintColor = UIColor.tertiarySystemFill
        contentStack.addArrangedSubview(progress)
    }

    private func addFeedback(_ text: String, positive: Bool) {
        let label = makeText(text, size: 15, weight: .semibold, color: positive ? .systemGreen : .systemRed)
        label.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [label])
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.backgroundColor = positive ? UIColor.systemGreen.withAlphaComponent(0.12) : UIColor.systemRed.withAlphaComponent(0.12)
        stack.layer.cornerRadius = 14
        contentStack.addArrangedSubview(stack)
    }

    private func addEmptyState(_ title: String, _ subtitle: String) {
        addCard([
            makeText(title, size: 18, weight: .bold),
            makeText(subtitle, size: 14, weight: .regular, color: .secondaryLabel)
        ])
    }

    private func addCard(_ views: [UIView]) {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = 10
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.backgroundColor = UIColor.secondarySystemGroupedBackground
        stack.layer.cornerRadius = 18
        contentStack.addArrangedSubview(stack)
    }

    private func addSwitchRow(title: String, subtitle: String, isOn: Bool, action: Selector) {
        let titleLabel = makeText(title, size: 16, weight: .semibold)
        let subtitleLabel = makeText(subtitle, size: 13, weight: .regular, color: .secondaryLabel)
        let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labels.axis = .vertical
        labels.spacing = 3

        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.addTarget(self, action: action, for: .valueChanged)

        let row = UIStackView(arrangedSubviews: [labels, toggle])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        row.isLayoutMarginsRelativeArrangement = true
        row.backgroundColor = UIColor.secondarySystemGroupedBackground
        row.layer.cornerRadius = 18
        contentStack.addArrangedSubview(row)
    }

    private func makeText(_ value: String, size: CGFloat = 16, weight: UIFont.Weight = .semibold, color: UIColor = .label) -> UILabel {
        let label = UILabel()
        label.text = value
        label.font = UIFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func makeLargeAction(_ title: String, subtitle: String, color: UIColor) -> UIButton {
        let button = makeButton("\(title)\n\(subtitle)", style: .plain)
        button.contentHorizontalAlignment = .left
        button.backgroundColor = color.withAlphaComponent(0.12)
        button.tintColor = color
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        return button
    }

    private func makeOptionButton(_ option: Option, selected: Bool) -> UIButton {
        let button = makeButton("\(option.key). \(option.text)", style: selected ? .primary : .plain)
        button.contentHorizontalAlignment = .left
        button.accessibilityIdentifier = option.key
        button.layer.borderWidth = selected ? 0 : 1
        button.layer.borderColor = UIColor.separator.cgColor
        return button
    }

    private func makeButton(_ title: String, style: ButtonStyle) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        button.titleLabel?.numberOfLines = 0
        button.layer.cornerRadius = 16
        button.contentEdgeInsets = UIEdgeInsets(top: 13, left: 14, bottom: 13, right: 14)
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
        case .danger:
            button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.12)
            button.tintColor = UIColor.systemRed
        }
        return button
    }

    @objc private func tabTapped(_ sender: UIButton) {
        autoTimer?.invalidate()
        feedbackText = nil
        page = Page(rawValue: sender.tag) ?? .home
        render()
    }

    @objc private func startSequential() {
        modeTitle = "\u{987a}\u{5e8f}\u{7ec3}\u{4e60}"
        order = Array(questions.indices)
        currentIndex = 0
        selectedAnswers.removeAll()
        feedbackText = nil
        page = .practice
        render()
    }

    @objc private func startRandom() {
        modeTitle = "\u{968f}\u{673a}\u{7ec3}\u{4e60}"
        order = Array(questions.indices).shuffled()
        currentIndex = 0
        selectedAnswers.removeAll()
        feedbackText = nil
        page = .practice
        render()
    }

    @objc private func answerTapped(_ sender: UIButton) {
        guard let key = sender.accessibilityIdentifier else { return }
        selectedAnswers = Set([key])
        feedbackText = nil
        render()
    }

    @objc private func submitAnswer() {
        guard !questions.isEmpty else { return }
        let question = questions[order[currentIndex]]
        let correct = selectedAnswers == question.answer
        if correct {
            if autoNextEnabled {
                advanceAfterCorrectAnswer()
            } else {
                feedbackText = "\u{7b54}\u{5bf9}\u{4e86}"
                feedbackIsPositive = true
                render()
            }
        } else {
            wrongQuestions.append(question)
            feedbackText = "\u{7b54}\u{9519}\u{4e86}\u{ff1a}\(question.explanation)"
            feedbackIsPositive = false
            render()
        }
    }

    private func advanceAfterCorrectAnswer() {
        guard currentIndex < order.count - 1 else {
            feedbackText = "\u{5df2}\u{5b8c}\u{6210}\u{672c}\u{7ec4}\u{7ec3}\u{4e60}"
            feedbackIsPositive = true
            render()
            return
        }
        selectedAnswers.removeAll()
        feedbackText = nil
        autoTimer?.invalidate()
        autoTimer = Timer.scheduledTimer(withTimeInterval: 0.16, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.currentIndex += 1
            self.renderSlideToNext()
        }
    }

    private func renderSlideToNext() {
        clearStack(contentStack)
        renderTabs()
        renderPractice()
        contentStack.transform = CGAffineTransform(translationX: 28, y: 0)
        contentStack.alpha = 0
        UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            self.contentStack.transform = .identity
            self.contentStack.alpha = 1
        }
    }

    @objc private func nextQuestion() {
        guard !order.isEmpty else { return }
        currentIndex = min(currentIndex + 1, order.count - 1)
        selectedAnswers.removeAll()
        feedbackText = nil
        page = .practice
        renderSlideToNext()
    }

    @objc private func importTapped() {
        let text = importTextView?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parsed = QuestionParser.parse(text)
        guard !parsed.isEmpty else {
            feedbackText = "\u{672a}\u{8bc6}\u{522b}\u{5230}\u{9898}\u{76ee}\u{ff0c}\u{8bf7}\u{68c0}\u{67e5}\u{683c}\u{5f0f}\u{3002}"
            feedbackIsPositive = false
            page = .practice
            render()
            return
        }
        questions = parsed
        order = Array(questions.indices)
        currentIndex = 0
        selectedAnswers.removeAll()
        wrongQuestions.removeAll()
        feedbackText = "\u{5df2}\u{5bfc}\u{5165} \(parsed.count) \u{9898}"
        feedbackIsPositive = true
        page = .practice
        render()
    }

    @objc private func clearWrongQuestions() {
        wrongQuestions.removeAll()
        render()
    }

    @objc private func autoNextChanged(_ sender: UISwitch) {
        autoNextEnabled = sender.isOn
        render()
    }
}
