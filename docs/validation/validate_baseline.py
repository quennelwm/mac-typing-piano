"""Read-only checks of the v1.0 contracts; no macOS input or audio claims."""
from collections import Counter
import json
from pathlib import Path
from jsonschema import Draft202012Validator

root = Path(__file__).resolve().parents[2]
contracts = root / "contracts"
for path in contracts.glob("*.json"):
    json.loads(path.read_text())
for schema_name, value_name in (
    ("keymap.schema.json", "keymap.ansi64.v0.1.json"),
    ("audio.manifest.schema.json", "audio.manifest.template.json"),
    ("ui.theme.schema.json", "ui.theme.example.json"),
):
    schema = json.loads((contracts / schema_name).read_text())
    Draft202012Validator.check_schema(schema)
    Draft202012Validator(schema).validate(json.loads((contracts / value_name).read_text()))

mapping = json.loads((contracts / "keymap.ansi64.v0.1.json").read_text())
keys = mapping["keys"]
expected_rows = [
    ["grave"] + ["digit" + x for x in "1234567890"] + ["minus", "equal", "delete"],
    ["tab"] + ["key" + x for x in "QWERTYUIOP"] + ["bracketLeft", "bracketRight", "backslash"],
    ["capsLock"] + ["key" + x for x in "ASDFGHJKL"] + ["semicolon", "quote", "return"],
    ["shiftLeft"] + ["key" + x for x in "ZXCVBNM"] + ["comma", "period", "slash", "shiftRight"],
    ["fn", "controlLeft", "optionLeft", "commandLeft", "space", "commandRight", "optionRight", "arrowLeft", "arrowDown", "arrowUp", "arrowRight"],
]
assert len(keys) == 64
assert len({k["physicalKeyID"] for k in keys}) == 64
assert {k["midiNote"] for k in keys} == set(range(33, 97))
for row, expected in enumerate(expected_rows, 1):
    actual = sorted((k for k in keys if k["physicalRow"] == row), key=lambda k: k["positionInRow"])
    assert [k["physicalKeyID"] for k in actual] == expected
    assert [k["positionInRow"] for k in actual] == list(range(1, len(expected) + 1))
names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
for key in keys:
    midi = key["midiNote"]
    assert key["pianoKeyColor"] == ("black" if midi % 12 in {1, 3, 6, 8, 10} else "white")
    assert key["noteName"] == names[midi % 12] + str(midi // 12 - 1)
    assert key["displayLabel"].strip() and key["labelParts"]["main"].strip() and key["accessibleName"].strip()
    assert key["captureStatus"] == "unverified"
lookup = {k["physicalKeyID"]: k for k in keys}
for modifier in ("shift", "command", "option"):
    assert lookup[modifier + "Left"]["labelParts"]["side"] == "L"
    assert lookup[modifier + "Right"]["labelParts"]["side"] == "R"
assert Counter(k["pianoKeyColor"] for k in keys) == {"white": 38, "black": 26}
print(json.dumps({
    "date": "2026-10-28", "scope": "Independent static recheck of supplied contracts only",
    "schema_validation": "pass", "physical_keys": 64, "row_counts": [len(r) for r in expected_rows],
    "unique_midi": 64, "range": [33, 96], "white": 38, "black": 26,
    "labels_and_sides": "pass", "all_capture_statuses": "unverified",
    "mac_input_tested": False, "audio_tested": False, "ui_render_tested": False,
}, ensure_ascii=False, indent=2))
