const CONFIG_KEY = "quiz_api_config";

export function loadApiConfig() {
  return JSON.parse(
    localStorage.getItem(CONFIG_KEY) ||
      JSON.stringify({
        endpoint: "",
        apiKey: "",
        model: "gpt-4.1-mini",
        strategy: "hybrid",
        sendOnlyFlagged: true,
      }),
  );
}

export function saveApiConfig(config) {
  localStorage.setItem(
    CONFIG_KEY,
    JSON.stringify({
      endpoint: String(config.endpoint || "").trim(),
      apiKey: String(config.apiKey || "").trim(),
      model: String(config.model || "gpt-4.1-mini").trim(),
      strategy: config.strategy || "hybrid",
      sendOnlyFlagged: config.sendOnlyFlagged !== false,
    }),
  );
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
