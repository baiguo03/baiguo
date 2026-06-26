# iOS Quiz Tool

An iOS 16-compatible quiz tool MVP designed for a WKWebView IPA shell.

## Run locally

Open `app/index.html` in a browser, or serve the folder with any static server.

## Test

Use the bundled Codex Node runtime or any Node 18+:

```powershell
& "C:\Users\liu\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe" app/tests/parser.test.mjs
& "C:\Users\liu\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe" app/tests/quiz-engine.test.mjs
```

## PDF Sample

The current test sample is `C:/Users/liu/Desktop/复习题_20260618093745.pdf`.

## IPA Build

The web app is intended to be embedded into the `ios/QuizTool` WKWebView shell and built on Codemagic or GitHub Actions macOS runners.
