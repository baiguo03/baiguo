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

## Local AI Backend

During development, the Windows PC can act as the AI parse/validation backend:

```powershell
cd backend
$env:LIZI_AI_KEY="your-new-key"
.\run_local_backend.ps1
```

On the iPhone, set the app API URL to the PC LAN address, for example:

```text
http://172.20.10.3:8787/api/parse-questions
```

To prepare a server upload package:

```powershell
.\backend\package_backend.ps1
```

The package is written to `outputs/lizi-backend.zip`.
