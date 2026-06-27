import UIKit

final class ViewController: UIViewController {
    private struct Question {
        let prompt: String
        let options: [(key: String, text: String)]
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
            prompt: "Warm antibody autoimmune hemolytic anemia is usually related to which antibody type?",
            options: [("A", "IgA"), ("B", "IgM"), ("C", "IgD"), ("D", "IgG")],
            answer: Set(["D"]),
            explanation: "Warm antibody autoimmune hemolytic anemia is commonly IgG mediated.",
            kind: "Single Choice"
        ),
        Question(
            prompt: "AI parsed questions should still be checked before publishing.",
            options: [("A", "True"), ("B", "False")],
            answer: Set(["A"]),
            explanation: "AI output needs manual review before use.",
            kind: "Judge"
        )
    ]

    private var wrongQuestions: [Question] = []
    private var order: [Int] = [0, 1]
    private var currentIndex = 0
    private var selectedAnswers = Set<String>()
    private var mode = "Sequential"
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
            (.home, "Home"),
            (.practice, "Practice"),
            (.importText, "Import"),
            (.wrong, "Wrong"),
            (.settings, "Settings")
        ]

        for item in items {
            let button = makeButton(item.1, style: item.0 == page ? .primary : .secondary)
            button.tag = item.0.rawValue
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabStack.addArrangedSubview(button)
        }
    }

    private func renderHome() {
        addTitle("QuizNativeV2", "Native UIKit version. No WebView. Build marker: native-v2.")
        addCard([
            makeText("Question bank: \(questions.count)"),
            makeText("Wrong questions: \(wrongQuestions.count)")
        ])

        let sequential = makeButton("Start Sequential Practice", style: .primary)
        sequential.addTarget(self, action: #selector(startSequential), for: .touchUpInside)
        contentStack.addArrangedSubview(sequential)

        let random = makeButton("Start Random Practice", style: .secondary)
        random.addTarget(self, action: #selector(startRandom), for: .touchUpInside)
        contentStack.addArrangedSubview(random)
    }

    private func renderPractice() {
        guard !questions.isEmpty else {
            addTitle("Practice", "No questions yet.")
            return
        }

        let question = questions[order[currentIndex]]
        addTitle("Practice", "\(mode)  \(currentIndex + 1) / \(order.count)")
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

        let submit = makeButton("Submit", style: .primary)
        submit.addTarget(self, action: #selector(submitAnswer), for: .touchUpInside)
        contentStack.addArrangedSubview(submit)

        let next = makeButton("Next", style: .secondary)
        next.addTarget(self, action: #selector(nextQuestion), for: .touchUpInside)
        contentStack.addArrangedSubview(next)
    }

    private func renderImport() {
        addTitle("Import", "Paste text from PDF or Word. This native version keeps import simple first.")

        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = UIColor.secondarySystemGroupedBackground
        textView.layer.cornerRadius = 14
        textView.text = "1. Sample question A. Option A B. Option B C. Option C D. Option D"
        textView.heightAnchor.constraint(equalToConstant: 220).isActive = true
        importTextView = textView
        contentStack.addArrangedSubview(textView)

        let parse = makeButton("Import as Sample Questions", style: .primary)
        parse.addTarget(self, action: #selector(importTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(parse)
    }

    private func renderWrong() {
        addTitle("Wrong", "Wrong answers are recorded here.")
        if wrongQuestions.isEmpty {
            addCard([makeText("No wrong questions yet.")])
        } else {
            for question in wrongQuestions {
                addCard([makeText(question.prompt)])
            }
        }
    }

    private func renderSettings() {
        addTitle("Settings", "Version marker: QuizNativeV2 / CFBundleVersion 3")
        addCard([
            makeText("App name: QuizNativeV2"),
            makeText("Runtime: Native UIKit"),
            makeText("iOS target: 16.0"),
            makeText("WebView removed to avoid blank screen.")
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
        mode = "Sequential"
        order = Array(questions.indices)
        currentIndex = 0
        selectedAnswers.removeAll()
        page = .practice
        render()
    }

    @objc private func startRandom() {
        mode = "Random"
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

        let title = correct ? "Correct" : "Wrong"
        let message = correct ? "Auto next question enabled." : question.explanation
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
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
        let prompt = text.isEmpty ? "Imported sample question?" : text
        questions = [
            Question(
                prompt: prompt,
                options: [("A", "Option A"), ("B", "Option B"), ("C", "Option C"), ("D", "Option D")],
                answer: Set(["A"]),
                explanation: "Imported questions default to answer A in this native smoke-test version.",
                kind: "Imported"
            )
        ]
        wrongQuestions.removeAll()
        startSequential()
    }
}
