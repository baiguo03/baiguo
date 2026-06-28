from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
backend = (ROOT / "backend" / "lizi_ai_backend.py").read_text(encoding="utf-8")
readme = (ROOT / "backend" / "README.md").read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


require("ThreadingHTTPServer" in backend, "backend server is missing")
require("/api/parse-questions" in backend, "parse endpoint is missing")
require("/api/validate-questions" in backend, "validate endpoint is missing")
require("/health" in backend, "health endpoint is missing")
require("LIZI_AI_KEY" in backend and "Authorization" in backend, "AI key forwarding is missing")
require("local_parse" in backend and "localFallback" in backend, "local fallback parser is missing")
require((ROOT / "backend" / "run_local_backend.ps1").exists(), "local run script is missing")
require((ROOT / "backend" / "package_backend.ps1").exists(), "package script is missing")
require("http://192.168.1.23:8787/api/parse-questions" in readme, "README does not show phone API URL example")

print("backend checks passed")
