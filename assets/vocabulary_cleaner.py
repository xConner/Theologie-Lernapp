import json
from pathlib import Path

# -----------------------------
# Datei anpassen
# -----------------------------
INPUT_FILE = "greek_vocabulary.json"
OUTPUT_FILE = "greek_vocabulary_clean.json"

# -----------------------------
# JSON laden
# -----------------------------
with open(INPUT_FILE, "r", encoding="utf-8") as f:
    data = json.load(f)

# -----------------------------
# Doppelte Lemmata entfernen
# (erster Eintrag bleibt erhalten)
# -----------------------------
seen = set()
cleaned = []
removed = []

for entry in data:
    lemma = entry.get("lemma", "").strip()

    if lemma in seen:
        removed.append((entry.get("id"), lemma))
        continue

    seen.add(lemma)
    cleaned.append(entry)

# -----------------------------
# IDs neu vergeben
# -----------------------------
for new_id, entry in enumerate(cleaned, start=1):
    entry["id"] = new_id

# -----------------------------
# Speichern
# -----------------------------
with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    json.dump(cleaned, f, ensure_ascii=False, indent=2)

# -----------------------------
# Ausgabe
# -----------------------------
print(f"Originale Einträge : {len(data)}")
print(f"Entfernte Duplikate: {len(removed)}")
print(f"Neue Einträge      : {len(cleaned)}")

if removed:
    print("\nEntfernte Duplikate:")
    for old_id, lemma in removed:
        print(f"  ID {old_id}: {lemma}")

print(f"\nBereinigte Datei gespeichert als: {OUTPUT_FILE}")