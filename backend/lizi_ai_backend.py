#!/usr/bin/env python3
import json
import os
import re
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


HOST = os.environ.get("LIZI_HOST", "0.0.0.0")
PORT = int(os.environ.get("LIZI_PORT", "8787"))
AI_BASE_URL = os.environ.get("LIZI_AI_BASE_URL", "https://api.openai.com/v1/chat/completions").strip()
AI_MODEL = os.environ.get("LIZI_AI_MODEL", "gpt-4.1-mini").strip()
AI_KEY = os.environ.get("LIZI_AI_KEY", "").strip()


LETTERS = "ABCDEFGH"


def send_json(handler, status, payload):
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
    handler.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


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
        if self.path == "/health":
            send_json(self, 200, {"ok": True, "model": AI_MODEL, "aiConfigured": bool(AI_KEY)})
            return
        send_json(self, 404, {"error": "not found"})

    def do_POST(self):
        if self.path not in ["/api/parse-questions", "/api/validate-questions"]:
            send_json(self, 404, {"error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length).decode("utf-8")
            payload = json.loads(body or "{}")
            text = normalize_text(payload.get("text", ""))
            title = payload.get("title", "题库")
            source = payload.get("source", "local")
            mode = payload.get("mode") or ("validate" if self.path.endswith("validate-questions") else "parse")
            request_key = self.headers.get("Authorization", "").strip()
            if request_key.lower().startswith("bearer "):
                request_key = request_key[7:].strip()
            if not text:
                send_json(self, 400, {"error": "missing text", "questions": []})
                return
            result = call_ai(mode, title, source, text, request_key=request_key)
            if not result:
                result = {"questions": local_parse(text), "localFallback": True}
            send_json(self, 200, result)
        except urllib.error.HTTPError as exc:
            send_json(self, 502, {"error": f"AI HTTP {exc.code}", "questions": local_parse(payload.get("text", "")) if "payload" in locals() else []})
        except Exception as exc:
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
