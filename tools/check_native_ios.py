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

require("PRODUCT_NAME = QuizNativeV10;" in project, "missing QuizNativeV10 product")
require("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;" in project, "missing AppIcon setting")
require("QuestionParser.swift in Sources" in project, "parser is not in sources")
require("insertBreaksBeforeInlineQuestionStarts" in parser, "parser does not split inline question starts")
require("stripAnswerSummary" in parser, "parser does not remove answer summary blocks")
require("QuizNativeV10.ipa" in yaml, "Codemagic artifact is not V10")
require("&#x4e91;&#x9898;V10" in plist, "display name is not Yunti V10")
require("autoNextEnabled" in view and "UISwitch" in view, "auto-next switch not wired")
require("shuffleOptionsEnabled" in view and "optionOrders" in view, "option shuffle setting/order cache missing")
require("UIPanGestureRecognizer" in view and "translation.x > 36" in view and "velocity.x > 420" in view, "sensitive horizontal swipe gestures missing")
require("appBackgroundColor" in view and "softGreenColor" in view, "V10 palette is not in native UI")
require("UIFont.systemFont(ofSize: 24" in view, "native title size is still too heavy")
require("tabStack.heightAnchor.constraint(equalToConstant: 82)" in view, "native tab bar height is still too heavy")
require("UIImage(systemName:" in view, "native bottom tabs still use text glyphs")
require("addTopBar" in view and "makeChip" in view, "browser-style top bar/chip is missing")
require("button.layer.cornerRadius = 17" in view, "native option rows do not match V10 preview")
require("stack.layer.cornerRadius = 18" in view, "native cards/lists are still too bulky")
require("addSearchField" in view and "\\u{641c}\\u{7d22}\\u{8bd5}\\u{5377}" in view, "library search field is missing")
require("paperRow" in view and "PDF" in view, "library paper rows do not match browser preview")
require("iconInfoRow" in view and "iconSwitchRow" in view and "makeBadge" in view, "profile icon rows do not match browser preview")
require("renderSlideToNext" in view and "UIView.animate" in view, "next transition not wired")
require("withDuration: 0.28" in view and "delay: 0.1" in view, "next transition is not calm enough")
require("withTimeInterval: 0.38" in view or "withTimeInterval: 0.4" in view, "auto-next confirmation pause missing")
require("makeTabButton" in view and "centeredParagraphStyle" in view, "wechat-like bottom tab missing")
require("if autoNextEnabled" in view and "submitAnswer()" in view, "auto-next does not submit on option tap")
require("if !autoNextEnabled" in view, "submit button still shows in auto-next mode")
require("\\u{2713}" in view and "UIColor.tertiarySystemFill" in view, "selected option does not use iOS settings-like highlight")
require("QuestionParser.parse" in view, "import does not use parser")
require("struct Paper" in view, "paper library model missing")
require("case library" in view, "library tab missing")
require("UIDocumentPickerViewController" in view, "file import picker missing")
require("import PDFKit" in view, "PDFKit import missing")
require("import UniformTypeIdentifiers" in view, "UTType import missing")
require((ROOT / "ios/QuizTool/QuizTool/Assets.xcassets/AppIcon.appiconset/Icon-60-60@3x.png").exists(), "missing 180px app icon")
require((ROOT / "ios/QuizTool/QuizTool/Assets.xcassets/AppIcon.appiconset/Icon-1024.png").exists(), "missing 1024px app icon")

print("native ios checks passed")
