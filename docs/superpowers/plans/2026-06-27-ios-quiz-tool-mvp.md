# iOS Quiz Tool MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a runnable iOS-style quiz tool MVP that imports text/PDF-extracted questions, allows review, publishes papers, supports practice/review, saves data locally, exposes AI/API settings, and includes cloud IPA build scaffolding.

**Architecture:** Use a dependency-light static web app first so it runs in desktop browsers and inside an iOS WKWebView shell. Keep parsing, storage, quiz logic, and UI rendering in separate JavaScript modules. Add a minimal iOS container and Codemagic configuration after the web MVP is verifiable.

**Tech Stack:** HTML, CSS, vanilla JavaScript ES modules, IndexedDB/localStorage fallback, Python verification scripts, WKWebView Swift container scaffold, Codemagic YAML.

---

## File Structure

- `app/index.html`: Main app shell.
- `app/styles.css`: iOS-style responsive UI.
- `app/src/models.js`: Shared type constants and validation helpers.
- `app/src/sample-data.js`: Demo questions and paper seed data.
- `app/src/storage.js`: IndexedDB wrapper with localStorage fallback.
- `app/src/parser.js`: Local text parser for PDF/Word extracted text.
- `app/src/quiz-engine.js`: Answer checking, attempts, wrong-question logic.
- `app/src/api-config.js`: API settings persistence and connection test helper.
- `app/src/app.js`: UI state, event wiring, rendering.
- `app/tests/parser.test.mjs`: Parser unit tests.
- `app/tests/quiz-engine.test.mjs`: Quiz logic tests.
- `tools/extract_pdf_text.py`: Extract text from the user PDF sample for local testing.
- `tools/check_app_files.py`: Static sanity checks for key app files.
- `ios/QuizTool/`: Minimal iOS WKWebView project scaffold.
- `codemagic.yaml`: Cloud build workflow skeleton.
- `README.md`: Run, test, and build instructions.
- `.gitignore`: Ignore generated files and brainstorm artifacts.

## Task 1: Initialize Project Files

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: `app/index.html`
- Create: `app/src/models.js`
- Create: `app/src/sample-data.js`

- [ ] **Step 1: Create `.gitignore`**

```gitignore
.superpowers/
work/*.txt
work/*.json
node_modules/
dist/
build/
DerivedData/
*.xcarchive
*.ipa
.DS_Store
```

- [ ] **Step 2: Create `README.md`**

```markdown
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

## PDF sample

The current test sample is `C:/Users/liu/Desktop/复习题_20260618093745.pdf`.

## IPA build

The web app is intended to be embedded into the `ios/QuizTool` WKWebView shell and built on Codemagic or GitHub Actions macOS runners.
```

- [ ] **Step 3: Create `app/index.html`**

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="default">
  <title>刷题工具</title>
  <link rel="stylesheet" href="./styles.css">
</head>
<body>
  <div id="app"></div>
  <script type="module" src="./src/app.js"></script>
</body>
</html>
```

- [ ] **Step 4: Create `app/src/models.js`**

```js
export const QUESTION_TYPES = {
  single: "单选题",
  multiple: "多选题",
  judge: "判断题",
  blank: "填空题",
  short: "简答题",
};

export const QUESTION_TYPE_KEYS = Object.keys(QUESTION_TYPES);

export function createId(prefix = "id") {
  return `${prefix}_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

export function normalizeAnswer(answer) {
  if (Array.isArray(answer)) {
    return answer.map((item) => String(item).trim().toUpperCase()).filter(Boolean).sort();
  }
  return String(answer ?? "").trim();
}

export function validateQuestion(question) {
  const errors = [];
  if (!question.prompt || !question.prompt.trim()) errors.push("题干不能为空");
  if (!QUESTION_TYPE_KEYS.includes(question.type)) errors.push("题型无效");
  if (["single", "multiple"].includes(question.type) && (!question.options || question.options.length < 2)) {
    errors.push("选择题至少需要两个选项");
  }
  if (question.type !== "short" && (question.answer === undefined || question.answer === null || question.answer === "")) {
    errors.push("答案不能为空");
  }
  return errors;
}
```

- [ ] **Step 5: Create `app/src/sample-data.js`**

```js
import { createId } from "./models.js";

export const sampleQuestions = [
  {
    id: createId("q"),
    type: "single",
    prompt: "温抗体型的自身免疫溶血性贫血的抗体类型一般为（）",
    options: [
      { key: "A", text: "IgA" },
      { key: "B", text: "IgM" },
      { key: "C", text: "IgD" },
      { key: "D", text: "IgG" },
    ],
    answer: "D",
    explanation: "",
    tags: ["样本", "血液学"],
    reviewed: true,
  },
  {
    id: createId("q"),
    type: "judge",
    prompt: "AI 解析后的题目可以跳过人工校对直接发布。",
    options: [
      { key: "A", text: "正确" },
      { key: "B", text: "错误" },
    ],
    answer: "B",
    explanation: "AI 输出需要经过校验和人工校对。",
    tags: ["系统"],
    reviewed: true,
  },
];
```

- [ ] **Step 6: Verify files exist**

Run: `Get-ChildItem -Recurse app, README.md, .gitignore`

Expected: The created files are listed.

## Task 2: Parser Module

**Files:**
- Create: `app/src/parser.js`
- Create: `app/tests/parser.test.mjs`

- [ ] **Step 1: Write failing parser tests**

```js
import assert from "node:assert/strict";
import { parseQuestionText } from "../src/parser.js";

const sample = `一、单项选择题（共 50 题，每题 2 分）
1.温抗体型的自身免疫溶血性贫血的抗体类型一般为（） A. IgA B. IgM
C. IgD D. IgG
2.凝血因子 Ⅶ 主要参与哪条凝血途径（） A. 内源性凝血途径 B. 外源性凝血途径 C. 共同凝血途径 D. 纤溶途径`;

const result = parseQuestionText(sample);
assert.equal(result.questions.length, 2);
assert.equal(result.questions[0].type, "single");
assert.equal(result.questions[0].options.length, 4);
assert.equal(result.questions[0].options[3].text, "IgG");
assert.equal(result.questions[1].prompt.includes("凝血因子"), true);
console.log("parser tests passed");
```

- [ ] **Step 2: Run parser test to verify it fails**

Run: `node app/tests/parser.test.mjs`

Expected: FAIL because `app/src/parser.js` does not exist.

- [ ] **Step 3: Implement `app/src/parser.js`**

```js
import { createId, validateQuestion } from "./models.js";

const TYPE_RULES = [
  { pattern: /单项选择|单选/i, type: "single" },
  { pattern: /多项选择|多选/i, type: "multiple" },
  { pattern: /判断/i, type: "judge" },
  { pattern: /填空/i, type: "blank" },
  { pattern: /简答|问答/i, type: "short" },
];

export function normalizeText(text) {
  return String(text ?? "")
    .replace(/\r/g, "\n")
    .replace(/[ \t]+/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

export function detectTypeFromHeading(line, fallback = "single") {
  const rule = TYPE_RULES.find((item) => item.pattern.test(line));
  return rule ? rule.type : fallback;
}

export function splitQuestionBlocks(text) {
  const normalized = normalizeText(text);
  const matches = [...normalized.matchAll(/(?:^|\n)\s*(\d{1,4})[\.．、]\s*/g)];
  if (!matches.length) return [];
  return matches.map((match, index) => {
    const start = match.index + match[0].length;
    const end = index + 1 < matches.length ? matches[index + 1].index : normalized.length;
    return {
      number: Number(match[1]),
      raw: normalized.slice(start, end).trim(),
    };
  }).filter((block) => block.raw);
}

export function parseOptions(raw) {
  const optionMatches = [...raw.matchAll(/(?:^|\s)([A-H])[\.\．、]\s*/g)];
  if (!optionMatches.length) return { prompt: raw.trim(), options: [] };

  const prompt = raw.slice(0, optionMatches[0].index).trim();
  const options = optionMatches.map((match, index) => {
    const key = match[1].toUpperCase();
    const start = match.index + match[0].length;
    const end = index + 1 < optionMatches.length ? optionMatches[index + 1].index : raw.length;
    return { key, text: raw.slice(start, end).trim() };
  }).filter((option) => option.text);

  return { prompt, options };
}

export function parseQuestionText(text) {
  const lines = normalizeText(text).split("\n");
  let currentType = "single";
  for (const line of lines.slice(0, 8)) {
    currentType = detectTypeFromHeading(line, currentType);
  }

  const blocks = splitQuestionBlocks(text);
  const questions = blocks.map((block) => {
    const parsed = parseOptions(block.raw);
    const inferredType = parsed.options.length >= 2 ? currentType : "short";
    const question = {
      id: createId("q"),
      sourceNumber: block.number,
      type: inferredType,
      prompt: parsed.prompt || block.raw,
      options: parsed.options,
      answer: "",
      explanation: "",
      tags: [],
      reviewed: false,
      raw: block.raw,
      warnings: [],
    };
    question.warnings = validateQuestion(question);
    if (!question.answer) question.warnings.push("答案待补充");
    return question;
  });

  return {
    questions,
    warnings: questions.flatMap((question) => question.warnings.map((warning) => `第 ${question.sourceNumber || "?"} 题：${warning}`)),
  };
}
```

- [ ] **Step 4: Run parser test**

Run: `node app/tests/parser.test.mjs`

Expected: PASS with `parser tests passed`.

## Task 3: Quiz Engine

**Files:**
- Create: `app/src/quiz-engine.js`
- Create: `app/tests/quiz-engine.test.mjs`

- [ ] **Step 1: Write failing quiz engine tests**

```js
import assert from "node:assert/strict";
import { checkAnswer, createAnswerRecord } from "../src/quiz-engine.js";

assert.equal(checkAnswer({ type: "single", answer: "A" }, "A"), true);
assert.equal(checkAnswer({ type: "multiple", answer: ["A", "C"] }, ["C", "A"]), true);
assert.equal(checkAnswer({ type: "blank", answer: ["红细胞", "RBC"] }, "rbc"), true);
assert.equal(checkAnswer({ type: "short", answer: "参考答案" }, "用户答案"), null);

const record = createAnswerRecord({ id: "q1", type: "single", answer: "B" }, "A", 12);
assert.equal(record.questionId, "q1");
assert.equal(record.correct, false);
console.log("quiz-engine tests passed");
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node app/tests/quiz-engine.test.mjs`

Expected: FAIL because `app/src/quiz-engine.js` does not exist.

- [ ] **Step 3: Implement `app/src/quiz-engine.js`**

```js
import { createId, normalizeAnswer } from "./models.js";

export function checkAnswer(question, userAnswer) {
  if (question.type === "short") return null;
  if (question.type === "multiple") {
    return JSON.stringify(normalizeAnswer(question.answer)) === JSON.stringify(normalizeAnswer(userAnswer));
  }
  if (question.type === "blank") {
    const accepted = Array.isArray(question.answer) ? question.answer : [question.answer];
    const normalizedUser = String(userAnswer ?? "").trim().toLowerCase();
    return accepted.some((item) => String(item).trim().toLowerCase() === normalizedUser);
  }
  return String(question.answer ?? "").trim().toUpperCase() === String(userAnswer ?? "").trim().toUpperCase();
}

export function createAnswerRecord(question, userAnswer, elapsedSeconds = 0) {
  const correct = checkAnswer(question, userAnswer);
  return {
    id: createId("answer"),
    questionId: question.id,
    userAnswer,
    correct,
    elapsedSeconds,
    answeredAt: new Date().toISOString(),
  };
}
```

- [ ] **Step 4: Run quiz engine test**

Run: `node app/tests/quiz-engine.test.mjs`

Expected: PASS with `quiz-engine tests passed`.

## Task 4: Storage and API Config

**Files:**
- Create: `app/src/storage.js`
- Create: `app/src/api-config.js`

- [ ] **Step 1: Implement `app/src/storage.js`**

```js
const DB_NAME = "ios_quiz_tool";
const DB_VERSION = 1;
const STORES = ["questions", "papers", "attempts", "reviewItems", "settings"];

function openDb() {
  return new Promise((resolve, reject) => {
    if (!("indexedDB" in window)) {
      reject(new Error("IndexedDB unavailable"));
      return;
    }
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      for (const store of STORES) {
        if (!db.objectStoreNames.contains(store)) db.createObjectStore(store, { keyPath: "id" });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function withStore(storeName, mode, callback) {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, mode);
    const store = tx.objectStore(storeName);
    const result = callback(store);
    tx.oncomplete = () => resolve(result);
    tx.onerror = () => reject(tx.error);
  });
}

export async function saveItem(storeName, item) {
  try {
    await withStore(storeName, "readwrite", (store) => store.put(item));
  } catch {
    const list = JSON.parse(localStorage.getItem(storeName) || "[]").filter((entry) => entry.id !== item.id);
    list.push(item);
    localStorage.setItem(storeName, JSON.stringify(list));
  }
}

export async function getAllItems(storeName) {
  try {
    const db = await openDb();
    return await new Promise((resolve, reject) => {
      const tx = db.transaction(storeName, "readonly");
      const req = tx.objectStore(storeName).getAll();
      req.onsuccess = () => resolve(req.result || []);
      req.onerror = () => reject(req.error);
    });
  } catch {
    return JSON.parse(localStorage.getItem(storeName) || "[]");
  }
}

export async function clearStore(storeName) {
  try {
    await withStore(storeName, "readwrite", (store) => store.clear());
  } catch {
    localStorage.removeItem(storeName);
  }
}
```

- [ ] **Step 2: Implement `app/src/api-config.js`**

```js
const CONFIG_KEY = "quiz_api_config";

export function loadApiConfig() {
  return JSON.parse(localStorage.getItem(CONFIG_KEY) || JSON.stringify({
    endpoint: "",
    apiKey: "",
    model: "gpt-4.1-mini",
    strategy: "hybrid",
    sendOnlyFlagged: true,
  }));
}

export function saveApiConfig(config) {
  localStorage.setItem(CONFIG_KEY, JSON.stringify({
    endpoint: String(config.endpoint || "").trim(),
    apiKey: String(config.apiKey || "").trim(),
    model: String(config.model || "gpt-4.1-mini").trim(),
    strategy: config.strategy || "hybrid",
    sendOnlyFlagged: config.sendOnlyFlagged !== false,
  }));
}

export async function testApiConnection(config) {
  if (!config.endpoint) return { ok: false, message: "请填写 API 地址" };
  if (!config.apiKey) return { ok: false, message: "请填写 API Key" };
  try {
    const response = await fetch(config.endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${config.apiKey}`,
      },
      body: JSON.stringify({ model: config.model, input: "ping" }),
    });
    return { ok: response.ok, message: response.ok ? "连接成功" : `连接失败：${response.status}` };
  } catch (error) {
    return { ok: false, message: `连接失败：${error.message}` };
  }
}
```

- [ ] **Step 3: Run static syntax check**

Run: `node --check app/src/storage.js` and `node --check app/src/api-config.js`

Expected: Both commands complete without syntax errors.

## Task 5: iOS-Style UI

**Files:**
- Create: `app/styles.css`
- Create: `app/src/app.js`

- [ ] **Step 1: Create `app/styles.css`**

Use the iOS visual direction from the approved mockups: system font stack, `#f2f2f7` app background, grouped lists, system-blue actions, bottom tabs, stable button sizes, no gradient-orb decoration.

- [ ] **Step 2: Create `app/src/app.js`**

Implement views:

- `library`: progress card, import button, paper list, wrong question entry.
- `import`: text area/file input, parser run button, parsed warnings.
- `review`: parsed question editor with type, prompt, options, answer, publish button.
- `practice`: question card, choices/input, submit, previous/next.
- `wrong`: wrong question list.
- `settings`: AI/API config, backup, clear cache, diagnostics.

- [ ] **Step 3: Manual verification**

Open `app/index.html`.

Expected:

- The app opens without a build step.
- Bottom tabs work.
- Sample questions appear.
- Import text can be parsed.
- Published paper can be practiced.
- Settings form saves values.

## Task 6: PDF Extraction Tool

**Files:**
- Create: `tools/extract_pdf_text.py`

- [ ] **Step 1: Create `tools/extract_pdf_text.py`**

```python
from pathlib import Path
import sys

import pdfplumber


def extract(pdf_path: Path, out_path: Path) -> None:
    chunks = []
    with pdfplumber.open(str(pdf_path)) as pdf:
        for index, page in enumerate(pdf.pages, start=1):
            text = page.extract_text() or ""
            chunks.append(f"\n--- page {index} ---\n{text}")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(chunks).strip(), encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: python tools/extract_pdf_text.py input.pdf output.txt")
    extract(Path(sys.argv[1]), Path(sys.argv[2]))
```

- [ ] **Step 2: Run extraction on sample PDF**

Run: `python tools/extract_pdf_text.py "C:\Users\liu\Desktop\复习题_20260618093745.pdf" work/sample-pdf.txt`

Expected:

- `work/sample-pdf.txt` exists.
- It contains `一、单项选择题`.

- [ ] **Step 3: Test parser with extracted text**

Run a small Node command importing `parseQuestionText` and reading `work/sample-pdf.txt`.

Expected: At least 20 questions parse from the sample.

## Task 7: iOS WebView and Cloud Build Scaffolding

**Files:**
- Create: `ios/QuizTool/README.md`
- Create: `ios/QuizTool/QuizTool/AppDelegate.swift`
- Create: `ios/QuizTool/QuizTool/SceneDelegate.swift`
- Create: `ios/QuizTool/QuizTool/ViewController.swift`
- Create: `ios/QuizTool/QuizTool/Info.plist`
- Create: `codemagic.yaml`

- [ ] **Step 1: Create iOS scaffold files**

Create a minimal WKWebView app scaffold that loads `app/index.html` from bundled resources. This scaffold documents the intended Xcode project structure even if the Windows environment cannot compile it.

- [ ] **Step 2: Create `codemagic.yaml`**

```yaml
workflows:
  ios-ipa:
    name: iOS IPA Build
    max_build_duration: 60
    instance_type: mac_mini_m2
    environment:
      vars:
        XCODE_WORKSPACE: "ios/QuizTool/QuizTool.xcodeproj"
        XCODE_SCHEME: "QuizTool"
    scripts:
      - name: Verify web app files
        script: |
          test -f app/index.html
          test -f app/src/app.js
      - name: Build archive
        script: |
          xcodebuild -project "$XCODE_WORKSPACE" -scheme "$XCODE_SCHEME" -configuration Release archive -archivePath build/QuizTool.xcarchive
      - name: Export IPA
        script: |
          xcodebuild -exportArchive -archivePath build/QuizTool.xcarchive -exportPath build/ipa -exportOptionsPlist ios/ExportOptions.plist
    artifacts:
      - build/ipa/*.ipa
```

- [ ] **Step 3: Document signing gap**

Add to `ios/QuizTool/README.md`: Codemagic signing requires Apple signing assets or an adjusted TrollStore-friendly signing workflow. The scaffold is build-oriented and may need project generation on macOS.

## Task 8: Verification

**Files:**
- Create: `tools/check_app_files.py`

- [ ] **Step 1: Create static checker**

```python
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
]

missing = [path for path in required if not Path(path).exists()]
if missing:
    raise SystemExit("Missing files: " + ", ".join(missing))

print("app file check passed")
```

- [ ] **Step 2: Run all verification**

Run:

```powershell
& "C:\Users\liu\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe" app/tests/parser.test.mjs
& "C:\Users\liu\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe" app/tests/quiz-engine.test.mjs
& "C:\Users\liu\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" tools/check_app_files.py
```

Expected:

- Parser tests pass.
- Quiz engine tests pass.
- Static file check passes.

## Self-Review Notes

- Spec coverage: The plan covers UI, import parsing, PDF sample extraction, AI/API settings, local storage, iOS 16-oriented WebView shape, cloud build scaffolding, and tests.
- Known limitation: Windows cannot verify real Xcode archive locally. Cloud build verification requires Codemagic or GitHub Actions.
- No placeholder implementation steps remain in parser, quiz engine, storage, API config, and tools. UI and iOS scaffold tasks describe required behavior because the exact code will be implemented during execution.
