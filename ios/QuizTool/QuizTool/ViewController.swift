import UIKit
import PDFKit
import PhotosUI
import UniformTypeIdentifiers
import Vision

final class ViewController: UIViewController, UIDocumentPickerDelegate, PHPickerViewControllerDelegate, UIGestureRecognizerDelegate {
    private struct Paper: Codable {
        let title: String
        let source: String
        let questions: [Question]
    }

    private struct AppState: Codable {
        let papers: [Paper]
        let activePaperIndex: Int
        let wrongQuestions: [Question]
        let currentIndex: Int
        let modeTitle: String
        let autoNextEnabled: Bool
        let shuffleOptionsEnabled: Bool
        let apiEndpoint: String
        let apiKey: String
    }

    private enum Page: Int {
        case home = 0
        case library = 1
        case importText = 2
        case wrong = 3
        case profile = 4
        case search = 5
        case apiConfig = 6
        case practiceMode = 7
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
    private let storageKey = "YuntiV11AppState"
    private var panStartOffset: CGPoint = .zero
    private var importTextView: UITextView?
    private var searchResultsStack: UIStackView?
    private var apiEndpointField: UITextField?
    private var apiKeyField: UITextField?
    private var feedbackText: String?
    private var feedbackIsPositive = true
    private var autoNextEnabled = true
    private var shuffleOptionsEnabled = true
    private var apiEndpoint = ""
    private var apiKey = ""
    private var searchQuery = ""

    private var papers: [Paper] = []
    private var activePaperIndex = 0
    private var wrongQuestions: [Question] = []
    private var focusedPracticeQuestions: [Question]?
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
        focusedPracticeQuestions ?? (papers.isEmpty ? [] : activePaper.questions)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        view.backgroundColor = appBackgroundColor
        configureSeedData()
        loadPersistedState()
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

    private func loadPersistedState() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let state = try? JSONDecoder().decode(AppState.self, from: data),
            !state.papers.isEmpty
        else { return }
        papers = state.papers
        activePaperIndex = min(max(state.activePaperIndex, 0), papers.count - 1)
        wrongQuestions = state.wrongQuestions
        currentIndex = max(state.currentIndex, 0)
        modeTitle = state.modeTitle
        autoNextEnabled = state.autoNextEnabled
        shuffleOptionsEnabled = state.shuffleOptionsEnabled
        apiEndpoint = state.apiEndpoint
        apiKey = state.apiKey
        let maxIndex = max(activeQuestions.count - 1, 0)
        currentIndex = min(currentIndex, maxIndex)
        order = activeQuestions.isEmpty ? [] : Array(activeQuestions.indices)
    }

    private func savePersistedState() {
        let state = AppState(
            papers: papers,
            activePaperIndex: activePaperIndex,
            wrongQuestions: wrongQuestions,
            currentIndex: currentIndex,
            modeTitle: modeTitle,
            autoNextEnabled: autoNextEnabled,
            shuffleOptionsEnabled: shuffleOptionsEnabled,
            apiEndpoint: apiEndpoint,
            apiKey: apiKey
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
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
        tabStack.layoutMargins = UIEdgeInsets(top: 12, left: 10, bottom: 20, right: 10)
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
            tabStack.heightAnchor.constraint(equalToConstant: 94)
        ])
    }

    private func configureSwipeGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePracticePan(_:)))
        pan.delegate = self
        pan.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(pan)
    }

    private func render(animated: Bool = false) {
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
            case .search:
                self.renderSearch()
            case .apiConfig:
                self.renderAPIConfig()
            case .practiceMode:
                self.renderPracticeMode()
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

    private func setPage(_ nextPage: Page, animated: Bool = false) {
        page = nextPage
        render(animated: animated)
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
        addTopBar(title: "\u{4e91}\u{9898} V11", chipTitle: "\u{5bfc}\u{5165}", action: #selector(openImportPage))
        addSearchField()
        addListGroup([
            paperRow(activePaper, index: activePaperIndex),
            row("\u{7ee7}\u{7eed}\u{7ec3}\u{4e60}", subtitle: "\(currentIndex + 1) / \(max(order.count, 1))", action: #selector(openCurrentPaper)),
            row("\u{968f}\u{673a}\u{7ec3}\u{4e60}", subtitle: "\u{4ece}\u{5f53}\u{524d}\u{9898}\u{5e93}\u{6253}\u{4e71}\u{9898}\u{76ee}\u{987a}\u{5e8f}", action: #selector(openRandomPractice))
        ])
    }

    private func renderLibrary() {
        addTopBar(title: "\u{9898}\u{5e93}", chipTitle: "\u{5bfc}\u{5165}", action: #selector(openImportPage))
        addSearchField()
        var rows: [UIView] = []
        for index in papers.indices {
            let paper = papers[index]
            rows.append(paperRow(paper, index: index))
        }
        addListGroup(rows)
    }

    private func renderImport() {
        addTitle("\u{5bfc}\u{5165}", "\u{6587}\u{4ef6}\u{5bfc}\u{5165}\u{4f18}\u{5148}\u{652f}\u{6301} TXT/PDF\u{ff0c}Word \u{540e}\u{7eed}\u{63a5} API \u{89e3}\u{6790}\u{66f4}\u{7a33}\u{3002}")
        addListGroup([
            row("\u{6587}\u{4ef6}\u{5bfc}\u{5165}", subtitle: "TXT / PDF", action: #selector(openFileImporter)),
            row("\u{56fe}\u{7247}\u{8bc6}\u{522b}\u{5bfc}\u{5165}", subtitle: "\u{622a}\u{56fe} / \u{7167}\u{7247} OCR", action: #selector(openImageImporter)),
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
        addTopBar(title: focusedPracticeQuestions == nil ? activePaper.title : "\u{9519}\u{9898}\u{7ec3}\u{4e60}", chipTitle: modeTitle, action: nil)
        addPracticeMeta()
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
    }

    private func renderWrong() {
        addTitle("\u{9519}\u{9898}", "\u{8de8}\u{9898}\u{5e93}\u{6536}\u{85cf}\u{4f60}\u{7b54}\u{9519}\u{7684}\u{9898}\u{3002}")
        if wrongQuestions.isEmpty {
            addEmptyState("\u{6682}\u{65e0}\u{9519}\u{9898}", "\u{53bb}\u{9898}\u{5e93}\u{5f00}\u{59cb}\u{4e00}\u{7ec4}\u{7ec3}\u{4e60}\u{5427}\u{3002}")
        } else {
            let practice = makeButton("\u{5f00}\u{59cb}\u{9519}\u{9898}\u{7ec3}\u{4e60}", style: .primary)
            practice.addTarget(self, action: #selector(startWrongPractice), for: .touchUpInside)
            contentStack.addArrangedSubview(practice)
            for question in wrongQuestions {
                addCard([makeText(question.prompt, size: 15, weight: .semibold), makeText(question.explanation, size: 13, weight: .regular, color: .secondaryLabel)])
            }
            let clear = makeButton("\u{6e05}\u{7a7a}\u{9519}\u{9898}", style: .danger)
            clear.addTarget(self, action: #selector(clearWrongQuestions), for: .touchUpInside)
            contentStack.addArrangedSubview(clear)
        }
    }

    private func renderProfile() {
        addTopBar(title: "\u{6211}\u{7684}", chipTitle: "V11", action: nil)
        contentStack.addArrangedSubview(iconSwitchRow(symbol: "\u{2192}", color: accentColor, title: "\u{7b54}\u{5bf9}\u{540e}\u{81ea}\u{52a8}\u{4e0b}\u{4e00}\u{9898}", subtitle: "\u{7b54}\u{5bf9}\u{76f4}\u{63a5}\u{5207}\u{9898}\u{ff0c}\u{7b54}\u{9519}\u{663e}\u{793a}\u{89e3}\u{6790}", isOn: autoNextEnabled, action: #selector(autoNextChanged(_:))))
        contentStack.addArrangedSubview(iconSwitchRow(symbol: "A", color: UIColor(red: 0.12, green: 0.47, blue: 0.90, alpha: 1), title: "\u{9009}\u{9879}\u{968f}\u{673a}\u{6392}\u{5e8f}", subtitle: "\u{8fd4}\u{56de}\u{540c}\u{9898}\u{65f6}\u{987a}\u{5e8f}\u{4fdd}\u{6301}\u{4e0d}\u{53d8}", isOn: shuffleOptionsEnabled, action: #selector(shuffleOptionsChanged(_:))))
        contentStack.addArrangedSubview(iconInfoRow(symbol: "AI", color: UIColor(red: 0.06, green: 0.42, blue: 0.92, alpha: 1), title: "API \u{914d}\u{7f6e}", subtitle: apiEndpoint.isEmpty ? "\u{7528}\u{4e8e}\u{6587}\u{6863}\u{8bc6}\u{522b}\u{548c}\u{89e3}\u{6790}\u{589e}\u{5f3a}" : "\u{5df2}\u{914d}\u{7f6e}\u{63a5}\u{53e3}", action: #selector(openAPIConfig)))
        contentStack.addArrangedSubview(iconInfoRow(symbol: "\u{21bb}", color: UIColor(red: 0.97, green: 0.57, blue: 0.08, alpha: 1), title: "\u{7ec3}\u{4e60}\u{6a21}\u{5f0f}", subtitle: "\u{987a}\u{5e8f}\u{7ec3}\u{4e60} / \u{968f}\u{673a}\u{7ec3}\u{4e60}", action: #selector(openPracticeMode)))
    }

    private func renderSearch() {
        addTopBar(title: "\u{641c}\u{7d22}\u{8bd5}\u{5377}", chipTitle: "\u{8fd4}\u{56de}", action: #selector(backToLibrary))
        let field = UITextField()
        field.text = searchQuery
        field.placeholder = "\u{8f93}\u{5165}\u{9898}\u{5e93}\u{540d}\u{6216}\u{6765}\u{6e90}"
        field.font = UIFont.systemFont(ofSize: 16)
        field.backgroundColor = cardBackgroundColor
        field.layer.cornerRadius = 15
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 48).isActive = true
        field.addTarget(self, action: #selector(searchChanged(_:)), for: .editingChanged)
        contentStack.addArrangedSubview(field)

        let results = UIStackView()
        results.axis = .vertical
        results.backgroundColor = cardBackgroundColor
        results.layer.cornerRadius = 18
        results.clipsToBounds = true
        searchResultsStack = results
        contentStack.addArrangedSubview(results)
        refreshSearchResults()
    }

    private func renderAPIConfig() {
        addTopBar(title: "API \u{914d}\u{7f6e}", chipTitle: "\u{8fd4}\u{56de}", action: #selector(backToProfile))
        addEmptyState("\u{6587}\u{6863}\u{89e3}\u{6790}\u{589e}\u{5f3a}", "\u{586b}\u{5165}\u{63a5}\u{53e3}\u{548c} Key\u{ff0c}\u{540e}\u{7eed}\u{53ef}\u{7528}\u{4e8e} Word/PDF \u{590d}\u{6742}\u{7248}\u{5f0f}\u{8bc6}\u{522b}\u{3002}")
        apiEndpointField = makeInput(placeholder: "API URL", text: apiEndpoint, secure: false)
        apiKeyField = makeInput(placeholder: "API Key", text: apiKey, secure: true)
        if let apiEndpointField { contentStack.addArrangedSubview(apiEndpointField) }
        if let apiKeyField { contentStack.addArrangedSubview(apiKeyField) }
        let save = makeButton("\u{4fdd}\u{5b58}\u{914d}\u{7f6e}", style: .primary)
        save.addTarget(self, action: #selector(saveAPIConfig), for: .touchUpInside)
        contentStack.addArrangedSubview(save)
    }

    private func renderPracticeMode() {
        addTopBar(title: "\u{7ec3}\u{4e60}\u{6a21}\u{5f0f}", chipTitle: "\u{8fd4}\u{56de}", action: #selector(backToProfile))
        addListGroup([
            row("\u{987a}\u{5e8f}\u{7ec3}\u{4e60}", subtitle: "\u{6309}\u{9898}\u{5e93}\u{539f}\u{59cb}\u{987a}\u{5e8f}\u{5f00}\u{59cb}", action: #selector(selectSequentialMode)),
            row("\u{968f}\u{673a}\u{7ec3}\u{4e60}", subtitle: "\u{6253}\u{4e71}\u{9898}\u{76ee}\u{987a}\u{5e8f}\u{ff0c}\u{9002}\u{5408}\u{590d}\u{4e60}", action: #selector(selectRandomMode)),
            row("\u{9519}\u{9898}\u{7ec3}\u{4e60}", subtitle: wrongQuestions.isEmpty ? "\u{6682}\u{65e0}\u{9519}\u{9898}" : "\(wrongQuestions.count) \u{9898}\u{5f85}\u{5de9}\u{56fa}", action: #selector(startWrongPractice))
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

    private func addTopBar(title: String, chipTitle: String?, action: Selector?) {
        let titleLabel = makeText(title, size: 22, weight: .bold)
        let spacer = UIView()
        let row = UIStackView(arrangedSubviews: [titleLabel, spacer])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        if let chipTitle {
            let chip = makeChip(chipTitle)
            if let action {
                chip.addTarget(self, action: action, for: .touchUpInside)
            }
            row.addArrangedSubview(chip)
        }
        contentStack.addArrangedSubview(row)
    }

    private func makeChip(_ title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        button.backgroundColor = cardBackgroundColor.withAlphaComponent(0.82)
        button.tintColor = UIColor.label
        button.layer.cornerRadius = 16
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    private func addPracticeMeta() {
        let text = "\(currentIndex + 1) / \(order.count)  \(activeQuestions[order[currentIndex]].kind)"
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        let currentRange = NSRange(location: 0, length: "\(currentIndex + 1)".count)
        attributed.addAttributes([
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: UIColor.label
        ], range: currentRange)
        let label = UILabel()
        label.attributedText = attributed
        label.numberOfLines = 1
        contentStack.addArrangedSubview(label)
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
        labels.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let spacer = UIView()
        let arrow = makeText("\u{203a}", size: 24, weight: .regular, color: .tertiaryLabel)
        arrow.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [labels, spacer, arrow])
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

    private func addSearchField() {
        let label = makeText("\u{2315}  \u{641c}\u{7d22}\u{8bd5}\u{5377}", size: 15, weight: .regular, color: .secondaryLabel)
        label.textAlignment = .center
        let container = UIStackView(arrangedSubviews: [label])
        container.alignment = .center
        container.layoutMargins = UIEdgeInsets(top: 11, left: 14, bottom: 11, right: 14)
        container.isLayoutMarginsRelativeArrangement = true
        container.backgroundColor = cardBackgroundColor
        container.layer.cornerRadius = 15
        let tap = UITapGestureRecognizer(target: self, action: #selector(openSearchPage))
        container.addGestureRecognizer(tap)
        container.isUserInteractionEnabled = true
        contentStack.addArrangedSubview(container)
    }

    private func paperRow(_ paper: Paper, index: Int) -> UIView {
        let source = paper.source.uppercased()
        let badgeText = source.contains("PDF") ? "PDF" : (source.contains("TXT") ? "TXT" : (source.contains("IMG") || source.contains("OCR") ? "IMG" : "DOC"))
        let badge = makeBadge(text: badgeText, color: badgeColor(for: badgeText))
        let titleLabel = makeText(paper.title, size: 16, weight: .bold)
        let mode = index == activePaperIndex ? modeTitle : "\u{987a}\u{5e8f}\u{7ec3}\u{4e60}"
        let progress = "\(min(currentIndex + 1, max(order.count, 1)))/\(max(order.count, 1))"
        let state = index == activePaperIndex ? "\(progress) \u{00b7} \u{7ee7}\u{7eed}" : "\u{672a}\u{5f00}\u{59cb}"
        let subtitle = "\(paper.questions.count) \u{9898} \u{00b7} \(mode) \u{00b7} \(state)"
        let subtitleLabel = makeText(subtitle, size: 13, weight: .regular, color: .secondaryLabel)
        let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labels.axis = .vertical
        labels.spacing = 3
        labels.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let spacer = UIView()
        let timeLabel = makeText(index == 0 ? "\u{4eca}\u{5929}" : "\u{6628}\u{5929}", size: 12, weight: .regular, color: .tertiaryLabel)
        timeLabel.textAlignment = .right
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [badge, labels, spacer, timeLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        row.isLayoutMarginsRelativeArrangement = true
        row.tag = index
        let tap = UITapGestureRecognizer(target: self, action: #selector(paperTapped(_:)))
        row.addGestureRecognizer(tap)
        let deleteSwipe = UISwipeGestureRecognizer(target: self, action: #selector(paperDeleteSwiped(_:)))
        deleteSwipe.direction = .left
        row.addGestureRecognizer(deleteSwipe)
        row.isUserInteractionEnabled = true
        return row
    }

    private func makeBadge(text: String, color: UIColor) -> UILabel {
        let label = makeText(text, size: 12, weight: .bold, color: .white)
        label.textAlignment = .center
        label.backgroundColor = color
        label.layer.cornerRadius = 13
        label.clipsToBounds = true
        label.widthAnchor.constraint(equalToConstant: 48).isActive = true
        label.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return label
    }

    private func badgeColor(for text: String) -> UIColor {
        switch text {
        case "PDF":
            return UIColor(red: 0.09, green: 0.74, blue: 0.43, alpha: 1)
        case "DOC":
            return UIColor(red: 0.05, green: 0.55, blue: 0.92, alpha: 1)
        case "IMG":
            return UIColor(red: 0.58, green: 0.34, blue: 0.92, alpha: 1)
        default:
            return UIColor(red: 0.98, green: 0.62, blue: 0.08, alpha: 1)
        }
    }

    private func iconInfoRow(symbol: String, color: UIColor, title: String, subtitle: String, action: Selector? = nil) -> UIView {
        let icon = makeBadge(text: symbol, color: color)
        let titleLabel = makeText(title, size: 16, weight: .bold)
        let subtitleLabel = makeText(subtitle, size: 13, weight: .regular, color: .secondaryLabel)
        let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labels.axis = .vertical
        labels.spacing = 3
        labels.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let spacer = UIView()
        let arrow = makeText("\u{203a}", size: 20, weight: .regular, color: .tertiaryLabel)
        arrow.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [icon, labels, spacer, arrow])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        row.isLayoutMarginsRelativeArrangement = true
        row.backgroundColor = cardBackgroundColor.withAlphaComponent(0.82)
        row.layer.cornerRadius = 18
        if let action {
            let tap = UITapGestureRecognizer(target: self, action: action)
            row.addGestureRecognizer(tap)
            row.isUserInteractionEnabled = true
        }
        return row
    }

    private func iconSwitchRow(symbol: String, color: UIColor, title: String, subtitle: String, isOn: Bool, action: Selector) -> UIView {
        let icon = makeBadge(text: symbol, color: color)
        let titleLabel = makeText(title, size: 16, weight: .bold)
        let subtitleLabel = makeText(subtitle, size: 13, weight: .regular, color: .secondaryLabel)
        let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labels.axis = .vertical
        labels.spacing = 3
        labels.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let toggle = UISwitch()
        toggle.onTintColor = accentColor
        toggle.isOn = isOn
        toggle.addTarget(self, action: action, for: .valueChanged)
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        let spacer = UIView()
        let row = UIStackView(arrangedSubviews: [icon, labels, spacer, toggle])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.layoutMargins = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        row.isLayoutMarginsRelativeArrangement = true
        row.backgroundColor = cardBackgroundColor.withAlphaComponent(0.82)
        row.layer.cornerRadius = 18
        return row
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
        let prompt = makeText(question.prompt, size: 18, weight: .bold)
        addCard([chip, prompt])
    }

    private func optionsForCurrentQuestion(_ question: Question) -> [Option] {
        let questionIndex = order.isEmpty ? currentIndex : order[currentIndex]
        let cachePrefix = focusedPracticeQuestions == nil ? "\(activePaperIndex)" : "wrong"
        let cacheKey = "\(cachePrefix)-\(questionIndex)"
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

    private func makeInput(placeholder: String, text: String, secure: Bool) -> UITextField {
        let field = UITextField()
        field.text = text
        field.placeholder = placeholder
        field.font = UIFont.systemFont(ofSize: 16)
        field.backgroundColor = cardBackgroundColor
        field.layer.cornerRadius = 15
        field.isSecureTextEntry = secure
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return field
    }

    private func makeOptionButton(_ option: Option, displayKey: String, selected: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = option.key
        button.backgroundColor = selected ? softGreenColor : cardBackgroundColor
        button.tintColor = UIColor.label
        button.layer.borderWidth = selected ? 1 : 0.5
        button.layer.borderColor = selected ? accentColor.withAlphaComponent(0.32).cgColor : UIColor.separator.cgColor
        button.layer.cornerRadius = 17
        button.contentHorizontalAlignment = .fill
        button.contentVerticalAlignment = .fill

        let letterLabel = UILabel()
        letterLabel.text = displayKey
        letterLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        letterLabel.textAlignment = .center
        letterLabel.textColor = selected ? UIColor.white : UIColor.label
        letterLabel.backgroundColor = selected ? accentColor : UIColor.tertiarySystemFill
        letterLabel.layer.cornerRadius = 13
        letterLabel.clipsToBounds = true
        letterLabel.translatesAutoresizingMaskIntoConstraints = false

        let textLabel = UILabel()
        textLabel.text = option.text
        textLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        textLabel.textColor = selected ? accentColor : UIColor.label
        textLabel.numberOfLines = 0
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        button.addSubview(letterLabel)
        button.addSubview(textLabel)
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
            letterLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 14),
            letterLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            letterLabel.widthAnchor.constraint(equalToConstant: 26),
            letterLabel.heightAnchor.constraint(equalToConstant: 26),
            textLabel.leadingAnchor.constraint(equalTo: letterLabel.trailingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
            textLabel.topAnchor.constraint(equalTo: button.topAnchor, constant: 12),
            textLabel.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -12)
        ])
        return button
    }

    private func makeTabButton(icon: String, title: String, selected: Bool) -> UIButton {
        let button = UIButton(type: .system)
        let color = selected ? accentColor : UIColor.label
        let image = UIImage(systemName: icon)?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 19, weight: .regular))
        var configuration = UIButton.Configuration.plain()
        configuration.image = image
        configuration.title = title
        configuration.imagePlacement = .top
        configuration.imagePadding = 6
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        configuration.baseForegroundColor = color
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
            return outgoing
        }
        button.configuration = configuration
        button.contentHorizontalAlignment = .center
        button.contentVerticalAlignment = .center
        button.backgroundColor = UIColor.clear
        button.tintColor = color
        button.imageView?.contentMode = .scaleAspectFit
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

    private func refreshSearchResults() {
        guard let searchResultsStack else { return }
        clearStack(searchResultsStack)
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = papers.enumerated().filter { index, paper in
            trimmed.isEmpty ||
                paper.title.localizedCaseInsensitiveContains(trimmed) ||
                paper.source.localizedCaseInsensitiveContains(trimmed) ||
                (index == activePaperIndex && "\u{7ee7}\u{7eed}".contains(trimmed))
        }
        if matched.isEmpty {
            let empty = row("\u{672a}\u{627e}\u{5230}\u{8bd5}\u{5377}", subtitle: "\u{6362}\u{4e2a}\u{5173}\u{952e}\u{8bcd}\u{8bd5}\u{8bd5}", action: nil)
            searchResultsStack.addArrangedSubview(empty)
            return
        }
        for item in matched {
            searchResultsStack.addArrangedSubview(paperRow(item.element, index: item.offset))
        }
    }

    @objc private func tabTapped(_ sender: UIButton) {
        autoTimer?.invalidate()
        feedbackText = nil
        focusedPracticeQuestions = nil
        setPage(Page(rawValue: sender.tag) ?? .home, animated: false)
    }

    @objc private func openSearchPage() {
        setPage(.search, animated: false)
    }

    @objc private func openImportPage() {
        setPage(.importText, animated: false)
    }

    @objc private func openAPIConfig() {
        setPage(.apiConfig, animated: false)
    }

    @objc private func openPracticeMode() {
        setPage(.practiceMode, animated: false)
    }

    @objc private func backToProfile() {
        setPage(.profile, animated: false)
    }

    @objc private func backToLibrary() {
        setPage(.library, animated: false)
    }

    @objc private func searchChanged(_ sender: UITextField) {
        searchQuery = sender.text ?? ""
        refreshSearchResults()
    }

    @objc private func saveAPIConfig() {
        apiEndpoint = apiEndpointField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        apiKey = apiKeyField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        UserDefaults.standard.set(apiEndpoint, forKey: "apiEndpoint")
        UserDefaults.standard.set(apiKey, forKey: "apiKey")
        savePersistedState()
        feedbackText = "\u{914d}\u{7f6e}\u{5df2}\u{4fdd}\u{5b58}"
        feedbackIsPositive = true
        setPage(.profile, animated: false)
    }

    @objc private func selectSequentialMode() {
        focusedPracticeQuestions = nil
        startPaper(index: activePaperIndex, random: false)
    }

    @objc private func selectRandomMode() {
        focusedPracticeQuestions = nil
        startPaper(index: activePaperIndex, random: true)
    }

    @objc private func openCurrentPaper() {
        focusedPracticeQuestions = nil
        startPaper(index: activePaperIndex, random: false)
    }

    @objc private func openRandomPractice() {
        focusedPracticeQuestions = nil
        startPaper(index: activePaperIndex, random: true)
    }

    @objc private func paperTapped(_ sender: UITapGestureRecognizer) {
        guard let index = sender.view?.tag else { return }
        startPaper(index: index, random: false)
    }

    @objc private func paperDeleteSwiped(_ sender: UISwipeGestureRecognizer) {
        guard let index = sender.view?.tag, papers.indices.contains(index) else { return }
        confirmDeletePaper(at: index)
    }

    private func confirmDeletePaper(at index: Int) {
        let paper = papers[index]
        let alert = UIAlertController(
            title: "\u{5220}\u{9664}\u{9898}\u{5e93}",
            message: "\u{786e}\u{5b9a}\u{5220}\u{9664}\u{300c}\(paper.title)\u{300d}\u{5417}\u{ff1f}\u{8fd9}\u{4e2a}\u{64cd}\u{4f5c}\u{4f1a}\u{4ece}\u{672c}\u{673a}\u{4fdd}\u{5b58}\u{4e2d}\u{79fb}\u{9664}\u{3002}",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "\u{53d6}\u{6d88}", style: .cancel))
        alert.addAction(UIAlertAction(title: "\u{5220}\u{9664}\u{9898}\u{5e93}", style: .destructive) { [weak self] _ in
            self?.deletePaper(at: index)
        })
        present(alert, animated: true)
    }

    private func deletePaper(at index: Int) {
        guard papers.indices.contains(index), papers.count > 1 else {
            feedbackText = "\u{81f3}\u{5c11}\u{9700}\u{4fdd}\u{7559}\u{4e00}\u{4efd}\u{9898}\u{5e93}"
            feedbackIsPositive = false
            render()
            return
        }
        papers.remove(at: index)
        if activePaperIndex >= papers.count {
            activePaperIndex = papers.count - 1
        } else if index < activePaperIndex {
            activePaperIndex -= 1
        }
        currentIndex = 0
        order = Array(activeQuestions.indices)
        optionOrders.removeAll()
        selectedAnswers.removeAll()
        feedbackText = "\u{9898}\u{5e93}\u{5df2}\u{5220}\u{9664}"
        feedbackIsPositive = true
        savePersistedState()
        render()
    }

    private func startPaper(index: Int, random: Bool) {
        guard papers.indices.contains(index) else { return }
        activePaperIndex = index
        focusedPracticeQuestions = nil
        let questions = activeQuestions
        order = random ? Array(questions.indices).shuffled() : Array(questions.indices)
        optionOrders.removeAll()
        modeTitle = random ? "\u{968f}\u{673a}\u{7ec3}\u{4e60}" : "\u{987a}\u{5e8f}\u{7ec3}\u{4e60}"
        currentIndex = 0
        selectedAnswers.removeAll()
        feedbackText = nil
        savePersistedState()
        setPage(.practice, animated: false)
    }

    @objc private func startWrongPractice() {
        guard !wrongQuestions.isEmpty else {
            setPage(.wrong, animated: false)
            return
        }
        focusedPracticeQuestions = wrongQuestions
        order = Array(wrongQuestions.indices)
        optionOrders.removeAll()
        modeTitle = "\u{9519}\u{9898}\u{7ec3}\u{4e60}"
        currentIndex = 0
        selectedAnswers.removeAll()
        feedbackText = nil
        setPage(.practice, animated: false)
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
                savePersistedState()
                render()
            }
        } else {
            if !wrongQuestions.contains(where: { $0.prompt == question.prompt }) {
                wrongQuestions.append(question)
                savePersistedState()
            }
            feedbackText = "\u{7b54}\u{9519}\u{4e86}\u{ff1a}\(question.explanation)"
            feedbackIsPositive = false
            savePersistedState()
            render()
        }
    }

    private func advanceAfterCorrectAnswer() {
        guard currentIndex < order.count - 1 else {
            feedbackText = "\u{5df2}\u{5b8c}\u{6210}\u{672c}\u{7ec4}\u{7ec3}\u{4e60}"
            feedbackIsPositive = true
            savePersistedState()
            render()
            return
        }
        feedbackText = nil
        render()
        autoTimer?.invalidate()
        autoTimer = Timer.scheduledTimer(withTimeInterval: 0.24, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.currentIndex += 1
            self.selectedAnswers.removeAll()
            self.savePersistedState()
            self.renderSlideToNext()
        }
    }

    private func renderSlideToNext() {
        renderCalmQuestionChange()
    }

    private func renderCalmQuestionChange() {
        UIView.transition(with: contentStack, duration: 0.16, options: [.transitionCrossDissolve, .allowUserInteraction]) {
            self.clearStack(self.contentStack)
            self.renderTabs()
            self.renderPractice()
            self.contentStack.alpha = 1
            self.contentStack.transform = .identity
        }
    }

    @objc private func nextQuestion() {
        guard !order.isEmpty else { return }
        currentIndex = min(currentIndex + 1, order.count - 1)
        selectedAnswers.removeAll()
        feedbackText = nil
        savePersistedState()
        page = .practice
        renderCalmQuestionChange()
    }

    @objc private func previousQuestion() {
        guard !order.isEmpty else { return }
        currentIndex = max(currentIndex - 1, 0)
        selectedAnswers.removeAll()
        feedbackText = nil
        savePersistedState()
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
                contentStack.transform = CGAffineTransform(translationX: translation.x * 0.03, y: 0)
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
            setPage(.library, animated: false)
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
        savePersistedState()
        setPage(.library, animated: false)
    }

    @objc private func openFileImporter() {
        let types: [UTType] = [.plainText, .pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    @objc private func openImageImporter() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }
        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self, let image = object as? UIImage else { return }
                self.recognizeText(from: image) { text in
                    DispatchQueue.main.async {
                        self.importQuestions(from: text, title: "\u{56fe}\u{7247}\u{8bc6}\u{522b}\u{9898}\u{5e93}", source: "IMG OCR")
                    }
                }
            }
        }
    }

    private func recognizeText(from image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage else {
            completion("")
            return
        }
        let request = VNRecognizeTextRequest { request, _ in
            let text = (request.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""
            completion(text)
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = true
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                completion("")
            }
        }
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
        savePersistedState()
        render()
    }

    @objc private func autoNextChanged(_ sender: UISwitch) {
        autoNextEnabled = sender.isOn
        savePersistedState()
        render()
    }

    @objc private func shuffleOptionsChanged(_ sender: UISwitch) {
        shuffleOptionsEnabled = sender.isOn
        optionOrders.removeAll()
        selectedAnswers.removeAll()
        feedbackText = nil
        savePersistedState()
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
