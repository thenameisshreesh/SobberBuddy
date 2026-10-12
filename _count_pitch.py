import re
import pathlib

t = pathlib.Path(r"m:\me\Projects\SoberBuddyF\build_fintech_pitch.py").read_text(encoding="utf-8")
parts = re.findall(
    r'story\.append\(P\(\s*"(.*?)"\s*(?:,\s*"([^"]+)")?\s*\)\)',
    t,
    re.S,
)
speech = []
for text, style in parts:
    if style in ("h1", "h2", "src", "footer_note", "body_first"):
        continue
    speech.append(text)
for i, p in enumerate(speech, 1):
    n = len(re.findall(r"[A-Za-z0-9'\u2019]+", p))
    print(f"{i:02d} {n:4d} {p[:100]}")
text = " ".join(speech)
words = re.findall(r"[A-Za-z0-9'\u2019]+", text)
print("---")
print("paragraphs", len(speech))
print("words", len(words))
print("min at 145", round(len(words) / 145, 2))
print("min at 150", round(len(words) / 150, 2))
