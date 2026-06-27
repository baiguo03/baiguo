import { loadApiConfig, saveApiConfig, testApiConnection } from "./api-config.js";
import { QUESTION_TYPES, createId } from "./models.js";
import { parseQuestionText } from "./parser.js";
import { buildPracticeOrder, createAnswerRecord, shouldAutoAdvance } from "./quiz-engine.js";
import { sampleQuestions } from "./sample-data.js";
import { clearStore, exportBackup, getAllItems, saveItem, saveItems } from "./storage.js";

const app = document.querySelector("#app");
const sessionId = `boot_${Date.now().toString(36)}`;

const state = {
  view: "library",
  questions: [],
  papers: [],
  reviewItems: [],
  parsedQuestions: [],
  parsedWarnings: [],
  activePaperId: null,
  activeQuestionIds: [],
  activeIndex: 0,
  practiceMode: "sequential",
  selectedAnswer: null,
  result: null,
  notice: "",
  error: "",
  autoAdvanceTimer: null,
};

function safeJson(value, fallback) {
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

function iconForType(type) {
  return {
    single: "A",
    multiple: "M",
    judge: "J",
    blank: "B",
    short: "S",
  }[type] || "?";
}

function colorForIndex(index) {
  return ["blue", "green", "orange", "purple", "red", "gray"][index % 6];
}

function setNotice(message) {
  state.notice = message;
  window.setTimeout(() => {
    if (state.notice === message) {
      state.notice = "";
      render();
    }
  }, 2400);
}

function setError(message) {
  state.error = message;
  render();
}

function clearError() {
  state.error = "";
}

function clearAutoAdvance() {
  if (state.autoAdvanceTimer) {
    window.clearTimeout(state.autoAdvanceTimer);
    state.autoAdvanceTimer = null;
  }
}

function currentPaper() {
  return state.papers.find((paper) => paper.id === state.activePaperId) || state.papers[0];
}

function questionsForPaper(paper) {
  if (!paper) return [];
  const ids = state.activeQuestionIds.length && paper.id === state.activePaperId ? state.activeQuestionIds : paper.questionIds;
  return ids.map((id) => state.questions.find((question) => question.id === id)).filter(Boolean);
}

function isSelected(key) {
  if (Array.isArray(state.selectedAnswer)) return state.selectedAnswer.includes(key);
  return state.selectedAnswer === key;
}

function page(title, subtitle, body) {
  return `
    <main class="app-shell">
      <header class="topbar">
        <div>
          <h1 class="large-title">${title}</h1>
          ${subtitle ? `<p class="caption">${subtitle}</p>` : ""}
        </div>
        <div class="topbar-meta">
          ${state.notice ? `<div class="pill">${state.notice}</div>` : ""}
          <div class="session-pill">${sessionId}</div>
        </div>
      </header>
      ${state.error ? renderErrorPanel() : ""}
      ${body}
    </main>
    ${tabs()}
  `;
}

function renderErrorPanel() {
  return `
    <section class="error-panel">
      <div class="error-title">应用启动失败</div>
      <div class="error-text">${state.error}</div>
    </section>
  `;
}

function tabs() {
  const items = [
    ["library", "题库"],
    ["practice", "练习"],
    ["wrong", "错题"],
    ["settings", "设置"],
  ];
  return `
    <nav class="bottom-tabs">
      ${items
        .map(
          ([view, label]) => `
            <button class="tab ${state.view === view ? "active" : ""}" data-nav="${view}">
              <span>${label}</span>
            </button>
          `,
        )
        .join("")}
    </nav>
  `;
}

function renderLibrary() {
  const answered = state.reviewItems.length;
  const total = state.questions.length || 1;
  const progress = Math.min(100, Math.round((answered / total) * 100));
  const paperRows = state.papers
    .map((paper, index) => {
      const count = paper.questionIds.length;
      return `
        <div class="cell paper-cell">
          <div class="tile-icon ${colorForIndex(index)}">${count}</div>
          <div class="cell-main">
            <div class="cell-title">${paper.title}</div>
            <div class="cell-sub">${count} 题 · ${paper.mode === "exam" ? "模拟考试" : "练习模式"}</div>
            <div class="mini-actions">
              <button class="mini-btn" data-start-paper="${paper.id}" data-practice-mode="sequential">顺序练习</button>
              <button class="mini-btn" data-start-paper="${paper.id}" data-practice-mode="random">随机练习</button>
            </div>
          </div>
        </div>
      `;
    })
    .join("");

  return page(
    "刷题",
    "导入文档，校对题库，然后开始练习。",
    `
      <section class="progress-card">
        <div class="progress-row">
          <div>
            <div class="cell-sub">本机题库</div>
            <div class="big-number">${state.questions.length}</div>
          </div>
          <div class="pill">错题 ${state.reviewItems.length}</div>
        </div>
        <div class="progress-bar"><div class="progress-fill" style="--progress:${progress}%"></div></div>
      </section>
      <button class="primary" data-nav="import">导入文档生成试卷</button>
      <div class="section-label">我的试卷</div>
      <section class="group">${paperRows || `<div class="empty">还没有试卷</div>`}</section>
    `,
  );
}

function renderImport() {
  return page(
    "导入",
    "支持从 PDF、Word、TXT、Markdown、CSV 等文档抽取后粘贴。",
    `
      <section class="upload-card">
        <div class="field">
          <label>题目文本</label>
          <textarea class="textarea" id="importText" placeholder="例如：1. 题干 A. ... B. ... C. ... D. ..."></textarea>
        </div>
        <div class="button-row">
          <button class="secondary" id="loadSample">填入样本</button>
          <button class="primary" id="parseText">开始解析</button>
        </div>
        <p class="small">先把 PDF/Word 里的文字抽出来再粘贴。后续也可以接上传入口。</p>
      </section>
      ${state.parsedQuestions.length ? renderParseSummary() : ""}
    `,
  );
}

function renderParseSummary() {
  return `
    <div class="section-label">解析结果</div>
    <section class="group">
      <div class="cell">
        <div class="tile-icon blue">${state.parsedQuestions.length}</div>
        <div class="cell-main">
          <div class="cell-title">识别到 ${state.parsedQuestions.length} 道题</div>
          <div class="cell-sub">${state.parsedWarnings.length} 条需要校对的提示</div>
        </div>
      </div>
    </section>
    ${state.parsedWarnings.length ? `<ul class="warning-list">${state.parsedWarnings.slice(0, 6).map((item) => `<li>${item}</li>`).join("")}</ul>` : ""}
    <button class="primary" data-nav="review">逐题校对并发布</button>
  `;
}

function renderReview() {
  if (!state.parsedQuestions.length) {
    return page("校对", "导入解析后会在这里逐题编辑。", `<section class="panel empty">暂无待校对题目</section>`);
  }

  const cards = state.parsedQuestions
    .map(
      (question, index) => `
        <section class="editor-card" data-editor="${index}">
          <div class="question-meta">
            <span>第 ${question.sourceNumber || index + 1} 题</span>
            <span>${question.warnings?.length ? question.warnings.join("，") : "待校对"}</span>
          </div>
          <div class="field">
            <label>题型</label>
            <select class="select" data-edit="${index}" data-field="type">
              ${Object.entries(QUESTION_TYPES)
                .map(([key, label]) => `<option value="${key}" ${question.type === key ? "selected" : ""}>${label}</option>`)
                .join("")}
            </select>
          </div>
          <div class="field">
            <label>题干</label>
            <textarea class="textarea" data-edit="${index}" data-field="prompt">${question.prompt}</textarea>
          </div>
          <div class="field">
            <label>选项（每行一个，例如 A. 选项）</label>
            <textarea class="textarea" data-edit="${index}" data-field="options">${question.options.map((option) => `${option.key}. ${option.text}`).join("\n")}</textarea>
          </div>
          <div class="field">
            <label>答案</label>
            <input class="input" data-edit="${index}" data-field="answer" value="${Array.isArray(question.answer) ? question.answer.join(",") : question.answer}">
          </div>
          <div class="field">
            <label>解析</label>
            <textarea class="textarea" data-edit="${index}" data-field="explanation">${question.explanation || ""}</textarea>
          </div>
        </section>
      `,
    )
    .join("");

  return page(
    "校对",
    "发布前先确认题型和答案。",
    `${cards}<button class="primary" id="publishPaper">发布为试卷</button>`,
  );
}

function renderPractice() {
  const paper = currentPaper();
  const questions = questionsForPaper(paper);
  const question = questions[state.activeIndex];

  if (!question) {
    return page("练习", "先选一套试卷开始。", `<section class="panel empty">暂无可练题目，请先导入或发布试卷。</section>`);
  }

  const input = ["blank", "short"].includes(question.type)
    ? `<input class="input" id="answerInput" placeholder="${question.type === "short" ? "输入简答后提交" : "输入答案"}">`
    : `<div class="option-grid">${question.options.map((option) => `
        <button class="option-row ${isSelected(option.key) ? "selected" : ""}" data-answer="${option.key}">
          <span class="choice-dot">${option.key}</span>
          <span>${option.text}</span>
        </button>
      `).join("")}</div>`;

  return page(
    "练习",
    `${paper?.title || "练习"} · ${state.practiceMode === "random" ? "随机练习" : "顺序练习"} · ${state.activeIndex + 1} / ${questions.length}`,
    `
      <section class="question-card">
        <div class="question-meta">
          <span>${QUESTION_TYPES[question.type]}</span>
          <span>${question.tags?.join(" / ") || "本机题库"}</span>
        </div>
        <div class="question-text">${question.prompt}</div>
      </section>
      ${input}
      <div class="button-row">
        <button class="secondary" id="prevQuestion">上一题</button>
        <button class="primary" id="submitAnswer">提交</button>
      </div>
      ${state.result ? renderAnswerResult(question) : ""}
    `,
  );
}

function renderAnswerResult(question) {
  const cls = state.result.correct === true ? "correct" : state.result.correct === false ? "wrong" : "";
  const verdict = state.result.correct === true ? "回答正确" : state.result.correct === false ? "回答错误" : "简答题请参考答案自判";
  return `
    <section class="result-box ${cls}">
      <strong>${verdict}</strong><br>
      参考答案：${Array.isArray(question.answer) ? question.answer.join("、") : question.answer || "未设置"}<br>
      ${question.explanation ? `解析：${question.explanation}<br>` : ""}
      <button class="primary" id="nextQuestion" style="margin-top:10px">下一题</button>
    </section>
  `;
}

function renderWrong() {
  const rows = state.reviewItems
    .map((item, index) => {
      const question = state.questions.find((entry) => entry.id === item.questionId);
      if (!question) return "";
      return `
        <div class="cell">
          <div class="tile-icon ${colorForIndex(index)}">${iconForType(question.type)}</div>
          <div class="cell-main">
            <div class="cell-title">${question.prompt}</div>
            <div class="cell-sub">${QUESTION_TYPES[question.type]} · ${item.reason || "答错"}</div>
          </div>
        </div>
      `;
    })
    .join("");

  return page("错题", "系统会自动记录答错题目，后续用于复习。", `<section class="group">${rows || `<div class="empty">还没有错题</div>`}</section>`);
}

function renderSettings() {
  const config = loadApiConfig();
  return page(
    "设置",
    "配置 API、备份和诊断。",
    `
      <section class="panel">
        <div class="field">
          <label>API 地址</label>
          <input class="input" id="apiEndpoint" value="${config.endpoint}" placeholder="https://api.example.com/v1/responses">
        </div>
        <div class="field">
          <label>API Key</label>
          <input class="input" id="apiKey" value="${config.apiKey}" placeholder="sk-...">
        </div>
        <div class="field">
          <label>模型</label>
          <input class="input" id="apiModel" value="${config.model}">
        </div>
        <div class="field">
          <label>解析策略</label>
          <select class="select" id="apiStrategy">
            <option value="hybrid" ${config.strategy === "hybrid" ? "selected" : ""}>混合模式</option>
            <option value="local" ${config.strategy === "local" ? "selected" : ""}>本地优先</option>
            <option value="ai" ${config.strategy === "ai" ? "selected" : ""}>AI 优先</option>
          </select>
        </div>
        <div class="button-row">
          <button class="secondary" id="testApi">测试连接</button>
          <button class="primary" id="saveApi">保存配置</button>
        </div>
        <p class="small">建议通过后端代理使用正式接口，手机端仅保存你自己的配置。</p>
      </section>
      <section class="group">
        <button class="cell" id="exportBackup">
          <div class="tile-icon green">导</div>
          <div class="cell-main">
            <div class="cell-title">导出题库备份</div>
            <div class="cell-sub">生成 JSON 备份文本</div>
          </div>
          <div class="chev">›</div>
        </button>
        <button class="cell" id="clearData">
          <div class="tile-icon red">清</div>
          <div class="cell-main">
            <div class="cell-title">清理本机数据</div>
            <div class="cell-sub">清空题库、试卷和错题</div>
          </div>
          <div class="chev">›</div>
        </button>
      </section>
    `,
  );
}

function renderStartup() {
  app.innerHTML = `
    <main class="app-shell">
      <section class="panel">
        <div class="large-title" style="font-size:28px">刷题工具</div>
        <p class="caption">正在启动...</p>
      </section>
    </main>
  `;
}

function render() {
  if (!app) return;
  const viewMap = {
    library: renderLibrary,
    import: renderImport,
    review: renderReview,
    practice: renderPractice,
    wrong: renderWrong,
    settings: renderSettings,
  };
  app.innerHTML = (viewMap[state.view] || renderLibrary)();
  bindEvents();
}

function navigate(view) {
  clearAutoAdvance();
  state.view = view;
  state.notice = "";
  render();
}

function bindEvents() {
  app.querySelectorAll("[data-nav]").forEach((button) => {
    button.addEventListener("click", () => navigate(button.dataset.nav));
  });

  app.querySelectorAll("[data-start-paper]").forEach((button) => {
    button.addEventListener("click", () => {
      startPractice(button.dataset.startPaper, button.dataset.practiceMode || "sequential");
    });
  });

  app.querySelector("#loadSample")?.addEventListener("click", () => {
    app.querySelector("#importText").value = `一、单项选择题
1. 温抗体型自身免疫性溶血性贫血的抗体类型通常为（ ） A. IgA B. IgM C. IgD D. IgG
2. 凝血因子 II 主要参与哪条凝血途径（ ） A. 内源性凝血途径 B. 外源性凝血途径 C. 共同凝血途径 D. 纤溶途径`;
  });

  app.querySelector("#parseText")?.addEventListener("click", () => {
    const text = app.querySelector("#importText").value;
    const result = parseQuestionText(text);
    state.parsedQuestions = result.questions;
    state.parsedWarnings = result.warnings;
    setNotice(`识别 ${result.questions.length} 题`);
    render();
  });

  app.querySelectorAll("[data-edit]").forEach((field) => {
    field.addEventListener("input", () => updateParsedQuestion(field));
  });

  app.querySelector("#publishPaper")?.addEventListener("click", publishPaper);

  app.querySelectorAll("[data-answer]").forEach((button) => {
    button.addEventListener("click", () => selectAnswer(button.dataset.answer));
  });

  app.querySelector("#prevQuestion")?.addEventListener("click", () => moveQuestion(-1));
  app.querySelector("#nextQuestion")?.addEventListener("click", () => moveQuestion(1));
  app.querySelector("#submitAnswer")?.addEventListener("click", submitAnswer);
  app.querySelector("#saveApi")?.addEventListener("click", saveSettings);
  app.querySelector("#testApi")?.addEventListener("click", testSettings);
  app.querySelector("#exportBackup")?.addEventListener("click", exportData);
  app.querySelector("#clearData")?.addEventListener("click", clearData);
}

function updateParsedQuestion(field) {
  const index = Number(field.dataset.edit);
  const question = state.parsedQuestions[index];
  if (!question) return;

  const value = field.value;
  if (field.dataset.field === "options") {
    question.options = value
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean)
      .map((line, optionIndex) => {
        const match = line.match(/^([A-H])[.、．)\s]*(.*)$/i);
        return {
          key: match ? match[1].toUpperCase() : String.fromCharCode(65 + optionIndex),
          text: match ? match[2].trim() : line,
        };
      });
  } else if (field.dataset.field === "answer" && question.type === "multiple") {
    question.answer = value.split(/[,，\s]+/).filter(Boolean).map((item) => item.toUpperCase());
  } else {
    question[field.dataset.field] = value;
  }
  question.reviewed = true;
}

async function publishPaper() {
  const questions = state.parsedQuestions.map((question) => ({
    ...question,
    id: question.id || createId("q"),
    reviewed: true,
  }));
  await saveItems("questions", questions);
  const paper = {
    id: createId("paper"),
    title: `导入试卷 ${new Date().toLocaleDateString("zh-CN")}`,
    mode: "practice",
    durationMinutes: 45,
    questionIds: questions.map((question) => question.id),
    createdAt: new Date().toISOString(),
  };
  await saveItem("papers", paper);
  state.questions = await getAllItems("questions");
  state.papers = await getAllItems("papers");
  state.parsedQuestions = [];
  state.parsedWarnings = [];
  state.activePaperId = paper.id;
  state.activeQuestionIds = [];
  setNotice("已发布试卷");
  navigate("library");
}

function startPractice(paperId, mode = "sequential") {
  const paper = state.papers.find((entry) => entry.id === paperId);
  if (!paper) return;
  clearAutoAdvance();
  state.activePaperId = paper.id;
  state.activeQuestionIds = buildPracticeOrder(paper.questionIds, mode);
  state.practiceMode = mode;
  state.activeIndex = 0;
  state.selectedAnswer = null;
  state.result = null;
  navigate("practice");
}

function selectAnswer(answer) {
  const paper = currentPaper();
  const question = questionsForPaper(paper)[state.activeIndex];
  if (!question) return;

  if (question.type === "multiple") {
    const selected = Array.isArray(state.selectedAnswer) ? [...state.selectedAnswer] : [];
    state.selectedAnswer = selected.includes(answer) ? selected.filter((item) => item !== answer) : [...selected, answer];
  } else {
    state.selectedAnswer = answer;
  }
  state.result = null;
  render();
}

async function submitAnswer() {
  const paper = currentPaper();
  const questions = questionsForPaper(paper);
  const question = questions[state.activeIndex];
  if (!question) return;

  const typed = app.querySelector("#answerInput")?.value;
  const answer = ["blank", "short"].includes(question.type) ? typed : state.selectedAnswer;
  const record = createAnswerRecord(question, answer, 0);
  state.result = record;
  await saveItem("attempts", record);
  if (record.correct === false) {
    const review = {
      id: createId("review"),
      questionId: question.id,
      reason: "答错",
      createdAt: new Date().toISOString(),
    };
    await saveItem("reviewItems", review);
    state.reviewItems = await getAllItems("reviewItems");
  }
  render();
  if (shouldAutoAdvance(record, question) && state.activeIndex < questions.length - 1) {
    state.autoAdvanceTimer = window.setTimeout(() => {
      moveQuestion(1);
    }, 850);
  }
}

function moveQuestion(delta) {
  clearAutoAdvance();
  const count = questionsForPaper(currentPaper()).length;
  state.activeIndex = Math.max(0, Math.min(count - 1, state.activeIndex + delta));
  state.selectedAnswer = null;
  state.result = null;
  render();
}

function readApiForm() {
  return {
    endpoint: app.querySelector("#apiEndpoint").value,
    apiKey: app.querySelector("#apiKey").value,
    model: app.querySelector("#apiModel").value,
    strategy: app.querySelector("#apiStrategy").value,
    sendOnlyFlagged: true,
  };
}

function saveSettings() {
  saveApiConfig(readApiForm());
  setNotice("配置已保存");
  render();
}

async function testSettings() {
  saveApiConfig(readApiForm());
  const result = await testApiConnection(readApiForm());
  setNotice(result.message);
  render();
}

async function exportData() {
  const backup = await exportBackup();
  const text = JSON.stringify(backup, null, 2);
  await navigator.clipboard?.writeText(text).catch(() => {});
  setNotice("备份已复制");
  console.log(text);
  render();
}

async function clearData() {
  if (!window.confirm("确定清空本机题库、试卷和错题吗？")) return;
  for (const store of ["questions", "papers", "attempts", "reviewItems"]) {
    await clearStore(store);
  }
  state.questions = [];
  state.papers = [];
  state.reviewItems = [];
  await init();
  setNotice("已清理");
}

async function init() {
  try {
    renderStartup();
    state.questions = await getAllItems("questions");
    state.papers = await getAllItems("papers");
    state.reviewItems = await getAllItems("reviewItems");

    if (!state.questions.length) {
      state.questions = sampleQuestions;
      await saveItems("questions", state.questions);
      const paper = {
        id: createId("paper"),
        title: "样本练习卷",
        mode: "practice",
        durationMinutes: 45,
        questionIds: state.questions.map((question) => question.id),
        createdAt: new Date().toISOString(),
      };
      state.papers = [paper];
      await saveItem("papers", paper);
    }

    clearError();
    render();
  } catch (error) {
    setError(error?.message || String(error));
  }
}

window.addEventListener("error", (event) => {
  setError(event?.error?.message || event.message || "未知运行错误");
});

window.addEventListener("unhandledrejection", (event) => {
  const reason = event?.reason;
  setError(reason?.message || String(reason || "Promise rejected"));
});

window.__QUIZ_TOOL_BOOT__ = sessionId;
init();
