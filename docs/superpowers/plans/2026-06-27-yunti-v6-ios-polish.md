# 云题 V6 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a more iOS-like 云题 V6 with polished native UIKit screens, a settings switch for auto-next behavior, useful paste-based question import, and clearer wrong-question review.

**Architecture:** Keep the shipping app native UIKit for iOS 16 compatibility. Extract question text parsing into a small pure Swift type so behavior can be verified without UI. Keep UI in the existing `ViewController.swift` for this iteration, but structure it with helpers for list rows, cards, chips, and feedback banners.

**Tech Stack:** Swift 5, UIKit, XCTest, Codemagic iOS IPA workflow.

---

### Task 1: Parser Test

**Files:**
- Create: `ios/QuizTool/QuizToolTests/QuestionParserTests.swift`
- Modify: `ios/QuizTool/QuizTool.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add XCTest target with parser tests**

Create tests proving that pasted text with `答案：A` and `解析：...` creates real questions.

- [ ] **Step 2: Run the test on Codemagic-compatible xcodebuild**

Expected before implementation: compile or test failure because `QuestionParser` does not exist.

### Task 2: Parser Implementation

**Files:**
- Create: `ios/QuizTool/QuizTool/QuestionParser.swift`
- Modify: `ios/QuizTool/QuizTool/ViewController.swift`

- [ ] **Step 1: Add `QuestionParser`**

Implement parsing for common pasted formats:
- `1.题干 A.选项A B.选项B C.选项C D.选项D 答案：A 解析：...`
- one or more questions separated by numbered starts.

- [ ] **Step 2: Wire import page**

Import should replace the question bank with parsed questions and show a concise result banner.

### Task 3: V6 Native UI Polish

**Files:**
- Modify: `ios/QuizTool/QuizTool/ViewController.swift`
- Modify: `ios/QuizTool/QuizTool/Info.plist`
- Modify: `ios/QuizTool/QuizTool.xcodeproj/project.pbxproj`
- Modify: `codemagic.yaml`

- [ ] **Step 1: Upgrade version markers**

Change display name to `云题V6`, build to `7`, product name/artifact to `QuizNativeV6.ipa`.

- [ ] **Step 2: Redesign main screens**

Use iOS grouped background, rounded grouped cards, compact stat cards, segmented-like practice buttons, and clearer tab selection.

- [ ] **Step 3: Add auto-next switch**

Settings includes `答对后自动下一题`. When on, correct answers jump to the next question without alert. When off, show result feedback and wait.

### Task 4: Verification and Push

**Files:**
- All changed files

- [ ] **Step 1: Run local static checks**

Check that old names do not remain, Swift identifiers are not corrupted by Unicode escapes, icon and Codemagic paths are valid.

- [ ] **Step 2: Commit and push**

Commit message: `polish native ios quiz v6`

