from pathlib import Path
import sys

import pdfplumber


def extract(pdf_path: Path, out_path: Path) -> None:
    chunks = []
    with pdfplumber.open(str(pdf_path)) as pdf:
        for index, page in enumerate(pdf.pages, start=1):
            text = page.extract_text() or ""
            chunks.append(f"\n--- page {index} ---\n{text}")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(chunks).strip(), encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: python tools/extract_pdf_text.py input.pdf output.txt")
    extract(Path(sys.argv[1]), Path(sys.argv[2]))
