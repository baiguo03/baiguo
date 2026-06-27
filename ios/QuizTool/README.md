# QuizTool iOS Shell

This folder contains the intended WKWebView iOS shell for the static web app in `app/`.

## Build Notes

- Minimum iOS target: 16.0.
- Main screen: `ViewController.swift` loads bundled `app/index.html`.
- The web app assets must be copied into the iOS app bundle as an `app` folder.
- Codemagic signing requires Apple signing assets or an adjusted TrollStore-friendly signing workflow.
- This Windows workspace cannot compile Xcode projects locally. Use Codemagic or another macOS/Xcode cloud builder.

## Required Xcode Project Shape

The repository includes a minimal `QuizTool.xcodeproj`. If Xcode rejects the generated project, create a fresh Xcode iOS App project named `QuizTool`, then add:

- `QuizTool/AppDelegate.swift`
- `QuizTool/SceneDelegate.swift`
- `QuizTool/ViewController.swift`
- `QuizTool/Info.plist`
- Bundled resource folder: `app/`

The `codemagic.yaml` workflow expects `ios/QuizTool/QuizTool.xcodeproj` and scheme `QuizTool`.
