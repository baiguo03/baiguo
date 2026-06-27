import assert from "node:assert/strict";
import { parseOptions, parseQuestionText, splitQuestionBlocks } from "../src/parser.js";

const sample = `一、单项选择题（共 50 题，每题 2 分）
1.温抗体型的自身免疫溶血性贫血的抗体类型一般为（） A. IgA B. IgM
C. IgD D. IgG
2.凝血因子 Ⅶ 主要参与哪条凝血途径（） A. 内源性凝血途径 B. 外源性凝血途径 C. 共同凝血途径 D. 纤溶途径`;

const blocks = splitQuestionBlocks(sample);
assert.equal(blocks.length, 2);
assert.equal(blocks[0].number, 1);

const parsedOptions = parseOptions(blocks[0].raw);
assert.equal(parsedOptions.prompt.includes("温抗体型"), true);
assert.equal(parsedOptions.options.length, 4);
assert.equal(parsedOptions.options[3].text, "IgG");

const result = parseQuestionText(sample);
assert.equal(result.questions.length, 2);
assert.equal(result.questions[0].type, "single");
assert.equal(result.questions[0].options.length, 4);
assert.equal(result.questions[0].options[3].text, "IgG");
assert.equal(result.questions[1].prompt.includes("凝血因子"), true);

console.log("parser tests passed");
