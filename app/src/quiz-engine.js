import { createId, normalizeAnswer } from "./models.js";

export function checkAnswer(question, userAnswer) {
  if (question.type === "short") return null;
  if (question.type === "multiple") {
    return JSON.stringify(normalizeAnswer(question.answer)) === JSON.stringify(normalizeAnswer(userAnswer));
  }
  if (question.type === "blank") {
    const accepted = Array.isArray(question.answer) ? question.answer : [question.answer];
    const normalizedUser = String(userAnswer ?? "").trim().toLowerCase();
    return accepted.some((item) => String(item).trim().toLowerCase() === normalizedUser);
  }
  return String(question.answer ?? "").trim().toUpperCase() === String(userAnswer ?? "").trim().toUpperCase();
}

export function createAnswerRecord(question, userAnswer, elapsedSeconds = 0) {
  const correct = checkAnswer(question, userAnswer);
  return {
    id: createId("answer"),
    questionId: question.id,
    userAnswer,
    correct,
    elapsedSeconds,
    answeredAt: new Date().toISOString(),
  };
}
