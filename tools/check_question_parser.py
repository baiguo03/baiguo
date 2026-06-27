import re


ANSWER_SUMMARY = "\u5355\u9009\u9898\u7b54\u6848"


def is_answer_heading(line: str) -> bool:
    compact = re.sub(r"\s+", "", line)
    return any(marker in compact for marker in [
        "\u5355\u9009\u9898\u7b54\u6848",
        "\u5355\u9879\u9009\u62e9\u9898\u7b54\u6848",
        "\u591a\u9009\u9898\u7b54\u6848",
        "\u5224\u65ad\u9898\u7b54\u6848",
        "\u540d\u8bcd\u89e3\u91ca\u7b54\u6848",
        "\u7b80\u7b54\u9898\u7b54\u6848",
        "\u6848\u4f8b\u5206\u6790\u9898\u7b54\u6848",
        "\u53c2\u8003\u7b54\u6848",
        "\u7b54\u6848\u6c47\u603b",
    ])


def is_objective_answer_heading(line: str) -> bool:
    compact = re.sub(r"\s+", "", line)
    return any(marker in compact for marker in [
        "\u5355\u9009\u9898\u7b54\u6848",
        "\u5355\u9879\u9009\u62e9\u9898\u7b54\u6848",
        "\u591a\u9009\u9898\u7b54\u6848",
        "\u5224\u65ad\u9898\u7b54\u6848",
        "\u7b54\u6848\u6c47\u603b",
    ])


def answer_heading_suffix(line: str) -> str:
    markers = [
        "\u5355\u9009\u9898\u7b54\u6848",
        "\u5355\u9879\u9009\u62e9\u9898\u7b54\u6848",
        "\u591a\u9009\u9898\u7b54\u6848",
        "\u5224\u65ad\u9898\u7b54\u6848",
        "\u7b54\u6848\u6c47\u603b",
    ]
    positions = [line.find(marker) for marker in markers if marker in line]
    return line[min(positions) :] if positions else line


def is_freeform_answer_heading(line: str) -> bool:
    compact = re.sub(r"\s+", "", line)
    return any(marker in compact for marker in [
        "\u540d\u8bcd\u89e3\u91ca\u7b54\u6848",
        "\u7b80\u7b54\u9898\u7b54\u6848",
        "\u586b\u7a7a\u9898\u7b54\u6848",
        "\u914d\u4f0d\u9898\u7b54\u6848",
        "\u6848\u4f8b\u5206\u6790\u9898\u7b54\u6848",
    ])


def clean_freeform_summary_answer(value: str) -> str:
    text = " ".join(value.split()).strip()
    text = re.sub(r"^\d{1,3}[\.\u3001\uff0e]?\s*", "", text).strip()
    if re.match(r"^(\u6848\u4f8b|\u75c5\u4f8b)\s*\d{1,3}", text):
        text = re.sub(r"^(\u6848\u4f8b|\u75c5\u4f8b)\s*\d{1,3}\s*\u7b54\u6848[:\uff1a]?\s*", "", text).strip()
    return text


def extract_freeform_summary_answers(text: str) -> list[str]:
    answers: list[str] = []
    current: list[str] = []
    collecting = False

    def flush() -> None:
        nonlocal current
        value = clean_freeform_summary_answer(" ".join(current))
        if value:
            answers.append(value)
        current = []

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if is_freeform_answer_heading(line):
            flush()
            collecting = True
            continue
        if is_objective_answer_heading(line):
            flush()
            collecting = False
            continue
        if not collecting:
            continue
        if is_section_heading(line):
            flush()
            collecting = False
            continue
        current_is_case = bool(current and is_case_start(current[0]))
        if (re.match(r"^\d{1,3}[\.\u3001\uff0e]", line) or is_case_start(line)) and current and not (current_is_case and not is_case_start(line)):
            flush()
        current.append(line)
    flush()
    return answers


def is_section_heading(line: str) -> bool:
    compact = re.sub(r"\s+", "", line)
    if is_answer_heading(compact):
        return False
    keywords = [
        "\u5355\u9879\u9009\u62e9\u9898",
        "\u5355\u9009\u9898",
        "\u591a\u9879\u9009\u62e9\u9898",
        "\u591a\u9009\u9898",
        "\u5224\u65ad\u9898",
        "\u586b\u7a7a\u9898",
        "\u7b80\u7b54\u9898",
        "\u540d\u8bcd\u89e3\u91ca",
        "\u914d\u4f0d\u9898",
        "\u6848\u4f8b\u5206\u6790\u9898",
    ]
    if not any(keyword in compact for keyword in keywords):
        return False
    return len(compact) <= 22 or any(token in compact for token in ["\u5171", "\u6bcf\u9898", "\u5206", "\uff08", "("])


def is_case_start(line: str) -> bool:
    return re.match(r"^(\u6848\u4f8b|\u75c5\u4f8b)\s*\d{1,3}", line) is not None


def strip_answer_summary(text: str) -> str:
    markers = [
        "\u5355\u9009\u9898\u7b54\u6848",
        "\u5355\u9879\u9009\u62e9\u9898\u7b54\u6848",
        "\u591a\u9009\u9898\u7b54\u6848",
        "\u5224\u65ad\u9898\u7b54\u6848",
        "\u540d\u8bcd\u89e3\u91ca\u7b54\u6848",
        "\u7b80\u7b54\u9898\u7b54\u6848",
        "\u6848\u4f8b\u5206\u6790\u9898\u7b54\u6848",
        "\u53c2\u8003\u7b54\u6848",
        "\u7b54\u6848\u6c47\u603b",
    ]
    kept: list[str] = []
    skipping_answers = False
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        marker_positions = [line.find(marker) for marker in markers if marker in line]
        marker_position = min(marker_positions) if marker_positions else -1
        if marker_position >= 0:
            prefix = line[:marker_position].strip()
            if prefix and not is_section_heading(prefix):
                kept.append(prefix)
            skipping_answers = True
            continue
        if skipping_answers:
            if is_section_heading(line):
                skipping_answers = False
                continue
            continue
        kept.append(line)
    return "\n".join(kept)


def normalize_answer_keys(value: str) -> set[str]:
    keys = {char for char in value.upper() if char in "ABCDEF"}
    if not keys:
        if any(token in value for token in ["\u6b63", "\u5bf9", "\u221a", "\u2713"]):
            keys.add("A")
        elif any(token in value for token in ["\u8bef", "\u9519", "\u00d7", "\u2717"]):
            keys.add("B")
    return keys


def extract_answer_summary_answers(text: str) -> list[set[str]]:
    summary_lines: list[str] = []
    collecting = False
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if is_objective_answer_heading(line):
            summary_lines.append(answer_heading_suffix(line))
            collecting = True
            continue
        if is_answer_heading(line):
            collecting = False
            continue
        if collecting:
            if is_section_heading(line):
                collecting = False
            else:
                summary_lines.append(line)
    summary = " ".join(summary_lines)
    answers: list[set[str]] = []
    pattern = r"(\d{1,3})\s*[\.\u3001\uff0e:\uff1a]?\s*([A-Fa-f]+|\u6b63\u786e|\u9519\u8bef|\u5bf9|\u9519|\u221a|\u2713|\u00d7|\u2717)"
    for number, answer in re.findall(pattern, summary):
        keys = normalize_answer_keys(answer)
        if keys:
            answers.append(keys)
    return answers


def split_question_blocks(text: str) -> list[str]:
    text = strip_answer_summary(text)
    text = re.sub(
        r"(\s+)(\d{1,3}[\.\u3001\uff0e]\s*)(?=[^\n]{0,180}\s*A\s*[\.\uff0e\u3001:\uff1a])",
        r"\n\2",
        text.strip(),
    )
    text = re.sub(
        r"([A-Fa-f])(?=(\d{1,3}[\.\u3001\uff0e]\s*)[^\n]{0,180}\s*A\s*[\.\uff0e\u3001:\uff1a])",
        r"\1\n",
        text,
    )
    text = re.sub(
        r"([^\s\d])(?=(\d{1,3}[\.\u3001\uff0e]\s*)[^\n]{0,120}[\uff08\(]\s*[\uff09\)])",
        r"\1\n",
        text,
    )
    text = re.sub(
        r"(\s+)(\d{1,3}[\.\u3001\uff0e]\s*)(?=[^\n]{0,120}[\uff08\(]\s*[\uff09\)])",
        r"\n\2",
        text,
    )
    text = re.sub(
        r"(\s+)(\d{1,3}[\.\u3001\uff0e]\s*)(?=[^\n]{0,120}(\u586b\u7a7a|\u7b80\u7b54|\u914d\u4f0d|____|\u7b54\u6848[:\uff1a]))",
        r"\n\2",
        text,
    )
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    blocks: list[str] = []
    current: list[str] = []
    for line in lines:
        if is_section_heading(line):
            continue
        current_is_case = bool(current and is_case_start(current[0]))
        line_starts_question = re.match(r"^\d{1,3}[\.\u3001\uff0e]", line) is not None
        if (is_case_start(line) or (line_starts_question and not current_is_case)) and current:
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

open_question_sample = (
    "1. \u586b\u7a7a\uff1a\u8840\u5c0f\u677f\u7684\u6b62\u8840\u529f\u80fd\u5305\u62ec____\u3002 "
    "\u7b54\u6848\uff1a\u9ecf\u9644\u3001\u805a\u96c6\u3001\u91ca\u653e "
    "2. \u7b80\u7b54\uff1a\u8bf7\u7b80\u8ff0\u51dd\u8840\u56e0\u5b50\u7684\u4f5c\u7528\u3002 "
    "\u7b54\u6848\uff1a\u53c2\u4e0e\u51dd\u8840\u7011\u5e03\u53cd\u5e94 "
    "3. \u914d\u4f0d\uff1a1-\u7f3a\u94c1\u8d2b 2-\u5de8\u5e7c\u8d2b "
    "\u7b54\u6848\uff1a1-A 2-B"
)

section_heading_sample = (
    "\u5355\u9879\u9009\u62e9\u9898\uff08\u5171 50 \u9898\uff0c\u6bcf\u9898 2 \u5206\uff09\n"
    "1. \u5173\u4e8e\u5de8\u5e7c\u7ec6\u80de\u6027\u8d2b\u8840\u7684\u63cf\u8ff0\u54ea\u9879\u9519\u8bef\uff08\uff09\u3002 "
    "A. \u8840\u8c61\u4e2d\u7c92\u7ec6\u80de\u53ef\u51fa\u73b0\u6838\u5de6\u79fb "
    "B. \u67d0\u5de8\u5e7c\u7ec6\u80de\u6027\u8d2b\u8840\u60a3\u8005\u53ef\u4ee5\u51fa\u73b0\u795e\u7ecf\u3001\u7cbe\u795e\u75c7\u72b6 "
    "C. \u5e7c\u7a1a\u7ea2\u7ec6\u80de\u6838\u67d3\u8272\u8d28\u758f\u677e "
    "D. \u60a3\u8005\u53ef\u4ee5\u51fa\u73b0\u955c\u9762\u820c "
    "\u5355\u9009\u9898\u7b54\u6848 1.B"
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
if summary[:3] != [{"D"}, {"B"}, {"B"}]:
    raise SystemExit(f"summary answers not normalized correctly: {summary!r}")

open_blocks = split_question_blocks(open_question_sample)
if len(open_blocks) != 3:
    raise SystemExit(f"expected fill/short/matching questions to remain as blocks, got {len(open_blocks)}: {open_blocks!r}")

section_blocks = split_question_blocks(section_heading_sample)
if len(section_blocks) != 1:
    raise SystemExit(f"section heading should not become a question, got {len(section_blocks)}: {section_blocks!r}")
if "\u5355\u9879\u9009\u62e9\u9898" in section_blocks[0]:
    raise SystemExit(f"section heading leaked into first question: {section_blocks[0]!r}")
if option_keys(section_blocks[0]) != ["A", "B", "C", "D"]:
    raise SystemExit(f"section heading sample lost option boundaries: {section_blocks[0]!r}")
section_summary = extract_answer_summary_answers(section_heading_sample)
if section_summary[:1] != [{"B"}]:
    raise SystemExit(f"section heading sample summary answer failed: {section_summary!r}")

mixed_section_sample = (
    "\u4e00\u3001\u5355\u9879\u9009\u62e9\u9898\uff08\u5171 1 \u9898\uff09\n"
    "1. \u7b2c\u4e00\u9898 A. \u7532 B. \u4e59 C. \u4e19 D. \u4e01\n"
    "\u5355\u9009\u9898\u7b54\u6848 1.B\n"
    "\u4e8c\u3001\u586b\u7a7a\u9898\uff08\u5171 1 \u9898\uff09\n"
    "1. \u8840\u5c0f\u677f\u529f\u80fd\u5305\u62ec____\u3002 \u7b54\u6848\uff1a\u9ecf\u9644\u3001\u805a\u96c6\u3001\u91ca\u653e\n"
    "\u4e09\u3001\u540d\u8bcd\u89e3\u91ca\uff08\u5171 1 \u9898\uff09\n"
    "1.Auer \u5c0f\u4f53\n"
    "\u540d\u8bcd\u89e3\u91ca\u7b54\u6848\n"
    "1.Auer \u5c0f\u4f53\uff1a\u7d2b\u7ea2\u8272\u68d2\u72b6\u5305\u6db5\u4f53"
)
mixed_blocks = split_question_blocks(mixed_section_sample)
if len(mixed_blocks) != 3:
    raise SystemExit(f"answer summaries should not drop later open sections, got {len(mixed_blocks)}: {mixed_blocks!r}")
if any("\u7b54\u6848" in block and "Auer \u5c0f\u4f53\uff1a" in block for block in mixed_blocks):
    raise SystemExit(f"freeform answer section leaked into question blocks: {mixed_blocks!r}")

messy_sample = (
    "\u4e00\u3001\u5355\u9879\u9009\u62e9\u9898\uff08\u5171 2 \u9898\uff0c\u6bcf\u9898 2 \u5206\uff09\n"
    "1. \u8840\u7ea2\u86cb\u767d\u7684\u4e3b\u8981\u529f\u80fd\u662f\uff08\uff09\nA. \u8fd0\u8f93\u6c27\nB. \u514d\u75ab\nC. \u51dd\u8840\nD. \u6eb6\u8840\n"
    "2. \u4e0b\u5217\u54ea\u9879\u662f\u5916\u6e90\u6027\u51dd\u8840\uff08\uff09 A. PT B. APTT C. TT D. FDP \u5355\u9009\u9898\u7b54\u6848 1.A 2.A\n"
    "\u4e8c\u3001\u5224\u65ad\u9898\uff08\u5171 2 \u9898\uff09\n"
    "1. \u8840\u5c0f\u677f\u53ef\u53c2\u4e0e\u6b62\u8840\u3002\n2. \u8840\u6e05\u94c1\u86cb\u767d\u5347\u9ad8\u4e00\u5b9a\u662f\u7f3a\u94c1\u3002\n"
    "\u5224\u65ad\u9898\u7b54\u6848 1.\u6b63\u786e 2.\u9519\u8bef\n"
    "\u4e09\u3001\u914d\u4f0d\u9898\uff08\u5171 1 \u9898\uff09\n1. \u8bf7\u914d\u4f0d\uff1a1-\u7f3a\u94c1\u8d2b 2-\u5de8\u5e7c\u8d2b \u7b54\u6848\uff1a1-A 2-B\n"
    "\u56db\u3001\u6848\u4f8b\u5206\u6790\u9898\uff08\u5171 1 \u9898\uff09\n\u6848\u4f8b 1 \u60a3\u8005\u4e4f\u529b\u3001\u5934\u6655\u3002\u95ee\u9898\uff1a1.\u521d\u6b65\u8bca\u65ad\uff1f 2.\u4f9d\u636e\uff1f\n"
)
messy_blocks = split_question_blocks(messy_sample)
if len(messy_blocks) != 6:
    raise SystemExit(f"messy mixed paper should produce exactly 6 questions, got {len(messy_blocks)}: {messy_blocks!r}")
messy_summary = extract_answer_summary_answers(messy_sample)
if messy_summary[:4] != [{"A"}, {"A"}, {"A"}, {"B"}]:
    raise SystemExit(f"messy objective answers should preserve appearance order, got {messy_summary!r}")

stuck_question_sample = (
    "48. \u7ea2\u767d\u8840\u75c5\uff08M6\uff09\u7ec6\u80de\u5316\u5b66\u67d3\u8272\u7279\u5f81\u662f\uff08\uff09 "
    "A. PAS \u5f3a\u9633\u6027 B. POX \u5f3a\u9633\u6027 C. NSE \u9633\u6027 D. NAP \u5347\u9ad8 "
    "\u7b54\u6848\uff1aA49. \u9020\u8840\u5fae\u73af\u5883\u4e0d\u5305\u62ec\uff08\uff09 A. \u57fa\u8d28\u7ec6\u80de B. \u7ec6\u80de\u5916\u57fa\u8d28 C. \u7ec6\u80de\u56e0\u5b50 D. \u6210\u719f\u7ea2\u7ec6\u80de"
)
stuck_blocks = split_question_blocks(stuck_question_sample)
if len(stuck_blocks) != 2:
    raise SystemExit(f"stuck answer/question boundary should split into 2 questions, got {stuck_blocks!r}")

stuck_option_boundary_sample = (
    "20. \u7c7b\u767d\u8840\u75c5\u53cd\u5e94\u60a3\u8005 NAP \u79ef\u5206\u901a\u5e38\uff08\uff09 "
    "A. \u663e\u8457\u5347\u9ad8 B. \u6b63\u5e38 C. \u964d\u4f4e D. \u96f6\u5206 "
    "21. \u9aa8\u9ad3\u589e\u751f\u6781\u5ea6\u6d3b\u8dc3\uff0c\u4ee5\u4e2d\u5e7c\u7c92\u4ee5\u4e0b\u9636\u6bb5\u7ec6\u80de\u4e3a\u4e3b\uff0c\u8f83\u6613\u89c1\u55dc\u9178\u3001\u55dc\u78b1\u6027\u7c92\u7ec6\u80de\uff08\uff09 "
    "A. \u6162\u6027\u7c92\u7ec6\u80de\u767d\u8840\u75c5 B. MDS C. \u6025\u6027\u7c92\u7ec6\u80de\u767d\u8840\u75c5 D. \u7c7b\u767d\u8840\u75c5\u53cd\u5e94"
)
stuck_option_blocks = split_question_blocks(stuck_option_boundary_sample)
if len(stuck_option_blocks) != 2:
    raise SystemExit(f"next numeric question should not be swallowed into options, got {stuck_option_blocks!r}")
if option_keys(stuck_option_blocks[0]) != ["A", "B", "C", "D"] or option_keys(stuck_option_blocks[1]) != ["A", "B", "C", "D"]:
    raise SystemExit(f"stuck numeric boundary produced bad option keys: {stuck_option_blocks!r}")

inline_judgement_sample = (
    "1. \u8840\u6e05\u603b\u94c1\u7ed3\u5408\u529b\u5728\u7f3a\u94c1\u6027\u8d2b\u8840\u65f6\u5347\u9ad8\u3002\uff08\uff09 "
    "2. \u6b63\u5e38\u9aa8\u9ad3\u7c92\u7ea2\u6bd4\u503c\u53c2\u8003\u8303\u56f4\u4e3a (2~4):1\u3002\uff08\uff09 "
    "3. \u5c3f\u672c\u5468\u86cb\u767d\u4ec5\u5728\u52a0\u70ed\u81f3 100\u00b0C \u65f6\u51dd\u56fa\u3002\uff08\uff09"
)
inline_judgement_blocks = split_question_blocks(inline_judgement_sample)
if len(inline_judgement_blocks) != 3:
    raise SystemExit(f"inline judgement questions should split into 3, got {inline_judgement_blocks!r}")

freeform_answers = extract_freeform_summary_answers(mixed_section_sample)
if not freeform_answers or "Auer" not in freeform_answers[0]:
    raise SystemExit(f"freeform summary answers should be extracted, got {freeform_answers!r}")

print("question parser checks passed")
