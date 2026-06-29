#!/usr/bin/env python3
import json
import os
import re
import socket
import sys
import urllib.error
import urllib.request
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


HOST = os.environ.get("LIZI_HOST", "0.0.0.0")
PORT = int(os.environ.get("LIZI_PORT", "8787"))
AI_BASE_URL = os.environ.get("LIZI_AI_BASE_URL", "https://api.openai.com/v1/chat/completions").strip()
AI_MODEL = os.environ.get("LIZI_AI_MODEL", "gpt-4.1-mini").strip()
AI_KEY = os.environ.get("LIZI_AI_KEY", "").strip()


LETTERS = "ABCDEFGH"
REQUEST_LOGS = []
REQUEST_LOG_LIMIT = 100
CLOUD_STATE_FILE = Path(__file__).with_name("lizi_cloud_state.json")
APP_CONFIG_FILE = Path(__file__).with_name("lizi_app_config.json")


def record_request(path, status, summary, remote="-"):
    REQUEST_LOGS.insert(0, {
        "time": datetime.now().strftime("%H:%M:%S"),
        "path": path,
        "status": status,
        "remote": remote,
        "summary": summary,
    })
    del REQUEST_LOGS[REQUEST_LOG_LIMIT:]


def get_lan_ips():
    ips = []
    try:
        for item in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            ip = item[4][0]
            if ip.startswith("127.") or ip in ips:
                continue
            ips.append(ip)
    except OSError:
        pass
    return ips


def send_json(handler, status, payload):
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
    handler.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def send_html(handler, status, html):
    body = html.encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "text/html; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def backend_status():
    lan_ips = get_lan_ips()
    api_paths = [f"http://{ip}:{PORT}/api/parse-questions" for ip in lan_ips]
    cloud_state = load_cloud_state()
    app_config = load_app_config()
    return {
        "ok": True,
        "host": HOST,
        "port": PORT,
        "model": AI_MODEL,
        "aiConfigured": bool(AI_KEY),
        "lanIps": lan_ips,
        "parseEndpoints": api_paths,
        "healthUrl": f"http://127.0.0.1:{PORT}/health",
        "cloudStateConfigured": CLOUD_STATE_FILE.exists(),
        "cloudPaperCount": cloud_state.get("paperCount", 0),
        "cloudQuestionCount": cloud_state.get("questionCount", 0),
        "appDisabled": bool(app_config.get("appDisabled")),
    }


def build_cloud_state(papers, source="app", device="", updated_at=None):
    return {
        "ok": True,
        "updatedAt": updated_at or datetime.now().isoformat(timespec="seconds"),
        "source": source,
        "device": device,
        "papers": papers,
        "paperCount": len(papers),
        "questionCount": sum(len(item.get("questions", [])) for item in papers if isinstance(item, dict)),
    }


def load_cloud_state():
    if not CLOUD_STATE_FILE.exists():
        return build_cloud_state([], updated_at="")
    try:
        payload = json.loads(CLOUD_STATE_FILE.read_text(encoding="utf-8"))
        papers = payload.get("papers", [])
        return build_cloud_state(
            papers,
            source=payload.get("source", "app"),
            device=payload.get("device", ""),
            updated_at=payload.get("updatedAt", ""),
        )
    except Exception as exc:
        return {"ok": False, "error": str(exc), "papers": []}


def save_cloud_state(payload):
    papers = payload.get("papers")
    if not isinstance(papers, list):
        raise ValueError("missing papers")
    cloud_state = build_cloud_state(
        papers,
        source=payload.get("source", "app"),
        device=payload.get("device", ""),
    )
    CLOUD_STATE_FILE.write_text(json.dumps(cloud_state, ensure_ascii=False, indent=2), encoding="utf-8")
    return cloud_state


def load_app_config():
    defaults = {
        "ok": True,
        "updatedAt": "",
        "appDisabled": False,
        "disableMessage": "",
        "forceCloudSync": True,
    }
    if not APP_CONFIG_FILE.exists():
        return defaults
    try:
        payload = json.loads(APP_CONFIG_FILE.read_text(encoding="utf-8"))
        defaults.update(payload)
        defaults["ok"] = True
        return defaults
    except Exception as exc:
        return {"ok": False, "error": str(exc), **defaults}


def save_app_config(payload):
    config = {
        "ok": True,
        "updatedAt": datetime.now().isoformat(timespec="seconds"),
        "appDisabled": bool(payload.get("appDisabled")),
        "disableMessage": (payload.get("disableMessage") or "").strip(),
        "forceCloudSync": payload.get("forceCloudSync", True) is not False,
    }
    APP_CONFIG_FILE.write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding="utf-8")
    return config


def normalize_imported_papers(payload):
    title = (payload.get("title") or "云端上传题库").strip()
    source = (payload.get("source") or "dashboard").strip()
    text = normalize_text(payload.get("text", ""))
    parsed = None
    if text.startswith("{") or text.startswith("["):
        try:
            parsed = json.loads(text)
        except Exception:
            parsed = None

    if isinstance(parsed, dict) and isinstance(parsed.get("papers"), list):
        return parsed["papers"]
    if isinstance(parsed, dict) and isinstance(parsed.get("questions"), list):
        return [{
            "title": parsed.get("title") or title,
            "source": parsed.get("source") or source,
            "questions": parsed["questions"],
        }]
    if isinstance(parsed, list):
        if parsed and isinstance(parsed[0], dict) and isinstance(parsed[0].get("questions"), list):
            return parsed
        if parsed and isinstance(parsed[0], dict) and "prompt" in parsed[0]:
            return [{"title": title, "source": source, "questions": parsed}]

    if not text:
        raise ValueError("missing text")
    questions = local_parse(text)
    if not questions:
        raise ValueError("no questions parsed")
    return [{"title": title, "source": source, "questions": questions}]


def import_cloud_papers(payload):
    replace = bool(payload.get("replace"))
    imported_papers = normalize_imported_papers(payload)
    existing_state = load_cloud_state()
    existing_papers = existing_state.get("papers", []) if existing_state.get("ok", True) else []
    merged_papers = imported_papers if replace else existing_papers + imported_papers
    saved = save_cloud_state({
        "source": payload.get("source", "dashboard"),
        "device": payload.get("device", "backend-dashboard"),
        "papers": merged_papers,
    })
    saved["importedCount"] = len(imported_papers)
    return saved


def dashboard_html():
    return """<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>李子本地后端控制台</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f7f8fb;
      --panel: #ffffff;
      --ink: #17202a;
      --muted: #667085;
      --line: #d9dee8;
      --brand: #1677ff;
      --good: #14945b;
      --warn: #b56b00;
      --bad: #c43d3d;
      --shadow: 0 14px 38px rgba(23, 32, 42, .08);
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--ink);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Microsoft YaHei", sans-serif;
    }
    header {
      border-bottom: 1px solid var(--line);
      background: #fff;
    }
    .wrap {
      width: min(1120px, calc(100% - 32px));
      margin: 0 auto;
    }
    .topbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      padding: 18px 0;
    }
    h1 {
      margin: 0;
      font-size: 22px;
      line-height: 1.2;
      letter-spacing: 0;
    }
    .subtitle {
      margin: 5px 0 0;
      color: var(--muted);
      font-size: 13px;
    }
    main {
      padding: 22px 0 34px;
    }
    .grid {
      display: grid;
      grid-template-columns: 360px minmax(0, 1fr);
      gap: 18px;
      align-items: start;
    }
    .panel {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      box-shadow: var(--shadow);
      padding: 18px;
    }
    .panel + .panel { margin-top: 18px; }
    h2 {
      margin: 0 0 14px;
      font-size: 16px;
      line-height: 1.25;
      letter-spacing: 0;
    }
    .status {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      min-height: 34px;
      padding: 0 12px;
      border: 1px solid var(--line);
      border-radius: 999px;
      font-weight: 650;
      font-size: 13px;
      background: #fff;
    }
    .dot {
      width: 9px;
      height: 9px;
      border-radius: 999px;
      background: var(--warn);
    }
    .status.good .dot { background: var(--good); }
    .status.bad .dot { background: var(--bad); }
    .kv {
      display: grid;
      grid-template-columns: 84px minmax(0, 1fr);
      gap: 10px 12px;
      margin-top: 14px;
      font-size: 14px;
    }
    .kv dt {
      color: var(--muted);
      margin: 0;
    }
    .kv dd {
      margin: 0;
      min-width: 0;
      overflow-wrap: anywhere;
    }
    code, pre {
      font-family: ui-monospace, SFMono-Regular, Consolas, "Liberation Mono", monospace;
    }
    .endpoint {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-top: 10px;
    }
    .endpoint code {
      flex: 1;
      min-width: 0;
      padding: 10px;
      border: 1px solid var(--line);
      border-radius: 6px;
      background: #f9fafc;
      overflow-wrap: anywhere;
      font-size: 12px;
    }
    button {
      min-height: 36px;
      border: 1px solid #1267d8;
      border-radius: 6px;
      background: var(--brand);
      color: #fff;
      padding: 0 13px;
      font-weight: 650;
      cursor: pointer;
    }
    button.secondary {
      border-color: var(--line);
      background: #fff;
      color: var(--ink);
    }
    button:disabled {
      opacity: .55;
      cursor: wait;
    }
    label {
      display: block;
      margin: 12px 0 7px;
      font-size: 13px;
      color: var(--muted);
    }
    input, textarea, select {
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 6px;
      background: #fff;
      color: var(--ink);
      font: inherit;
      padding: 10px 11px;
      outline: none;
    }
    textarea {
      min-height: 210px;
      resize: vertical;
      line-height: 1.55;
    }
    input:focus, textarea:focus, select:focus {
      border-color: var(--brand);
      box-shadow: 0 0 0 3px rgba(22, 119, 255, .14);
    }
    .row {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
    }
    .actions {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin-top: 14px;
    }
    .hint {
      color: var(--muted);
      font-size: 13px;
    }
    .result-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      margin-bottom: 12px;
    }
    .cards {
      display: grid;
      gap: 10px;
    }
    .question {
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 13px;
      background: #fff;
    }
    .qtitle {
      display: flex;
      align-items: start;
      justify-content: space-between;
      gap: 10px;
      font-weight: 700;
      line-height: 1.45;
    }
    .tag {
      flex: 0 0 auto;
      border-radius: 999px;
      padding: 3px 8px;
      color: #0b5cab;
      background: #eaf3ff;
      font-size: 12px;
      font-weight: 700;
    }
    .options {
      margin: 10px 0 0;
      padding: 0;
      list-style: none;
      display: grid;
      gap: 6px;
      color: #344054;
      font-size: 14px;
    }
    .answer {
      margin-top: 10px;
      color: var(--good);
      font-weight: 700;
      font-size: 14px;
    }
    .explain {
      margin-top: 6px;
      color: var(--muted);
      line-height: 1.5;
      font-size: 14px;
    }
    .request-list {
      display: grid;
      gap: 8px;
    }
    .request-item {
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 10px;
      background: #fff;
      font-size: 13px;
    }
    .request-top {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      margin-bottom: 6px;
    }
    .request-path {
      font-weight: 700;
      overflow-wrap: anywhere;
    }
    .request-status {
      flex: 0 0 auto;
      border-radius: 999px;
      padding: 2px 7px;
      color: #0b5cab;
      background: #eaf3ff;
      font-weight: 700;
      font-size: 12px;
    }
    .request-status.bad {
      color: #a4262c;
      background: #fff1f0;
    }
    .request-meta {
      color: var(--muted);
      line-height: 1.45;
      overflow-wrap: anywhere;
    }
    pre {
      overflow: auto;
      max-height: 420px;
      margin: 0;
      padding: 14px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: #101828;
      color: #e6edf7;
      font-size: 12px;
      line-height: 1.5;
    }
    .tabs {
      display: inline-flex;
      border: 1px solid var(--line);
      border-radius: 7px;
      overflow: hidden;
    }
    .tabs button {
      border: 0;
      border-radius: 0;
      background: #fff;
      color: var(--muted);
      min-height: 32px;
    }
    .tabs button.active {
      background: #eaf3ff;
      color: #0b5cab;
    }
    .hidden { display: none; }
    @media (max-width: 860px) {
      .grid, .row {
        grid-template-columns: 1fr;
      }
      .topbar {
        align-items: flex-start;
        flex-direction: column;
      }
      .actions {
        align-items: stretch;
        flex-direction: column;
      }
      button {
        width: 100%;
      }
    }
  </style>
</head>
<body>
  <header>
    <div class="wrap topbar">
      <div>
        <h1>李子本地后端控制台</h1>
        <p class="subtitle">查看状态、复制 App 地址、测试题库解析。</p>
      </div>
      <div id="statusPill" class="status"><span class="dot"></span><span>检查中</span></div>
    </div>
  </header>
  <main class="wrap">
    <div class="grid">
      <aside>
        <section class="panel">
          <h2>服务状态</h2>
          <dl class="kv">
            <dt>端口</dt><dd id="port">-</dd>
            <dt>模型</dt><dd id="model">-</dd>
            <dt>AI Key</dt><dd id="aiConfigured">-</dd>
            <dt>局域网 IP</dt><dd id="lanIps">-</dd>
            <dt>云端题库</dt><dd id="cloudState">-</dd>
          </dl>
          <div class="endpoint">
            <code id="appEndpoint">加载中...</code>
            <button class="secondary" id="copyEndpoint">复制</button>
          </div>
        </section>

        <section class="panel">
          <h2>连接配置</h2>
          <label for="apiKey">临时 API Key</label>
          <input id="apiKey" type="password" autocomplete="off" placeholder="后端已配置可留空">
          <label for="mode">模式</label>
          <select id="mode">
            <option value="parse">解析题库</option>
            <option value="validate">校验题库</option>
          </select>
          <p class="hint">如果启动后端时没有设置 LIZI_AI_KEY，这里填 key 也可以临时调用 AI；不填则走本地兜底解析。</p>
        </section>

        <section class="panel">
          <h2>最近请求</h2>
          <div id="requests" class="request-list">
            <div class="hint">等待 App 或控制台发起请求。</div>
          </div>
        </section>
      </aside>

      <section class="panel">
        <h2>题库解析测试</h2>
        <div class="row">
          <div>
            <label for="title">题库名</label>
            <input id="title" value="本地测试题库">
          </div>
          <div>
            <label for="source">来源</label>
            <input id="source" value="dashboard">
          </div>
        </div>
        <label for="text">题库文本</label>
        <textarea id="text">1. 下列哪项属于生命体征？
A. 体温
B. 身高
C. 发色
D. 指纹
答案：A
解析：体温是临床常用生命体征之一。</textarea>
        <div class="actions">
          <span class="hint" id="message">准备就绪。</span>
          <button id="runParse">开始解析</button>
        </div>

        <div class="result-head" style="margin-top:18px">
          <h2 style="margin:0">结果</h2>
          <div class="tabs">
            <button id="viewCards" class="active">卡片</button>
            <button id="viewJson">JSON</button>
          </div>
        </div>
        <div id="cards" class="cards"></div>
        <pre id="json" class="hidden">暂无结果</pre>
      </section>
    </div>

    <section class="panel" style="margin-top:18px">
      <div class="result-head">
        <h2 style="margin:0">Cloud Control</h2>
        <button class="secondary" id="refreshCloud">Refresh</button>
      </div>

      <div class="row" style="margin-top:14px">
        <div>
          <label for="cloudImportTitle">Paper title</label>
          <input id="cloudImportTitle" value="后台上传题库">
        </div>
        <div>
          <label for="cloudImportSource">Source</label>
          <input id="cloudImportSource" value="dashboard">
        </div>
      </div>
      <label for="cloudImportText">Import text or JSON</label>
      <textarea id="cloudImportText">1. 下列哪项属于生命体征？ A. 体温 B. 身高 C. 发色 D. 指纹
答案：A
解析：体温属于常见生命体征。</textarea>
      <label style="display:flex;align-items:center;gap:8px;margin-top:12px;color:var(--ink)">
        <input id="replaceCloudLibraries" type="checkbox" style="width:auto">
        Replace all cloud papers
      </label>
      <div class="actions">
        <span class="hint">支持粘贴纯试题文本，也支持粘贴单个 paper / 整包 papers JSON。</span>
        <button id="importCloudPaper">Upload to cloud</button>
      </div>

      <div class="row" style="margin-top:22px">
        <div>
          <label style="margin-top:0">Block app use</label>
          <label style="display:flex;align-items:center;gap:8px;margin-top:8px;color:var(--ink)">
            <input id="appDisabled" type="checkbox" style="width:auto">
            Disable app from backend
          </label>
        </div>
        <div>
          <label for="disableMessage">Disable message</label>
          <input id="disableMessage" value="当前服务暂停，请联系管理员。">
        </div>
      </div>
      <div class="actions">
        <span class="hint">启用后，App 下次启动或刷新配置时会进入停用页。</span>
        <button id="saveAppControl">Save control</button>
      </div>

      <div id="cloudPapers" class="cards" style="margin-top:18px">
        <div class="hint">Loading cloud papers...</div>
      </div>
    </section>
  </main>

  <script>
    const $ = (id) => document.getElementById(id);
    let currentEndpoint = `${location.origin}/api/parse-questions`;

    function setStatus(ok, text) {
      const pill = $("statusPill");
      pill.className = `status ${ok ? "good" : "bad"}`;
      pill.querySelector("span:last-child").textContent = text;
    }

    function escapeHtml(value) {
      return String(value ?? "").replace(/[&<>"']/g, (ch) => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#39;",
      }[ch]));
    }

    async function loadStatus() {
      try {
        const response = await fetch("/health");
        const data = await response.json();
        setStatus(Boolean(data.ok), data.ok ? "运行中" : "异常");
        $("port").textContent = data.port ?? "-";
        $("model").textContent = data.model ?? "-";
        $("aiConfigured").textContent = data.aiConfigured ? "已配置" : "未配置";
        $("lanIps").textContent = (data.lanIps || []).join(", ") || "未检测到";
        $("cloudState").textContent = data.cloudStateConfigured ? "已保存" : "暂无";
        currentEndpoint = (data.parseEndpoints && data.parseEndpoints[0]) || `${location.origin}/api/parse-questions`;
        $("appEndpoint").textContent = currentEndpoint;
      } catch (error) {
        setStatus(false, "连接失败");
        $("message").textContent = error.message || "无法读取服务状态";
      }
    }

    async function loadRequests() {
      try {
        const response = await fetch("/api/requests");
        const data = await response.json();
        const items = Array.isArray(data.requests) ? data.requests : [];
        $("requests").innerHTML = items.length
          ? items.slice(0, 12).map((item) => {
              const bad = Number(item.status || 0) >= 400;
              return `<div class="request-item">
                <div class="request-top">
                  <span class="request-path">${escapeHtml(item.path)}</span>
                  <span class="request-status ${bad ? "bad" : ""}">${escapeHtml(item.status)}</span>
                </div>
                <div class="request-meta">${escapeHtml(item.time)} · ${escapeHtml(item.remote)}<br>${escapeHtml(item.summary)}</div>
              </div>`;
            }).join("")
          : `<div class="hint">等待 App 或控制台发起请求。</div>`;
      } catch {
        $("requests").innerHTML = `<div class="hint">请求记录读取失败。</div>`;
      }
    }

    function renderCloudLibraries(data) {
      const papers = Array.isArray(data.papers) ? data.papers : [];
      if (!papers.length) {
        $("cloudPapers").innerHTML = `<div class="hint">No cloud papers yet.</div>`;
        return;
      }
      $("cloudPapers").innerHTML = papers.map((paper, index) => {
        const questions = Array.isArray(paper.questions) ? paper.questions : [];
        const preview = questions.slice(0, 2).map((q) => escapeHtml(q.prompt || "")).join("<br>");
        return `<article class="question">
          <div class="qtitle">
            <span>${index + 1}. ${escapeHtml(paper.title || "Untitled paper")}</span>
            <span class="tag">${questions.length} questions</span>
          </div>
          <div class="explain">Source: ${escapeHtml(paper.source || "-")}</div>
          <div class="explain">${preview || "No question preview"}</div>
        </article>`;
      }).join("");
    }

    async function loadCloudLibraries() {
      try {
        const response = await fetch("/api/cloud-state");
        const data = await response.json();
        renderCloudLibraries(data);
      } catch (error) {
        $("cloudPapers").innerHTML = `<div class="hint">${escapeHtml(error.message || "Failed to load cloud papers.")}</div>`;
      }
    }

    async function loadAppControl() {
      try {
        const response = await fetch("/api/app-config");
        const data = await response.json();
        $("appDisabled").checked = Boolean(data.appDisabled);
        $("disableMessage").value = data.disableMessage || "当前服务暂停，请联系管理员。";
      } catch {
        $("appDisabled").checked = false;
      }
    }

    async function importCloudPaper() {
      const button = $("importCloudPaper");
      button.disabled = true;
      $("message").textContent = "Uploading cloud paper...";
      try {
        const response = await fetch("/api/cloud-library-import", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            title: $("cloudImportTitle").value.trim(),
            source: $("cloudImportSource").value.trim(),
            text: $("cloudImportText").value,
            replace: $("replaceCloudLibraries").checked,
            device: "dashboard"
          }),
        });
        const data = await response.json();
        if (!response.ok) {
          throw new Error(data.error || `HTTP ${response.status}`);
        }
        $("message").textContent = `Cloud saved: ${data.paperCount || 0} papers / ${data.questionCount || 0} questions`;
        await loadCloudLibraries();
        await loadStatus();
        await loadRequests();
      } catch (error) {
        $("message").textContent = error.message || "Cloud upload failed";
      } finally {
        button.disabled = false;
      }
    }

    async function saveAppControl() {
      const button = $("saveAppControl");
      button.disabled = true;
      $("message").textContent = "Saving app control...";
      try {
        const response = await fetch("/api/app-config", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            appDisabled: $("appDisabled").checked,
            disableMessage: $("disableMessage").value.trim(),
            forceCloudSync: true
          }),
        });
        const data = await response.json();
        if (!response.ok) {
          throw new Error(data.error || `HTTP ${response.status}`);
        }
        $("message").textContent = data.appDisabled ? "App has been disabled from backend." : "App access restored.";
        await loadStatus();
        await loadRequests();
      } catch (error) {
        $("message").textContent = error.message || "Failed to save app control";
      } finally {
        button.disabled = false;
      }
    }

    function renderResult(data) {
      $("json").textContent = JSON.stringify(data, null, 2);
      const questions = Array.isArray(data.questions) ? data.questions : [];
      if (!questions.length) {
        $("cards").innerHTML = `<div class="hint">没有解析出题目。</div>`;
        return;
      }
      $("cards").innerHTML = questions.map((q, index) => {
        const options = Array.isArray(q.options) ? q.options : [];
        return `<article class="question">
          <div class="qtitle">
            <span>${index + 1}. ${escapeHtml(q.prompt)}</span>
            <span class="tag">${escapeHtml(q.kind || "题目")}</span>
          </div>
          <ul class="options">${options.map((item) => `<li><b>${escapeHtml(item.key)}.</b> ${escapeHtml(item.text)}</li>`).join("")}</ul>
          <div class="answer">答案：${escapeHtml((q.answer || []).join(", "))}</div>
          <div class="explain">${escapeHtml(q.explanation || "")}</div>
        </article>`;
      }).join("");
    }

    async function parseQuestions() {
      const button = $("runParse");
      button.disabled = true;
      $("message").textContent = "解析中...";
      try {
        const mode = $("mode").value;
        const path = mode === "validate" ? "/api/validate-questions" : "/api/parse-questions";
        const headers = { "Content-Type": "application/json" };
        const apiKey = $("apiKey").value.trim();
        if (apiKey) headers.Authorization = `Bearer ${apiKey}`;
        const response = await fetch(path, {
          method: "POST",
          headers,
          body: JSON.stringify({
            title: $("title").value,
            source: $("source").value,
            text: $("text").value,
            mode,
          }),
        });
        const data = await response.json();
        renderResult(data);
        $("message").textContent = response.ok
          ? `完成：${(data.questions || []).length} 道题${data.localFallback ? "，本地兜底解析" : ""}`
          : `失败：${data.error || response.status}`;
      } catch (error) {
        $("message").textContent = error.message || "请求失败";
      } finally {
        button.disabled = false;
      }
    }

    $("copyEndpoint").addEventListener("click", async () => {
      await navigator.clipboard.writeText(currentEndpoint);
      $("message").textContent = "已复制 App API 地址。";
    });
    $("runParse").addEventListener("click", parseQuestions);
    $("refreshCloud").addEventListener("click", async () => {
      await loadCloudLibraries();
      await loadAppControl();
    });
    $("importCloudPaper").addEventListener("click", importCloudPaper);
    $("saveAppControl").addEventListener("click", saveAppControl);
    $("viewCards").addEventListener("click", () => {
      $("viewCards").classList.add("active");
      $("viewJson").classList.remove("active");
      $("cards").classList.remove("hidden");
      $("json").classList.add("hidden");
    });
    $("viewJson").addEventListener("click", () => {
      $("viewJson").classList.add("active");
      $("viewCards").classList.remove("active");
      $("json").classList.remove("hidden");
      $("cards").classList.add("hidden");
    });

    loadStatus();
    loadRequests();
    loadCloudLibraries();
    loadAppControl();
    setInterval(loadRequests, 2000);
  </script>
</body>
</html>"""


def normalize_text(text):
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def local_parse(text):
    text = normalize_text(text)
    chunks = re.split(r"(?m)(?=^\s*\d+[\.、．]\s*)", text)
    questions = []
    for chunk in chunks:
        chunk = chunk.strip()
        if not chunk:
            continue
        chunk = re.sub(r"^\d+[\.、．]\s*", "", chunk)
        answer = []
        explanation = "暂无解析"
        answer_match = re.search(r"(答案|参考答案)[:：]\s*([A-H]+|正确|错误|对|错)", chunk, re.I)
        if answer_match:
            raw = answer_match.group(2).upper()
            answer = [ch for ch in raw if ch in LETTERS]
            if not answer and raw in ["正确", "对"]:
                answer = ["A"]
            if not answer and raw in ["错误", "错"]:
                answer = ["B"]
        exp_match = re.search(r"(解析|答案解析)[:：]\s*(.+)$", chunk, re.S)
        if exp_match:
            explanation = exp_match.group(2).strip()[:1200] or explanation
        option_matches = list(re.finditer(r"([A-H])[\.\、．:：]\s*", chunk))
        options = []
        prompt = chunk
        if option_matches:
            prompt = chunk[: option_matches[0].start()].strip()
            for i, match in enumerate(option_matches):
                start = match.end()
                end = option_matches[i + 1].start() if i + 1 < len(option_matches) else len(chunk)
                option_text = chunk[start:end]
                option_text = re.split(r"(答案|参考答案|解析|答案解析)[:：]", option_text, maxsplit=1)[0].strip()
                if option_text:
                    options.append({"key": match.group(1), "text": option_text[:800]})
        kind = infer_kind(prompt, options, answer)
        if not options:
            if "判断" in kind:
                options = [{"key": "A", "text": "正确"}, {"key": "B", "text": "错误"}]
            else:
                options = [{"key": "A", "text": explanation}]
        if not answer:
            answer = ["A"]
        prompt = re.split(r"(答案|参考答案|解析|答案解析)[:：]", prompt, maxsplit=1)[0].strip()
        if prompt:
            questions.append({
                "prompt": prompt[:1600],
                "options": options,
                "answer": answer,
                "explanation": explanation,
                "kind": kind,
            })
    return questions


def infer_kind(prompt, options, answer):
    prompt = prompt or ""
    if "简答" in prompt or "案例" in prompt or "分析" in prompt or "问答" in prompt:
        return "简答题"
    if "填空" in prompt or "()" in prompt or "（）" in prompt:
        return "填空题"
    if "配伍" in prompt or "匹配" in prompt:
        return "配伍题"
    if len(answer) > 1:
        return "多选题"
    if len(options) == 2 and any(item.get("text") in ["正确", "错误"] for item in options):
        return "判断题"
    return "单选题" if options else "简答题"


def ai_prompt(mode, title, source, text):
    task = "解析题库文本" if mode != "validate" else "校验并修正已解析题库"
    return f"""你是医学考试题库整理助手，请{task}。
要求：
1. 只输出 JSON，不要 Markdown。
2. JSON 格式：{{"questions":[{{"prompt":"题干","options":[{{"key":"A","text":"选项"}}],"answer":["A"],"explanation":"解析","kind":"单选题"}}]}}
3. kind 只能用：单选题、多选题、判断题、填空题、简答题、配伍题、案例分析题。
4. 简答题不要硬造选项；如果没有选项，options 可为空数组，answer 放参考答案摘要。
5. 填空题按题干空位顺序生成 answer，例如 ["答案1","答案2"]。
6. 不要把下一题题干混入上一题选项；遇到答案汇总要按题号匹配。
7. 不要返回 mode、题库名、来源、校验说明这类元信息，只返回真正题目。
8. explanation 必须回答题目本身，说明为什么答案成立；不要只写“正确选项是 X”或复述选项，建议 15-45 字；没有把握时写“需结合题干知识点复核”。
9. 简答题、案例分析题、名词解释和填空题必须在 answer 中返回文字参考答案；explanation 返回解题依据或补充解析，不能用 explanation 代替 answer。

题库名：{title}
来源：{source}
文本：
{text[:50000]}"""


def call_ai(mode, title, source, text, request_key=None):
    key = AI_KEY or (request_key or "").strip()
    if not key:
        return None
    payload = {
        "model": AI_MODEL,
        "messages": [
            {"role": "system", "content": "你只返回可解析的 JSON。"},
            {"role": "user", "content": ai_prompt(mode, title, source, text)},
        ],
        "temperature": 0.1,
    }
    req = urllib.request.Request(
        AI_BASE_URL,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {key}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    content = data["choices"][0]["message"]["content"].strip()
    content = content.removeprefix("```json").removeprefix("```").removesuffix("```").strip()
    return json.loads(content)


class Handler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        send_json(self, 200, {"ok": True})

    def do_GET(self):
        if self.path in ["/", "/dashboard"]:
            send_html(self, 200, dashboard_html())
            return
        if self.path == "/health":
            send_json(self, 200, backend_status())
            return
        if self.path == "/api/requests":
            send_json(self, 200, {"requests": REQUEST_LOGS})
            return
        if self.path == "/api/app-config":
            record_request(
                self.path,
                200,
                "app config fetch",
                self.client_address[0] if self.client_address else "-",
            )
            send_json(self, 200, load_app_config())
            return
        if self.path == "/api/cloud-state":
            record_request(
                self.path,
                200,
                "cloud state fetch",
                self.client_address[0] if self.client_address else "-",
            )
            send_json(self, 200, load_cloud_state())
            return
        send_json(self, 404, {"error": "not found"})

    def do_POST(self):
        if self.path == "/api/app-config":
            try:
                length = int(self.headers.get("Content-Length", "0"))
                body = self.rfile.read(length).decode("utf-8")
                payload = json.loads(body or "{}")
                saved = save_app_config(payload)
                record_request(
                    self.path,
                    200,
                    f"app config save: disabled={saved['appDisabled']}",
                    self.client_address[0] if self.client_address else "-",
                )
                send_json(self, 200, saved)
            except Exception as exc:
                record_request(
                    self.path,
                    400,
                    str(exc)[:180],
                    self.client_address[0] if self.client_address else "-",
                )
                send_json(self, 400, {"ok": False, "error": str(exc)})
            return
        if self.path == "/api/cloud-state":
            try:
                length = int(self.headers.get("Content-Length", "0"))
                body = self.rfile.read(length).decode("utf-8")
                payload = json.loads(body or "{}")
                saved = save_cloud_state(payload)
                record_request(
                    self.path,
                    200,
                    f"cloud save: {saved['paperCount']} papers, {saved['questionCount']} questions",
                    self.client_address[0] if self.client_address else "-",
                )
                send_json(self, 200, saved)
            except Exception as exc:
                record_request(
                    self.path,
                    400,
                    str(exc)[:180],
                    self.client_address[0] if self.client_address else "-",
                )
                send_json(self, 400, {"ok": False, "error": str(exc)})
            return
        if self.path == "/api/cloud-library-import":
            try:
                length = int(self.headers.get("Content-Length", "0"))
                body = self.rfile.read(length).decode("utf-8")
                payload = json.loads(body or "{}")
                saved = import_cloud_papers(payload)
                record_request(
                    self.path,
                    200,
                    f"cloud import: +{saved['importedCount']} papers, total {saved['paperCount']}",
                    self.client_address[0] if self.client_address else "-",
                )
                send_json(self, 200, saved)
            except Exception as exc:
                record_request(
                    self.path,
                    400,
                    str(exc)[:180],
                    self.client_address[0] if self.client_address else "-",
                )
                send_json(self, 400, {"ok": False, "error": str(exc)})
            return
        if self.path not in ["/api/parse-questions", "/api/validate-questions"]:
            send_json(self, 404, {"error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length).decode("utf-8")
            payload = json.loads(body or "{}")
            text = normalize_text(payload.get("text", "") or payload.get("input", ""))
            title = payload.get("title", "题库")
            source = payload.get("source", "local")
            mode = payload.get("mode") or ("validate" if self.path.endswith("validate-questions") else "parse")
            request_key = self.headers.get("Authorization", "").strip()
            if request_key.lower().startswith("bearer "):
                request_key = request_key[7:].strip()
            if not text:
                record_request(
                    self.path,
                    400,
                    f"{mode}: missing text",
                    self.client_address[0] if self.client_address else "-",
                )
                send_json(self, 400, {"error": "missing text", "questions": []})
                return
            result = call_ai(mode, title, source, text, request_key=request_key)
            if not result:
                result = {"questions": local_parse(text), "localFallback": True}
            record_request(
                self.path,
                200,
                f"{mode}: {len(result.get('questions', []))} questions, {len(text)} chars"
                + (" local fallback" if result.get("localFallback") else " AI"),
                self.client_address[0] if self.client_address else "-",
            )
            send_json(self, 200, result)
        except urllib.error.HTTPError as exc:
            record_request(
                self.path,
                502,
                f"AI HTTP {exc.code}",
                self.client_address[0] if self.client_address else "-",
            )
            send_json(self, 502, {"error": f"AI HTTP {exc.code}", "questions": local_parse(payload.get("text", "")) if "payload" in locals() else []})
        except Exception as exc:
            record_request(
                self.path,
                500,
                str(exc)[:180],
                self.client_address[0] if self.client_address else "-",
            )
            send_json(self, 500, {"error": str(exc), "questions": local_parse(payload.get("text", "")) if "payload" in locals() else []})

    def log_message(self, fmt, *args):
        sys.stdout.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"Lizi backend listening on http://{HOST}:{PORT}")
    print("App API URL: http://<电脑局域网IP>:%s/api/parse-questions" % PORT)
    print("Health check: http://127.0.0.1:%s/health" % PORT)
    server.serve_forever()


if __name__ == "__main__":
    main()
