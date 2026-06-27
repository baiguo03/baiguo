import UIKit
import PDFKit
import UniformTypeIdentifiers

final class ViewController: UIViewController, UIDocumentPickerDelegate, UIGestureRecognizerDelegate {
    private struct Paper {
        let title: String
        let source: String
        let questions: [Question]
    }

    private enum Page: Int {
        case home = 0
        case library = 1
        case importText = 2
        case wrong = 3
        case profile = 4
        case practice = 9
    }

    private enum ButtonStyle {
        case primary
        case secondary
        case plain
        case danger
    }

    private let accentColor = UIColor(red: 0.09, green: 0.71, blue: 0.42, alpha: 1)
    private let appBackgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
    private let softGreenColor = UIColor(red: 0.93, green: 0.98, blue: 0.95, alpha: 1)
    private let cardBackgroundColor = UIColor.white
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let tabStack = UIStackView()
    private var panStartOffset: CGPoint = .zero
    private var importTextView: UITextView?
    private var feedbackText: String?
    private var feedbackIsPositive = true
    private var autoNextEnabled = true
    private var shuffleOptionsEnabled = true

    private var papers: [Paper] = []
    private var activePaperIndex = 0
    private var wrongQuestions: [Question] = []
    private var order: [Int] = []
    private var optionOrders: [String: [String]] = [:]
    private var currentIndex = 0
    private var selectedAnswers = Set<String>()
    private var modeTitle = "\u{987a}\u{5e8f}\u{7ec3}\u{4e60}"
    private var page: Page = .home
    private var autoTimer: Timer?

    private var activePaper: Paper {
        papers[min(activePaperIndex, max(papers.count - 1, 0))]
    }

    private var activeQuestions: [Question] {
        papers.isEmpty ? [] : activePaper.questions
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = appBackgroundColor
        configureSeedData()
        configureLayout()
        configureSwipeGestures()
        render(animated: false)
    }

    private func configureSeedData() {
        let sample = Paper(
            title: "\u{793a}\u{4f8b}\u{9898}\u{5e93}",
            source: "\u{5185}\u{7f6e}\u{6837}\u{672c}",
            questions: [
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
        )
        papers = [sample]
        order = Array(sample.questions.indices)
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        tabStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.alignment = .fill
        tabStack.axis = .horizontal
        tabStack.distribution = .fillEqually
        tabStack.spacing = 0
        tabStack.backgroundColor = UIColor.white.withAlphaComponent(0.96)
        tabStack.layoutMargins = UIEdgeInsets(top: 7, left: 10, bottom: 16, right: 10)
        tabStack.isLayoutMarginsRelativeArrangement = true

        view.addSubview(scrollView)
        view.addSubview(tabStack)
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: tabStack.topAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 10),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -18),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -14),
            tabStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            tabStack.heightAnchor.constraint(equalToConstant: 82)
        ])
    }

    private func configureSwipeGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePracticePan(_:)))
        pan.delegate = self
        pan.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(pan)
    }

    private func render(animated: Bool = true) {
        let changes = {
            self.clearStack(self.contentStack)
            self.renderTabs()
            switch self.page {
            case .home:
                self.renderHome()
            case .library:
                self.renderLibrary()
            case .importText:
                self.renderImport()
            case .wrong:
                self.renderWrong()
            case .profile:
                self.renderProfile()
            case .practice:
                self.renderPractice()
            }
            self.view.layoutIfNeeded()
        }
        if animated {
            UIView.transition(with: contentStack, duration: 0.2, options: [.transitionCrossDissolve, .allowUserInteraction], animations: changes)
        } else {
            changes()
        }
    }

    private func renderTabs() {
        clearStack(tabStack)
        let items: [(Page, String, String)] = [
            (.home, "house", "\u{9996}\u{9875}"),
            (.library, "square.grid.2x2", "\u{9898}\u{5e93}"),
            (.wrong, "exclamationmark.triangle", "\u{9519}\u{9898}"),
            (.profile, "person", "\u{6211}\u{7684}")
        ]
        for item in items {
            let selected = item.0 == page || (page == .practice && item.0 == .library)
            let button = makeTabButton(icon: item.1, title: item.2, selected: selected)
            button.tag = item.0.rawValue
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabStack.addArrangedSubview(button)
        }
    }

    private func renderHome() {
        addTitle("\u{4e91}\u{9898} V10", "\u{7ba1}\u{7406}\u{591a}\u{4efd}\u{8bd5}\u{9898}\u{ff0c}\u{70b9}\u{5f00}\u{9898}\u{5e93}\u{540e}\u{518d}\u{5f00}\u{59cb}\u{7ec3}\u{4e60}\u{3002}")
        addStatsRow()
        addSectionHeader("\u{5feb}\u{6377}\u{5165}\u{53e3}")
        addListGroup([
            row("\u{6700}\u{8fd1}\u{9898}\u{5e93}", subtitle: activePaper.title, action: #selector(openCurrentPaper)),
            row("\u{5bfc}\u{5165}\u{65b0}\u{8bd5}\u{9898}", subtitle: "\u{7c98}\u{8d34}\u{6216}\u{9009}\u{62e9} TXT/PDF", action: #selector(openImportPage)),
            row("\u{7ee7}\u{7eed}\u{7ec3}\u{4e60}", subtitle: "\(currentIndex + 1) / \(max(order.count, 1))", action: #selector(openCurrentPaper))
        ])
    }

    private func renderLibrary() {
        addTitle("\u{9898}\u{5e93}", "\u{6bcf}\u{4efd}\u{5bfc}\u{5165}\u{7684}\u{8bd5}\u{9898}\u{90fd}\u{4f1a}\u{72ec}\u{7acb}\u{4fdd}\u{7559}\u{3002}")
        var rows: [UIView] = []
        for index in papers.indices {
            let paper = papers[index]
            rows.append(row(paper.title, subtitle: "\(paper.questions.count) \u{9898}  \u{00b7}  \(paper.source)", tag: index, action: #selector(paperTapped(_:))))
        }
        addListGroup(rows)
        let importButton = makeButton("\u{5bfc}\u{5165}\u{65b0}\u{8bd5}\u{9898}", style: .primary)
        importButton.addTarget(self, action: #selector(openImportPage), for: .touchUpInside)
        contentStack.addArrangedSubview(importButton)
    }

    private func renderImport() {
        addTitle("\u{5bfc}\u{5165}", "\u{6587}\u{4ef6}\u{5bfc}\u{5165}\u{4f18}\u{5148}\u{652f}\u{6301} TXT/PDF\u{ff0c}Word \u{540e}\u{7eed}\u{63a5} API \u{89e3}\u{6790}\u{66f4}\u{7a33}\u{3002}")
        addListGroup([
            row("\u{6587}\u{4ef6}\u{5bfc}\u{5165}", subtitle: "TXT / PDF", action: #selector(openFileImporter)),
            row("\u{7c98}\u{8d34}\u{5bfc}\u{5165}", subtitle: "\u{5c06}\u{9898}\u{76ee}\u{6587}\u{672c}\u{7c98}\u{8d34}\u{5230}\u{4e0b}\u{65b9}", action: nil)
        ])
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = UIColor.white
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        textView.text = "1. \u{793a}\u{4f8b}\u{9898}\u{5e72} A. \u{9009}\u{9879}A B. \u{9009}\u{9879}B C. \u{9009}\u{9879}C D. \u{9009}\u{9879}D \u{7b54}\u{6848}\u{ff1a}A \u{89e3}\u{6790}\u{ff1a}\u{8fd9}\u{91cc}\u{662f}\u{89e3}\u{6790}"
        textView.heightAnchor.constraint(equalToConstant: 220).isActive = true
        importTextView = textView
        contentStack.addArrangedSubview(textView)
        let parse = makeButton("\u{89e3}\u{6790}\u{4e3a}\u{65b0}\u{9898}\u{5e93}", style: .primary)
        parse.addTarget(self, action: #selector(importTapped), for: .touchUpInside)
        contentStack.addArrangedSubview(parse)
    }

    private func renderPractice() {
        guard !activeQuestions.isEmpty, !order.isEmpty else {
            addTitle("\u{7ec3}\u{4e60}", "\u{8fd9}\u{4efd}\u{9898}\u{5e93}\u{6682}\u{65e0}\u{9898}\u{76ee}\u{3002}")
            return
        }
        let question = activeQuestions[order[currentIndex]]
        addTitle(activePaper.title, "\(modeTitle)  \(currentIndex + 1) / \(order.count)")
        addProgress()
        if let feedbackText {
            addFeedback(feedbackText, positive: feedbackIsPositive)
        }
        addQuestionCard(question)
        for (index, option) in optionsForCurrentQuestion(question).enumerated() {
            let selected = selectedAnswers.contains(option.key)
            let button = makeOptionButton(option, displayKey: displayKey(for: index), selected: selected)
            button.addTarget(self, action: #selector(answerTapped(_:)), for: .touchUpInside)
            contentStack.addArrangedSubview(button)
        }
        if !autoNextEnabled {
            let submit = makeButton("\u{63d0}\u{4ea4}\u{7b54}\u{6848}", style: .primary)
            submit.addTarget(self, action: #selector(submitAnswer), for: .touchUpInside)
            contentStack.addArrangedSubview(submit)
        }
        let hint = makeText("\u{4ece}\u{5c4f}\u{5e55}\u{5de6}\u{8fb9}\u{7f18}\u{6ed1}\u{52a8}\u{8fd4}\u{56de}\u{4e0a}\u{4e00}\u{9898}\u{ff0c}\u{53f3}\u{8fb9}\u{7f18}\u{6ed1}\u{52a8}\u{8fdb}\u{5165}\u{4e0b}\u{4e00}\u{9898}\u{3002}", size: 13, weight: .regular, color: .secondaryLabel)
        hint.textAlignment = .center
        contentStack.addArrangedSubview(hint)
    }

    private func renderWrong() {
        addTitle("\u{9519}\u{9898}", "\u{8de8}\u{9898}\u{5e93}\u{6536}\u{85cf}\u{4f60}\u{7b54}\u{9519}\u{7684}\u{9898}\u{3002}")
        if wrongQuestions.isEmpty {
            addEmptyState("\u{6682}\u{65e0}\u{9519}\u{9898}", "\u{53bb}\u{9898}\u{5e93}\u{5f00}\u{59cb}\u{4e00}\u{7ec4}\u{7ec3}\u{4e60}\u{5427}\u{3002}")
        } else {
            for question in wrongQuestions {
                addCard([makeText(question.prompt, size: 15, weight: .semibold), makeText(question.explanation, size: 13, weight: .regular, color: .secondaryLabel)])
            }
            let clear = makeButton("\u{6e05}\u{7a7a}\u{9519}\u{9898}", style: .danger)
            clear.addTarget(self, action: #selector(clearWrongQuestions), for: .touchUpInside)
            contentStack.addArrangedSubview(clear)
        }
    }

    private func renderProfile() {
        addTitle("\u{6211}\u{7684}", "\u{504f}\u{597d}\u{8bbe}\u{7f6e}\u{548c}\u{7248}\u{672c}\u{4fe1}\u{606f}\u{3002}")
        addSwitchRow(title: "\u{7b54}\u{5bf9}\u{540e}\u{81ea}\u{52a8}\u{4e0b}\u{4e00}\u{9898}", subtitle: "\u{6253}\u{5f00}\u{540e}\u{4e0d}\u{5f39}\u{7b54}\u{5bf9}\u{63d0}\u{793a}\u{ff0c}\u{76f4}\u{63a5}\u{8fdb}\u{5165}\u{4e0b}\u{4e00}\u{9898}\u{3002}", isOn: autoNextEnabled, action: #selector(autoNextChanged(_:)))
        addSwitchRow(title: "\u{9009}\u{9879}\u{968f}\u{673a}\u{6392}\u{5e8f}", subtitle: "\u{6bcf}\u{9053}\u{9898}\u{9996}\u{6b21}\u{6253}\u{5f00}\u{65f6}\u{968f}\u{673a}\u{ff0c}\u{8fd4}\u{56de}\u{540c}\u{9898}\u{65f6}\u{4fdd}\u{6301}\u{987a}\u{5e8f}\u{4e0d}\u{53d8}\u{3002}", isOn: shuffleOptionsEnabled, action: #selector(shuffleOptionsChanged(_:)))
        addListGroup([
            infoRow("\u{5e94}\u{7528}\u{7248}\u{672c}", subtitle: "\u{4e91}\u{9898} V10 / build 11"),
            infoRow("\u{6587}\u{4ef6}\u{5bfc}\u{5165}", subtitle: "TXT / PDF"),
            infoRow("API", subtitle: "\u{9884}\u{7559}\u{5165}\u{53e3}")
        ])
    }

    private func addTitle(_ title: String, _ subtitle: String) {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.numberOfLines = 0
        contentStack.addArrangedSubview(titleLabel)
        let subtitleLabel = makeText(subtitle, size: 15, weight: .regular, color: UIColor.secondaryLabel)
        contentStack.addArrangedSubview(subtitleLabel)
    }

    private func addSectionHeader(_ text: String) {
        let label = makeText(text, size: 13, weight: .semibold, color: .secondaryLabel)
        contentStack.addArrangedSubview(label)
    }

    private func addStatsRow() {
        let total = papers.reduce(0) { $0 + $1.questions.count }
        let row = UIStackView(arrangedSubviews: [
            makeStatCard("\u{9898}\u{5e93}", "\(papers.count)"),
            makeStatCard("\u{9898}\u{76ee}", "\(total)"),
            makeStatCard("\u{9519}\u{9898}", "\(wrongQuestions.count)")
        ])
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 10
        contentStack.addArrangedSubview(row)
    }

    private func makeStatCard(_ title: String, _ value: String) -> UIView {
        let valueLabel = makeText(value, size: 20, weight: .bold, color: accentColor)
        let titleLabel = makeText(title, size: 11, weight: .medium, color: .secondaryLabel)
        let stack = UIStackView(arrangedSubviews: [valueLabel, titleLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center
        stack.layoutMargins = UIEdgeInsets(top: 11, left: 10, bottom: 11, right: 10)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.backgroundColor = cardBackgroundColor
        stack.layer.cornerRadius = 16
        return stack
    }

    private func row(_ title: String, subtitle: String, tag: Int = 0, action: Selector?) -> UIView {
        let titleLabel = makeText(title, size: 15, weight: .semibold)
        let subtitleLabel = makeText(subtitle, size: 13, weight: .regular, color: .secondaryLabel)
        let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labels.axis = .vertical
        labels.spacing = 2
        let arrow = makeText("\u{203a}", size: 24, weight: .regular, color: .tertiaryLabel)
        let row = UIStackView(arrangedSubviews: [labels, arrow])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.layoutMargins = UIEdgeInsets(top: 11, left: 14, bottom: 11, right: 14)
        row.isLayoutMarginsRelativeArrangement = true
        row.tag = tag
        if let action {
            let tap = UITapGestureRecognizer(target: self, action: action)
            row.addGestureRecognizer(tap)
            row.isUserInteractionEnabled = true
        }
        return row
    }

    private func infoRow(_ title: String, subtitle: String) -> UIView {
        row(title, subtitle: subtitle, action: nil)
    }

    private func addListGroup(_ rows: [UIView]) {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.backgroundColor = cardBackgroundColor
        stack.layer.cornerRadius = 18
        stack.clipsToBounds = true
        for index in rows.indices {
            stack.addArrangedSubview(rows[index])
            if index < rows.count - 1 {
                let divider = UIView()
                divider.backgroundColor = UIColor.separator
                divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                stack.addArrangedSubview(divider)
            }
        }
        contentStack.addArrangedSubview(stack)
    }

    private func addQuestionCard(_ question: Question) {
        let chip = makeText(question.kind, size: 13, weight: .bold, color: accentColor)
        let prompt = makeText(question.prompt, size: 20, weight: .bold)
        addCard([chip, prompt])
    }

    private func optionsForCurrentQuestion(_ question: Question) -> [Option] {
        let questionIndex = order.isEmpty ? currentIndex : order[currentIndex]
        let cacheKey = "\(activePaperIndex)-\(questionIndex)"
        if let keys = optionOrders[cacheKey] {
            return keys.compactMap { key in question.options.first { $0.key == key } }
        }

        let options = shuffleOptionsEnabled ? question.options.shuffled() : question.options
        optionOrders[cacheKey] = options.map(\.key)
        return options
    }

    private func displayKey(for index: Int) -> String {
        let keys = ["A", "B", "C", "D", "E", "F"]
        return index < keys.count ? keys[index] : "\(index + 1)"
    }

    private func addProgress() {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.progress = order.isEmpty ? 0 : Float(currentIndex + 1) / Float(order.count)
        progress.tintColor = accentColor
        progress.trackTintColor = UIColor.tertiarySystemFill
        contentStack.addArrangedSubview(progress)
    }

    private func addFeedback(_ text: String, positive: Bool) {
        let label = makeText(text, size: 15, weight: .semibold, color: positive ? accentColor : .systemRed)
        label.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [label])
        stack.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.backgroundColor = positive ? softGreenColor : UIColor.systemRed.withAlphaComponent(0.12)
        stack.layer.cornerRadius = 16
        contentStack.addArrangedSubview(stack)
    }

    private func addEmptyState(_ title: String, _ subtitle: String) {
        addCard([makeText(title, size: 18, weight: .bold), makeText(subtitle, size: 14, weight: .regular, color: .secondaryLabel)])
    }

    private func addCard(_ views: [UIView]) {
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = 10
        stack.layoutMargins = UIEdgeInsets(top: 15, left: 16, bottom: 15, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.backgroundColor = cardBackgroundColor
        stack.layer.cornerRadius = 18
        contentStack.addArrangedSubview(stack)
    }

    private func addSwitchRow(title: String, subtitle: String, isOn: Bool, action: Selector) {
        let titleLabel = makeText(title, size: 15, weight: .semibold)
        let subtitleLabel = makeText(subtitle, size: 13, weight: .regular, color: .secondaryLabel)
        let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labels.axis = .vertical
        labels.spacing = 3
        let toggle = UISwitch()
        toggle.onTintColor = accentColor
        toggle.isOn = isOn
        toggle.addTarget(self, action: action, for: .valueChanged)
        let row = UIStackView(arrangedSubviews: [labels, toggle])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        row.isLayoutMarginsRelativeArrangement = true
        row.backgroundColor = cardBackgroundColor
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

    private func makeOptionButton(_ option: Option, displayKey: String, selected: Bool) -> UIButton {
        let title = selected ? "\u{2713}  \(displayKey). \(option.text)" : "\(displayKey). \(option.text)"
        let button = makeButton(title, style: .plain)
        button.contentHorizontalAlignment = .left
        button.accessibilityIdentifier = option.key
        button.backgroundColor = selected ? softGreenColor : cardBackgroundColor
        button.tintColor = selected ? accentColor : UIColor.label
        button.layer.borderWidth = selected ? 1 : 0.5
        button.layer.borderColor = selected ? accentColor.withAlphaComponent(0.32).cgColor : UIColor.separator.cgColor
        button.layer.cornerRadius = 17
        return button
    }

    private func makeTabButton(icon: String, title: String, selected: Bool) -> UIButton {
        let button = UIButton(type: .system)
        let color = selected ? accentColor : UIColor.label
        let image = UIImage(systemName: icon)?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 19, weight: .regular))
        button.setImage(image, for: .normal)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        button.titleLabel?.textAlignment = .center
        button.backgroundColor = UIColor.clear
        button.tintColor = color
        button.imageView?.contentMode = .scaleAspectFit
        button.alignImageAboveTitle(spacing: 2)
        return button
    }

    private func centeredParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = 2
        return style
    }

    private func makeButton(_ title: String, style: ButtonStyle) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        button.titleLabel?.numberOfLines = 0
        button.layer.cornerRadius = 14
        button.contentEdgeInsets = UIEdgeInsets(top: 11, left: 14, bottom: 11, right: 14)
        switch style {
        case .primary:
            button.backgroundColor = accentColor
            button.tintColor = UIColor.white
        case .secondary:
            button.backgroundColor = UIColor.tertiarySystemFill
            button.tintColor = UIColor.label
        case .plain:
            button.backgroundColor = cardBackgroundColor
            button.tintColor = UIColor.label
        case .danger:
            button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.12)
            button.tintColor = UIColor.systemRed
        }
        return button
    }

    private func clearStack(_ stack: UIStackView) {
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    @objc private func tabTapped(_ sender: UIButton) {
        autoTimer?.invalidate()
        feedbackText = nil
        page = Page(rawValue: sender.tag) ?? .home
        render()
    }

    @objc private func openImportPage() {
        page = .importText
        render()
    }

    @objc private func openCurrentPaper() {
        startPaper(index: activePaperIndex, random: false)
    }

    @objc private func paperTapped(_ sender: UITapGestureRecognizer) {
        guard let index = sender.view?.tag else { return }
        startPaper(index: index, random: false)
    }

    private func startPaper(index: Int, random: Bool) {
        guard papers.indices.contains(index) else { return }
        activePaperIndex = index
        let questions = activeQuestions
        order = random ? Array(questions.indices).shuffled() : Array(questions.indices)
        optionOrders.removeAll()
        modeTitle = random ? "\u{968f}\u{673a}\u{7ec3}\u{4e60}" : "\u{987a}\u{5e8f}\u{7ec3}\u{4e60}"
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
        if autoNextEnabled {
            submitAnswer()
        } else {
            render()
        }
    }

    @objc private func submitAnswer() {
        guard !activeQuestions.isEmpty, !order.isEmpty else { return }
        let question = activeQuestions[order[currentIndex]]
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
        feedbackText = nil
        render()
        autoTimer?.invalidate()
        autoTimer = Timer.scheduledTimer(withTimeInterval: 0.38, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.currentIndex += 1
            self.selectedAnswers.removeAll()
            self.renderSlideToNext()
        }
    }

    private func renderSlideToNext() {
        renderCalmQuestionChange()
    }

    private func renderCalmQuestionChange() {
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            self.contentStack.alpha = 0.72
            self.contentStack.transform = CGAffineTransform(translationX: 0, y: 2)
        } completion: { _ in
            self.clearStack(self.contentStack)
            self.renderTabs()
            self.renderPractice()
            self.contentStack.alpha = 0.82
            self.contentStack.transform = CGAffineTransform(translationX: 0, y: 2)
            UIView.animate(withDuration: 0.28, delay: 0.1, options: [.curveEaseInOut, .allowUserInteraction]) {
                self.contentStack.alpha = 1
                self.contentStack.transform = .identity
            }
        }
    }

    @objc private func nextQuestion() {
        guard !order.isEmpty else { return }
        currentIndex = min(currentIndex + 1, order.count - 1)
        selectedAnswers.removeAll()
        feedbackText = nil
        page = .practice
        renderCalmQuestionChange()
    }

    @objc private func previousQuestion() {
        guard !order.isEmpty else { return }
        currentIndex = max(currentIndex - 1, 0)
        selectedAnswers.removeAll()
        feedbackText = nil
        page = .practice
        renderCalmQuestionChange()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard page == .practice, let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        return abs(velocity.x) > abs(velocity.y) * 1.2
    }

    @objc private func handlePracticePan(_ gesture: UIPanGestureRecognizer) {
        guard page == .practice else { return }
        switch gesture.state {
        case .began:
            panStartOffset = scrollView.contentOffset
        case .changed:
            let translation = gesture.translation(in: view)
            if abs(translation.x) > abs(translation.y) {
                scrollView.contentOffset = panStartOffset
                contentStack.transform = CGAffineTransform(translationX: translation.x * 0.08, y: 0)
            }
        case .ended:
            let translation = gesture.translation(in: view)
            let velocity = gesture.velocity(in: view)
            contentStack.transform = .identity
            if translation.x > 36 || velocity.x > 420 {
                previousQuestion()
            } else if translation.x < -36 || velocity.x < -420 {
                nextQuestion()
            }
        case .cancelled, .failed:
            contentStack.transform = .identity
        default:
            break
        }
    }

    @objc private func importTapped() {
        let text = importTextView?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        importQuestions(from: text, title: "\u{7c98}\u{8d34}\u{5bfc}\u{5165}\u{9898}\u{5e93}", source: "\u{7c98}\u{8d34}")
    }

    private func importQuestions(from text: String, title: String, source: String) {
        let parsed = QuestionParser.parse(text)
        guard !parsed.isEmpty else {
            feedbackText = "\u{672a}\u{8bc6}\u{522b}\u{5230}\u{9898}\u{76ee}\u{ff0c}\u{8bf7}\u{68c0}\u{67e5}\u{683c}\u{5f0f}\u{3002}"
            feedbackIsPositive = false
            page = .library
            render()
            return
        }
        let paper = Paper(title: title, source: source, questions: parsed)
        papers.append(paper)
        activePaperIndex = papers.count - 1
        order = Array(parsed.indices)
        optionOrders.removeAll()
        currentIndex = 0
        selectedAnswers.removeAll()
        feedbackText = "\u{5df2}\u{5bfc}\u{5165} \(parsed.count) \u{9898}"
        feedbackIsPositive = true
        page = .library
        render()
    }

    @objc private func openFileImporter() {
        let types: [UTType] = [.plainText, .pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let title = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            let text = extractPDFText(from: url)
            importQuestions(from: text, title: title, source: "PDF")
        } else {
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            importQuestions(from: text, title: title, source: "TXT")
        }
    }

    private func extractPDFText(from url: URL) -> String {
        guard let document = PDFDocument(url: url) else { return "" }
        var text = ""
        for index in 0..<document.pageCount {
            text += document.page(at: index)?.string ?? ""
            text += "\n"
        }
        return text
    }

    @objc private func clearWrongQuestions() {
        wrongQuestions.removeAll()
        render()
    }

    @objc private func autoNextChanged(_ sender: UISwitch) {
        autoNextEnabled = sender.isOn
        render()
    }

    @objc private func shuffleOptionsChanged(_ sender: UISwitch) {
        shuffleOptionsEnabled = sender.isOn
        optionOrders.removeAll()
        selectedAnswers.removeAll()
        feedbackText = nil
        render()
    }
}

private extension UIButton {
    func alignImageAboveTitle(spacing: CGFloat) {
        guard
            let imageSize = imageView?.image?.size,
            let text = titleLabel?.text,
            let font = titleLabel?.font
        else { return }

        let titleSize = (text as NSString).size(withAttributes: [.font: font])
        titleEdgeInsets = UIEdgeInsets(
            top: imageSize.height + spacing,
            left: -imageSize.width,
            bottom: 0,
            right: 0
        )
        imageEdgeInsets = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: titleSize.height + spacing,
            right: -titleSize.width
        )
        contentEdgeInsets = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
    }
}
