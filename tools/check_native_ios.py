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

for old in ["刷题工具", "QuizNativeV8", "QuizNativeV7", "QuizNativeV6", "QuizNativeV5", "QuizNativeV4", "QuizNativeV3", "QuizNativeV2"]:
    require(old not in view + parser + project + plist + yaml, f"old marker remains: {old}")

require("PRODUCT_NAME = QuizNativeV9;" in project, "missing QuizNativeV9 product")
require("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;" in project, "missing AppIcon setting")
require("QuestionParser.swift in Sources" in project, "parser is not in sources")
require("QuizNativeV9.ipa" in yaml, "Codemagic artifact is not V9")
require("&#x4e91;&#x9898;V9" in plist, "display name is not 云题V9")
require("autoNextEnabled" in view and "UISwitch" in view, "auto-next switch not wired")
require("renderSlideToNext" in view and "UIView.animate" in view, "slide transition not wired")
require("translationX: 0, y: 4" in view and "withDuration: 0.18" in view, "next transition is still too large")
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
