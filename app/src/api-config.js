const CONFIG_KEY = "quiz_api_config";

const DEFAULT_CONFIG = {
  endpoint: "",
  apiKey: "",
  model: "gpt-4.1-mini",
  strategy: "hybrid",
  sendOnlyFlagged: true,
};

function readJsonStorage(key) {
  try {
    return JSON.parse(localStorage.getItem(key) || "null");
  } catch {
    return null;
  }
}

function writeJsonStorage(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Safari/WKWebView private contexts can throw here.
  }
}

export function loadApiConfig() {
  return { ...DEFAULT_CONFIG, ...(readJsonStorage(CONFIG_KEY) || {}) };
}

export function saveApiConfig(config) {
  writeJsonStorage(CONFIG_KEY, {
    endpoint: String(config.endpoint || "").trim(),
    apiKey: String(config.apiKey || "").trim(),
    model: String(config.model || DEFAULT_CONFIG.model).trim(),
    strategy: config.strategy || DEFAULT_CONFIG.strategy,
    sendOnlyFlagged: config.sendOnlyFlagged !== false,
  });
}

export async function testApiConnection(config) {
  if (!config.endpoint) return { ok: false, message: "请填写 API 地址" };

  try {
    const headers = {
      "Content-Type": "application/json",
    };
    if (config.apiKey) {
      headers.Authorization = `Bearer ${config.apiKey}`;
    }
    const response = await fetch(config.endpoint, {
      method: "POST",
      headers,
      body: JSON.stringify({
        model: config.model,
        title: "连接测试",
        source: "app-settings",
        text: "1. 连接测试题\nA. 正常\n答案：A",
        mode: "parse",
      }),
    });
    return {
      ok: response.ok,
      message: response.ok ? "连接成功" : `连接失败：${response.status}`,
    };
  } catch (error) {
    return { ok: false, message: `连接失败：${error?.message || "网络异常"}` };
  }
}
