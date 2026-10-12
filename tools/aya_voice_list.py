"""Writes docs/aya_voice.md: every phrase Aya's games say, with the file name a recording needs.
Run after changing ToddlerVoice.PHRASES: python3 tools/aya_voice_list.py
"""
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "scripts", "toddler", "toddler_voice.gd")
OUT = os.path.join(ROOT, "docs", "aya_voice.md")

GROUPS = [  # key prefix -> where the phrase is heard
    ("c_", "الألوان (التلوين، الفرز، البالونات)"),
    ("s_", "الأشكال"),
    ("a_", "الحيوانات (اسم وصوت)"),
    ("p_", "البزل (اسم الصورة)"),
    ("w_", "مسابقة العيلة: وين ...؟"),
    ("wc_", "مسابقة العيلة: وين الطابة ...؟"),
    ("", "عامة (الترحيب، التشجيع، بداية كل لعبة)"),
]


def phrases():
    text = open(SRC, encoding="utf-8").read()
    block = text.split("const PHRASES := {", 1)[1].split("\n}", 1)[0]
    return re.findall(r'^\s*"([a-z0-9_]+)":\s*"([^"]*)"', block, re.M)


def group_of(key):
    # The longest matching prefix wins ("wc_" before "w_"); keys without a known prefix are general.
    best = ""
    for prefix, _ in GROUPS:
        if prefix and key.startswith(prefix) and len(prefix) > len(best):
            best = prefix
    return best


def main():
    items = phrases()
    lines = [
        "# أصوات ألعاب آية",
        "",
        "كل جملة بتقولها ألعاب آية إلها اسم ملف. إذا لقت اللعبة ملف بهالاسم بتشغّله، وإذا ما لقت بتقرأ الجملة بصوت التلفون.",
        "",
        "كل الجمل هلق إلها ملفات معمولة على ElevenLabs (صوت xcVbjGhhLIoKi3va6mAe). إذا جملة نطقها مش مزبوط، سجّلها بصوتك وارفعها بنفس الاسم مكان القديمة.",
        "",
        "طريقة الإضافة:",
        "1. سجّل الجملة بصوتك (أي تطبيق تسجيل على التلفون).",
        "2. سمّي الملف باسم المفتاح من الجدول، مثلاً `hello.mp3`. الأنواع المقبولة: `.mp3` و`.ogg` و`.wav`.",
        "3. حطّ الملف بمجلد `assets/toddler/voice/` بالريبو (على GitHub: Add file ثم Upload files).",
        "4. بعد ما يخلص بناء التطبيق، نزّل الـAPK الجديد.",
        "",
        "نصائح: سجّل بمكان هادي، جملة وحدة بكل ملف، وخلّي الملف قصير (ثانية أو ثانيتين) بدون سكوت طويل بالأول.",
        "",
        "هالملف بينعمل تلقائياً من `scripts/toddler/toddler_voice.gd` بالأمر `python3 tools/aya_voice_list.py`.",
        "",
    ]
    for prefix, title in GROUPS:
        rows = [(k, v) for k, v in items if group_of(k) == prefix]
        if not rows:
            continue
        lines += [f"## {title}", "", "| اسم الملف | الجملة |", "|---|---|"]
        lines += [f"| `{k}.mp3` | {v} |" for k, v in rows]
        lines.append("")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("wrote", OUT, len(items), "phrases")


if __name__ == "__main__":
    main()
