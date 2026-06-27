import re


ANSWER_SUMMARY = "单选题答案"


def strip_answer_summary(text: str) -> str:
    markers = ["单选题答案", "多选题答案", "判断题答案", "参考答案", "答案汇总"]
    positions = [text.find(marker) for marker in markers if marker in text]
    return text[: min(positions)] if positions else text


def split_question_blocks(text: str) -> list[str]:
    text = strip_answer_summary(text)
    text = re.sub(
        r"(\s+)(\d{1,3}[\.、．]\s*)(?=[^\n]{0,180}\s*A\s*[\.．、:：])",
        r"\n\2",
        text.strip(),
    )
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    blocks: list[str] = []
    current: list[str] = []
    for line in lines:
        if re.match(r"^\d{1,3}[\.、．]", line) and current:
            blocks.append(" ".join(current))
            current = []
        current.append(line)
    if current:
        blocks.append(" ".join(current))
    return blocks


def option_keys(block: str) -> list[str]:
    body = re.split(r"答案[:：]|解析[:：]", block)[0]
    return re.findall(r"([A-D])\s*[\.．、:：]\s*", body)


sample = (
    "1. 第一题 A. 甲 B. 乙 C. 丙 D. 丁 答案：A "
    "2. 第二题 A. 子 B. 丑 C. 寅 D. 卯 答案：B "
    "单选题答案 1.A 2.B 3.C 4.D"
)

blocks = split_question_blocks(sample)
if len(blocks) != 2:
    raise SystemExit(f"expected 2 blocks, got {len(blocks)}: {blocks!r}")

for block in blocks:
    keys = option_keys(block)
    if keys != ["A", "B", "C", "D"]:
        raise SystemExit(f"expected A-D once, got {keys!r} from {block!r}")
    if ANSWER_SUMMARY in block:
        raise SystemExit(f"answer summary leaked into question: {block!r}")

print("question parser checks passed")
