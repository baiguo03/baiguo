from pathlib import Path


required = [
    "app/index.html",
    "app/styles.css",
    "app/src/app.js",
    "app/src/parser.js",
    "app/src/quiz-engine.js",
    "app/src/storage.js",
    "app/src/api-config.js",
    "tools/extract_pdf_text.py",
    "codemagic.yaml",
    "ios/QuizTool/QuizTool.xcodeproj/project.pbxproj",
    "ios/QuizTool/QuizTool/ViewController.swift",
    "docs/signing.md",
]

missing = [path for path in required if not Path(path).exists()]
if missing:
    raise SystemExit("Missing files: " + ", ".join(missing))

print("app file check passed")
