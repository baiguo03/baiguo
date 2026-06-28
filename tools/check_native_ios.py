from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


view = read("ios/QuizTool/QuizTool/ViewController.swift")
parser = read("ios/QuizTool/QuizTool/QuestionParser.swift")
project = read("ios/QuizTool/QuizTool.xcodeproj/project.pbxproj")
plist = read("ios/QuizTool/QuizTool/Info.plist")
yaml = read("codemagic.yaml")

for old in [
    "QuizNativeV11",
    "QuizNativeV10",
    "QuizNativeV9",
    "QuizNativeV8",
    "QuizNativeV7",
    "QuizNativeV6",
    "QuizNativeV5",
    "QuizNativeV4",
    "QuizNativeV3",
    "QuizNativeV2",
    "云题 V11",
    "&#x4e91;&#x9898;V11",
]:
    require(old not in view + parser + project + plist + yaml, f"old marker remains: {old}")

require("PRODUCT_NAME = Lizi;" in project, "missing Lizi product")
require("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;" in project, "missing AppIcon setting")
require("QuestionParser.swift in Sources" in project, "parser is not in sources")
require("insertBreaksBeforeInlineQuestionStarts" in parser, "parser does not split inline question starts")
require("stripAnswerSummary" in parser, "parser does not remove answer summary blocks")
require("extractAnswerSummaryAnswers" in parser, "parser does not read answer summary mappings")
require("objectiveIndex < summaryAnswers.count" in parser and "summaryAnswers[objectiveIndex]" in parser, "parser does not apply summary answers by appearance order")
require("freeformAnswers[freeformIndex]" in parser and "extractFreeformSummaryAnswers" in parser, "parser does not apply freeform summary answers")
require("normalizeAnswerKeys" in parser, "parser does not normalize summary answers")
require("isSectionHeading" in parser and "\\u{5355}\\u{9879}\\u{9009}\\u{62e9}\\u{9898}" in parser, "parser does not skip paper section headings")
require("isCaseQuestionStart" in parser, "case-analysis questions are not kept as whole blocks")
require("stuckQuestionPattern" in parser, "parser does not split stuck answer/question boundaries")
require("inlineJudgementPattern" in parser, "parser does not split inline judgement questions")
require("candidateAnswer" in parser and "openAnswer" in parser, "open questions still use objective summary answers")
require("inferOpenQuestionKind" in parser and "\\u{586b}\\u{7a7a}\\u{9898}" in parser, "fill-in questions are not supported")
require("\\u{7b80}\\u{7b54}\\u{9898}" in parser and "\\u{914d}\\u{4f0d}\\u{9898}" in parser, "short answer/matching questions are not supported")
require("Lizi.ipa" in yaml, "Codemagic artifact is not Lizi")
require("<string>李子</string>" in plist, "display name is not Lizi")
require("UIUserInterfaceStyle" in plist and "<string>Light</string>" in plist, "app does not force light appearance")
require("overrideUserInterfaceStyle = .light" in view, "view controller does not force light appearance")
require("autoNextEnabled" in view and "UISwitch" in view, "auto-next switch not wired")
require("shuffleOptionsEnabled" in view and "optionOrders" in view, "option shuffle setting/order cache missing")
require("Codable" in view and "AppState" in view, "app state persistence model is missing")
require("loadPersistedState" in view and "savePersistedState" in view, "app state persistence is not wired")
require("legacyStorageKey" in view and '"Yunti" + "V11AppState"' in view, "old saved app state is not migrated")
require("defaults.data(forKey: storageKey)" in view and "persistedData" in view, "persisted app state is not loaded")
require("UserDefaults.standard.set(data, forKey: storageKey)" in view, "persisted app state is not saved")
require("case search" in view and "renderSearch" in view and "openSearchPage" in view, "search entry is not wired")
require("case apiConfig" in view and "renderAPIConfig" in view and "openAPIConfig" in view, "api config entry is not wired")
require("AIParseRequest" in view and "AIParseResponse" in view and "AIQuestionPayload" in view, "AI parse API models are missing")
require("aiImportTapped" in view and "requestAIParse" in view and "decodeAIQuestions" in view, "AI-assisted import flow is missing")
require("URLSession.shared.dataTask" in view and '"Authorization"' in view and '"Bearer \\(apiKey)"' in view, "AI parse request does not call configured backend securely")
require("QuestionParser.parse(response.text" in view and "normalizedAnswerKeys" in view, "AI parse response fallback/normalization is missing")
require("case practiceMode" in view and "renderPracticeMode" in view and "openPracticeMode" in view, "practice mode entry is not wired")
require("startWrongPractice" in view and "focusedPracticeQuestions" in view, "wrong question practice is missing")
require('"wrong"' in view and "cachePrefix" in view, "wrong practice option cache is not isolated")
require("wrongQuestions.contains" in view, "wrong questions can be duplicated")
require("UIPanGestureRecognizer" in view and "translation.x > 36" in view and "velocity.x > 420" in view, "sensitive horizontal swipe gestures missing")
require("appBackgroundColor" in view and "softGreenColor" in view, "V11 palette is not in native UI")
require("UIFont.systemFont(ofSize: 24" in view, "native title size is still too heavy")
require("tabStack.heightAnchor.constraint(equalToConstant: 82)" in view, "native tab bar height is not balanced")
require("UIEdgeInsets(top: 8, left: 10, bottom: 10, right: 10)" in view, "native tab bar vertical padding is too tight")
require("UIImage(systemName:" in view, "native bottom tabs still use text glyphs")
require("addTopBar" in view and "makeChip" in view, "browser-style top bar/chip is missing")
require('addTopBar(title: "李子"' in view, "home title is not Lizi")
require('addTopBar(title: "\\u{6211}\\u{7684}", chipTitle: nil' in view, "profile still shows V11 badge")
require("button.layer.cornerRadius = 17" in view, "native option rows do not match V11 preview")
require("stack.layer.cornerRadius = 18" in view, "native cards/lists are still too bulky")
require("addSearchField" in view and "\\u{641c}\\u{7d22}\\u{8bd5}\\u{5377}" in view, "library search field is missing")
require('UIImage(systemName: "magnifyingglass")' in view and "\\u{2315}" not in view, "search field still uses an off-ratio text magnifier")
require("paperRow" in view and "PDF" in view, "library paper rows do not match browser preview")
require("iconInfoRow" in view and "iconSwitchRow" in view and "makeBadge" in view, "profile icon rows do not match browser preview")
require("renderSlideToNext" in view and "UIView.transition" in view, "next transition not wired")
require("transitionCrossDissolve" in view and "duration: 0.16" in view, "next transition is still too heavy")
require("render(animated: false)" in view and "setPage(" in view, "tap navigation still uses heavy page transition")
require("setPage(.library, animated: false)" in view and "setPage(.practice, animated: false)" in view, "direct tap navigation still jumps too much")
require("withTimeInterval: 0.24" in view, "auto-next confirmation pause is not tuned")
require("translation.x * 0.03" in view, "drag feedback is still too strong")
require("makeTabButton" in view and "imagePlacement = .top" in view and "imagePadding = 4" in view, "wechat-like bottom tab spacing missing")
require("if autoNextEnabled" in view and "submitAnswer()" in view, "auto-next does not submit on option tap")
require("if !autoNextEnabled || question.answer.count > 1" in view, "multi-select questions do not keep the submit button")
require("question.answer.count > 1" in view and "selectedAnswers.remove(key)" in view and "selectedAnswers.insert(key)" in view, "multi-select taps still auto-submit or cannot toggle")
require("case questionJump" in view and "renderQuestionJumpPanel" in view and "makeQuestionNumberGrid" in view, "quick question jump panel is missing")
require("isQuestionAnswered" in view and "jumpButtonTapped" in view and "restoreSelectedAnswersForCurrentQuestion" in view, "jump panel does not show answered state or restore answers")
require("jumpSearchField" in view and "jumpSearchChanged" in view and "filteredJumpItems" in view, "jump page is not searchable/scroll-friendly")
require("revealAnswer" in view and "isCorrectOption" in view and "isWrongSelectedOption" in view, "wrong answer state does not reveal correct option")
require("addAnswerComparison" in view, "open/fill questions do not show answer comparison")
require("answeredSelections" in view and "textAnswers" in view, "answered choices/text are not persisted")
require("addFreeTextAnswer" in view and "currentTextAnswerView" in view, "short-answer questions do not render a text box")
require("addBlankInputs" in view and "blankAnswerFields" in view and "countBlankPlaceholders" in view, "fill-in questions do not render ordered blanks")
require("isTextResponseQuestion" in view and "isFillBlankQuestion" in view, "open/fill question type detection missing")
require("openRandomPractice" in view and "random: true" in view, "home random practice shortcut is missing")
require("case paperDetail" in view and "renderPaperDetail" in view, "paper detail page is missing")
require("showSequentialPractice" in view and "showRandomPractice" in view and "showWrongPracticeEntry" in view and "showEditEntry" in view, "practice entry switches are missing")
require("startSequentialFromDetail" in view and "startRandomFromDetail" in view and "openEditorFromDetail" in view, "paper detail actions are not wired")
require('"\\u{8fd8}\\u{6ca1}\\u{6709}\\u{9898}\\u{5e93}"' in view and "papers.isEmpty" in view, "empty library/home state is missing")
require("guard papers.indices.contains(index) else { return }" in view and "papers.count > 1" not in view, "paper deletion still forbids deleting all papers")
home_body = view.split("private func renderHome()", 1)[1].split("private func renderLibrary()", 1)[0]
require("openCurrentPaper" not in home_body and "openRandomPractice" not in home_body, "home still exposes direct practice shortcuts")
detail_body = view.split("private func renderPaperDetail()", 1)[1].split("private func renderImport()", 1)[0]
require("showSequentialPractice" in detail_body and "showRandomPractice" in detail_body and "showWrongPracticeEntry" in detail_body and "showEditEntry" in detail_body, "paper detail does not respect practice entry switches")
require("letterLabel" in view and "UIColor.tertiarySystemFill" in view, "selected option does not use iOS settings-like highlight")
require("setContentCompressionResistancePriority(.defaultLow, for: .horizontal)" in view, "right-side row controls can drift left")
require("QuestionParser.parse" in view, "import does not use parser")
require("struct Paper" in view, "paper library model missing")
require("case library" in view, "library tab missing")
require("UIDocumentPickerViewController" in view, "file import picker missing")
require("import PDFKit" in view, "PDFKit import missing")
require("import UniformTypeIdentifiers" in view, "UTType import missing")
require("import PhotosUI" in view and "PHPickerViewController" in view, "image import picker missing")
require("import Vision" in view and "VNRecognizeTextRequest" in view and "recognitionLanguages" in view, "local image OCR is missing")
require("makeSwipeDeletePaperRow" in view and "paperForegroundView" in view and "paperDeleteButtonTapped" in view, "wechat-style swipe-to-delete row is missing")
require("revealPaperDelete" in view and "CGAffineTransform(translationX: -82" in view, "paper row does not slide open to reveal delete")
require("UILongPressGestureRecognizer" in view and "openPaperSwitchSheet" in view and "switchActivePaper" in view, "home long-press paper switching is missing")
require("case questionList" in view and "case questionEdit" in view, "question editing pages are missing")
require("renderQuestionList" in view and "renderQuestionEditor" in view and "saveQuestionEdit" in view, "question editing UI is missing")
require("editSearchField" in view and "editSearchChanged" in view and "filteredEditableQuestions" in view, "question editing list is not searchable/scroll-friendly")
require("parseEditedOptions" in view, "edited option parser is missing")
require("aiValidatePaperTapped" in view and "requestAIValidatePaper" in view and "previewAIValidation" in view, "AI answer validation/review flow is missing")
require('mode: "validate"' in view and "validation" in view, "AI validation request does not identify validation mode")
require((ROOT / "ios/QuizTool/QuizTool/Assets.xcassets/AppIcon.appiconset/Icon-60-60@3x.png").exists(), "missing 180px app icon")
require((ROOT / "ios/QuizTool/QuizTool/Assets.xcassets/AppIcon.appiconset/Icon-1024.png").exists(), "missing 1024px app icon")

print("native ios checks passed")
