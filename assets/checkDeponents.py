import json

INPUT_FILE = "greek_vocabulary.json"
OUTPUT_FILE = "greek_vocabulary_updated.json"

with open(INPUT_FILE, "r", encoding="utf-8") as f:
    vocabulary = json.load(f)

count = 0

for entry in vocabulary:
    if (
        entry.get("type") == "verb"
        and isinstance(entry.get("lemma"), str)
        and entry["lemma"].endswith("μαι")
    ):
        entry["deponent"] = True
        count += 1

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(
        vocabulary,
        f,
        ensure_ascii=False,
        indent=2
    )

print(f"{count} Verben als deponent markiert.")