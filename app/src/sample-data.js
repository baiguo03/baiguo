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
    explanation: "温抗体型自身免疫溶血性贫血多为 IgG 型抗体。",
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
