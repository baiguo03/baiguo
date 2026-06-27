import assert from "node:assert/strict";
import { buildPracticeOrder, checkAnswer, createAnswerRecord, shouldAutoAdvance } from "../src/quiz-engine.js";

assert.equal(checkAnswer({ type: "single", answer: "A" }, "A"), true);
assert.equal(checkAnswer({ type: "single", answer: "A" }, "B"), false);
assert.equal(checkAnswer({ type: "multiple", answer: ["A", "C"] }, ["C", "A"]), true);
assert.equal(checkAnswer({ type: "multiple", answer: ["A", "C"] }, ["A"]), false);
assert.equal(checkAnswer({ type: "blank", answer: ["红细胞", "RBC"] }, "rbc"), true);
assert.equal(checkAnswer({ type: "short", answer: "参考答案" }, "用户答案"), null);

const record = createAnswerRecord({ id: "q1", type: "single", answer: "B" }, "A", 12);
assert.equal(record.questionId, "q1");
assert.equal(record.correct, false);
assert.equal(record.elapsedSeconds, 12);

assert.deepEqual(buildPracticeOrder(["q1", "q2", "q3"], "sequential"), ["q1", "q2", "q3"]);
assert.deepEqual(buildPracticeOrder(["q1", "q2", "q3"], "random", () => 0), ["q2", "q3", "q1"]);
assert.equal(shouldAutoAdvance({ correct: true }, { type: "single" }), true);
assert.equal(shouldAutoAdvance({ correct: false }, { type: "single" }), false);
assert.equal(shouldAutoAdvance({ correct: null }, { type: "short" }), false);

console.log("quiz-engine tests passed");
