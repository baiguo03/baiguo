# 云题 V7 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert 云题 into a WeChat-like iOS layout where the bottom tabs are 首页 / 题库 / 错题 / 我的, imported papers are managed as separate libraries, and practice starts only after opening a paper.

**Architecture:** Keep the native UIKit app and the existing parser. Add a small in-memory `Paper` model in `ViewController.swift` for this iteration. Use grouped list rows, white cards, subtle dividers, and a green accent to match a WeChat-like iOS style without adding external dependencies.

**Tech Stack:** Swift 5, UIKit, UniformTypeIdentifiers, PDFKit, Codemagic iOS IPA workflow.

---

### Task 1: V7 Static Expectations

**Files:**
- Modify: `tools/check_native_ios.py`

- [ ] **Step 1: Change checks to V7**

Require `QuizNativeV7`, `QuizNativeV7.ipa`, `Paper`, `library`, `UIDocumentPickerViewController`, `PDFKit`, and no old V6 markers.

- [ ] **Step 2: Run check to verify it fails**

Run: `python tools/check_native_ios.py`
Expected: fail because implementation is still V6.

### Task 2: Version and File Import Plumbing

**Files:**
- Modify: `ios/QuizTool/QuizTool/Info.plist`
- Modify: `ios/QuizTool/QuizTool.xcodeproj/project.pbxproj`
- Modify: `codemagic.yaml`
- Modify: `ios/QuizTool/QuizTool/ViewController.swift`

- [ ] **Step 1: Upgrade version markers**

Set display name to 云题V7, build to 8, product/artifact to `QuizNativeV7.ipa`.

- [ ] **Step 2: Add document picker**

Use `UIDocumentPickerViewController` for `.txt` and `.pdf`, parse TXT as UTF-8 text, parse PDF with `PDFDocument`.

### Task 3: Library-First UI

**Files:**
- Modify: `ios/QuizTool/QuizTool/ViewController.swift`

- [ ] **Step 1: Replace bottom tabs**

Use tabs 首页 / 题库 / 错题 / 我的. Remove bottom 练习 tab.

- [ ] **Step 2: Add paper library**

Store imported papers separately. The 题库 tab lists each paper. Tapping a paper opens practice from the first question.

- [ ] **Step 3: WeChat-like visual pass**

Use white grouped cards, grey app background, green accent, row separators, and right-arrow rows.

### Task 4: Verification and Push

**Files:**
- All changed files

- [ ] **Step 1: Run local static checks**

Run `tools/check_native_ios.py` and text searches for old markers.

- [ ] **Step 2: Commit and push**

Commit message: `redesign yunti v7 library flow`

