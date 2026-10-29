#!/usr/bin/env python3
"""Import only the approved note assignment; preserve existing physical input metadata."""
import copy
import json
from pathlib import Path
import jsonschema

root = Path(__file__).resolve().parents[2]
original = json.loads((root / 'contracts/keymap.ansi64.v0.1.json').read_text())
incoming = json.loads((root / 'docs/inputs/playable-v0.2/Mac_Typing_Piano_Playable_Keymap_v0.2_DRAFT.json').read_text())
ids = {f'Key{x}': f'key{x}' for x in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'}
ids.update({f'Digit{x}': f'digit{x}' for x in '0123456789'})
ids.update({'Backquote':'grave','Minus':'minus','Equal':'equal','Backspace':'delete',
 'Tab':'tab','BracketLeft':'bracketLeft','BracketRight':'bracketRight','Backslash':'backslash',
 'CapsLock':'capsLock','Semicolon':'semicolon','Quote':'quote','Return':'return',
 'ShiftLeft':'shiftLeft','ShiftRight':'shiftRight','Comma':'comma','Period':'period','Slash':'slash',
 'Fn':'fn','ControlLeft':'controlLeft','AltLeft':'optionLeft','AltRight':'optionRight',
 'MetaLeft':'commandLeft','MetaRight':'commandRight','Space':'space',
 'ArrowLeft':'arrowLeft','ArrowDown':'arrowDown','ArrowUp':'arrowUp','ArrowRight':'arrowRight'})
assert len(ids) == 64 and len(set(ids.values())) == 64
assert set(ids) == {k['physicalKeyID'] for k in incoming['mapping']}
assert len(incoming['mapping']) == 64
notes = {ids[k['physicalKeyID']]:k for k in incoming['mapping']}
assert set(notes) == {k['physicalKeyID'] for k in original['keys']}
assert {k['midi'] for k in notes.values()} == set(range(33,97))
result = copy.deepcopy(original)
result['mappingVersion'] = 'ansi64-playable.0.2'
result['statusNote'] = 'CR-006/CR-007 approved default note assignment; physical capture remains subject to hardware validation. Historical classic mapping is not a runtime option.'
for key in result['keys']:
    item = notes[key['physicalKeyID']]
    key['midiNote'] = item['midi']; key['noteName'] = item['note']; key['pianoKeyColor'] = item['pianoKeyType']
jsonschema.validate(result, json.loads((root / 'contracts/keymap.schema.json').read_text()))
path = root / 'contracts/keymap.ansi64.playable.v0.2.json'
path.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
print(f'Validated 64 explicit ID translations; wrote {path.name}')
