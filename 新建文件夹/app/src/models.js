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
