import re


ANSWER_SUMMARY = "\u5355\u9009\u9898\u7b54\u6848"


def strip_answer_summary(text: str) -> str:
    markers = [
        "\u5355\u9009\u9898\u7b54\u6848",
        "\u591a\u9009\u9898\u7b54\u6848",
        "\u5224\u65ad\u9898\u7b54\u6848",
        "\u53c2\u8003\u7b54\u6848",
        "\u7b54\u6848\u6c47\u603b",
    ]
    positions = [text.find(marker) for marker in markers if marker in text]
    return text[: min(positions)] if positions else text


def normalize_answer_keys(value: str) -> set[str]:
    keys = {char for char in value.upper() if char in "ABCDEF"}
    if not keys:
        if any(token in value for token in ["\u6b63", "\u5bf9", "\u221a", "\u2713"]):
            keys.add("A")
        elif any(token in value for token in ["\u8bef", "\u9519", "\u00d7", "\u2717"]):
            keys.add("B")
    return keys


def extract_answer_summary_answers(text: str) -> dict[int, set[str]]:
    markers = [
        "\u5355\u9009\u9898\u7b54\u6848",
        "\u591a\u9009\u9898\u7b54\u6848",
        "\u5224\u65ad\u9898\u7b54\u6848",
        "\u53c2\u8003\u7b54\u6848",
        "\u7b54\u6848\u6c47\u603b",
    ]
    positions = [text.find(marker) for marker in markers if marker in text]
    if not positions:
        return {}
    summary = text[min(positions) :]
    answers: dict[int, set[str]] = {}
    pattern = r"(\d{1,3})\s*[\.\u3001\uff0e:\uff1a]?\s*([A-Fa-f]+|\u6b63\u786e|\u9519\u8bef|\u5bf9|\u9519|\u221a|\u2713|\u00d7|\u2717)"
    for number, answer in re.findall(pattern, summary):
        keys = normalize_answer_keys(answer)
        if keys:
            answers[int(number)] = keys
    return answers


def split_question_blocks(text: str) -> list[str]:
    text = strip_answer_summary(text)
    text = re.sub(
        r"(\s+)(\d{1,3}[\.\u3001\uff0e]\s*)(?=[^\n]{0,180}\s*A\s*[\.\uff0e\u3001:\uff1a])",
        r"\n\2",
        text.strip(),
    )
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    blocks: list[str] = []
    current: list[str] = []
    for line in lines:
        if re.match(r"^\d{1,3}[\.\u3001\uff0e]", line) and current:
            blocks.append(" ".join(current))
            current = []
        current.append(line)
    if current:
        blocks.append(" ".join(current))
    return blocks


def option_keys(block: str) -> list[str]:
    body = re.split(r"\u7b54\u6848[:\uff1a]|\u89e3\u6790[:\uff1a]", block)[0]
    return re.findall(r"([A-F])\s*[\.\uff0e\u3001:\uff1a]\s*", body)


sample = (
    "1. \u7b2c\u4e00\u9898 A. \u7532 B. \u4e59 C. \u4e19 D. \u4e01 "
    "2. \u7b2c\u4e8c\u9898 A. \u5b50 B. \u4e11 C. \u5bc5 D. \u536f "
    "3. \u5224\u65ad\u9898\u793a\u4f8b "
    "\u5355\u9009\u9898\u7b54\u6848 1.D 2.B "
    "\u5224\u65ad\u9898\u7b54\u6848 3.\u9519"
)

blocks = split_question_blocks(sample)
if len(blocks) != 2:
    raise SystemExit(f"expected 2 option blocks after stripping summary, got {len(blocks)}: {blocks!r}")

for block in blocks:
    keys = option_keys(block)
    if keys != ["A", "B", "C", "D"]:
        raise SystemExit(f"expected A-D once, got {keys!r} from {block!r}")
    if ANSWER_SUMMARY in block:
        raise SystemExit(f"answer summary leaked into question: {block!r}")

summary = extract_answer_summary_answers(sample)
if summary.get(1) != {"D"} or summary.get(2) != {"B"} or summary.get(3) != {"B"}:
    raise SystemExit(f"summary answers not normalized correctly: {summary!r}")

print("question parser checks passed")
