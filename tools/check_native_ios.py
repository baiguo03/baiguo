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
require("UIRectEdge.left" in view and "UIRectEdge.right" in view, "side swipe gestures missing")
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
