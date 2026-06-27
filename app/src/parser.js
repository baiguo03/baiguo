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

  return matches
    .map((match, index) => {
      const start = match.index + match[0].length;
      const end = index + 1 < matches.length ? matches[index + 1].index : normalized.length;
      return {
        number: Number(match[1]),
        raw: normalized.slice(start, end).trim(),
      };
    })
    .filter((block) => block.raw);
}

export function parseOptions(raw) {
  const optionMatches = [...raw.matchAll(/(?:^|\s)([A-H])[\.\．、]\s*/g)];
  if (!optionMatches.length) return { prompt: raw.trim(), options: [] };

  const prompt = raw.slice(0, optionMatches[0].index).trim();
  const options = optionMatches
    .map((match, index) => {
      const key = match[1].toUpperCase();
      const start = match.index + match[0].length;
      const end = index + 1 < optionMatches.length ? optionMatches[index + 1].index : raw.length;
      return { key, text: raw.slice(start, end).trim() };
    })
    .filter((option) => option.text);

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
    warnings: questions.flatMap((question) =>
      question.warnings.map((warning) => `第 ${question.sourceNumber || "?"} 题：${warning}`),
    ),
  };
}
