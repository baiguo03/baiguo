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
    "QuizNativeV10",
    "QuizNativeV9",
    "QuizNativeV8",
    "QuizNativeV7",
    "QuizNativeV6",
    "QuizNativeV5",
    "QuizNativeV4",
    "QuizNativeV3",
    "QuizNativeV2",
]:
    require(old not in view + parser + project + plist + yaml, f"old marker remains: {old}")

require("PRODUCT_NAME = QuizNativeV11;" in project, "missing QuizNativeV11 product")
require("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;" in project, "missing AppIcon setting")
require("QuestionParser.swift in Sources" in project, "parser is not in sources")
require("insertBreaksBeforeInlineQuestionStarts" in parser, "parser does not split inline question starts")
require("stripAnswerSummary" in parser, "parser does not remove answer summary blocks")
require("extractAnswerSummaryAnswers" in parser, "parser does not read answer summary mappings")
require("summaryAnswers[index + 1]" in parser, "parser does not apply per-question summary answers")
require("normalizeAnswerKeys" in parser, "parser does not normalize summary answers")
require("inferOpenQuestionKind" in parser and "\\u{586b}\\u{7a7a}\\u{9898}" in parser, "fill-in questions are not supported")
require("\\u{7b80}\\u{7b54}\\u{9898}" in parser and "\\u{914d}\\u{4f0d}\\u{9898}" in parser, "short answer/matching questions are not supported")
require("QuizNativeV11.ipa" in yaml, "Codemagic artifact is not V11")
require("&#x4e91;&#x9898;V11" in plist, "display name is not Yunti V11")
require("UIUserInterfaceStyle" in plist and "<string>Light</string>" in plist, "app does not force light appearance")
require("overrideUserInterfaceStyle = .light" in view, "view controller does not force light appearance")
require("autoNextEnabled" in view and "UISwitch" in view, "auto-next switch not wired")
require("shuffleOptionsEnabled" in view and "optionOrders" in view, "option shuffle setting/order cache missing")
require("Codable" in view and "AppState" in view, "app state persistence model is missing")
require("loadPersistedState" in view and "savePersistedState" in view, "app state persistence is not wired")
require("UserDefaults.standard.data(forKey: storageKey)" in view, "persisted app state is not loaded")
require("UserDefaults.standard.set(data, forKey: storageKey)" in view, "persisted app state is not saved")
require("case search" in view and "renderSearch" in view and "openSearchPage" in view, "search entry is not wired")
require("case apiConfig" in view and "renderAPIConfig" in view and "openAPIConfig" in view, "api config entry is not wired")
require("case practiceMode" in view and "renderPracticeMode" in view and "openPracticeMode" in view, "practice mode entry is not wired")
require("startWrongPractice" in view and "focusedPracticeQuestions" in view, "wrong question practice is missing")
require('"wrong"' in view and "cachePrefix" in view, "wrong practice option cache is not isolated")
require("wrongQuestions.contains" in view, "wrong questions can be duplicated")
require("UIPanGestureRecognizer" in view and "translation.x > 36" in view and "velocity.x > 420" in view, "sensitive horizontal swipe gestures missing")
require("appBackgroundColor" in view and "softGreenColor" in view, "V11 palette is not in native UI")
require("UIFont.systemFont(ofSize: 24" in view, "native title size is still too heavy")
require("tabStack.heightAnchor.constraint(equalToConstant: 94)" in view, "native tab bar height is not balanced")
require("UIEdgeInsets(top: 12, left: 10, bottom: 20, right: 10)" in view, "native tab bar vertical padding is too tight")
require("UIImage(systemName:" in view, "native bottom tabs still use text glyphs")
require("addTopBar" in view and "makeChip" in view, "browser-style top bar/chip is missing")
require("button.layer.cornerRadius = 17" in view, "native option rows do not match V11 preview")
require("stack.layer.cornerRadius = 18" in view, "native cards/lists are still too bulky")
require("addSearchField" in view and "\\u{641c}\\u{7d22}\\u{8bd5}\\u{5377}" in view, "library search field is missing")
require("paperRow" in view and "PDF" in view, "library paper rows do not match browser preview")
require("iconInfoRow" in view and "iconSwitchRow" in view and "makeBadge" in view, "profile icon rows do not match browser preview")
require("renderSlideToNext" in view and "UIView.transition" in view, "next transition not wired")
require("transitionCrossDissolve" in view and "duration: 0.16" in view, "next transition is still too heavy")
require("render(animated: false)" in view and "setPage(" in view, "tap navigation still uses heavy page transition")
require("setPage(.library, animated: false)" in view and "setPage(.practice, animated: false)" in view, "direct tap navigation still jumps too much")
require("withTimeInterval: 0.24" in view, "auto-next confirmation pause is not tuned")
require("translation.x * 0.03" in view, "drag feedback is still too strong")
require("makeTabButton" in view and "imagePlacement = .top" in view and "imagePadding = 6" in view, "wechat-like bottom tab spacing missing")
require("if autoNextEnabled" in view and "submitAnswer()" in view, "auto-next does not submit on option tap")
require("if !autoNextEnabled" in view, "submit button still shows in auto-next mode")
require("openRandomPractice" in view and "random: true" in view, "home random practice shortcut is missing")
require("letterLabel" in view and "UIColor.tertiarySystemFill" in view, "selected option does not use iOS settings-like highlight")
require("setContentCompressionResistancePriority(.defaultLow, for: .horizontal)" in view, "right-side row controls can drift left")
require("QuestionParser.parse" in view, "import does not use parser")
require("struct Paper" in view, "paper library model missing")
require("case library" in view, "library tab missing")
require("UIDocumentPickerViewController" in view, "file import picker missing")
require("import PDFKit" in view, "PDFKit import missing")
require("import UniformTypeIdentifiers" in view, "UTType import missing")
require((ROOT / "ios/QuizTool/QuizTool/Assets.xcassets/AppIcon.appiconset/Icon-60-60@3x.png").exists(), "missing 180px app icon")
require((ROOT / "ios/QuizTool/QuizTool/Assets.xcassets/AppIcon.appiconset/Icon-1024.png").exists(), "missing 1024px app icon")

print("native ios checks passed")
