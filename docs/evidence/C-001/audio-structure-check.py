#!/usr/bin/env python3
"""Fixture-only SF2 structure/reproducibility regression, Python stdlib."""
from pathlib import Path
import hashlib
import importlib.util
import json
import struct
import sys

sys.dont_write_bytecode = True
root = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("placeholder", root / "Code/Scripts/generate_placeholder.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
bank, timecents = module.build_bank()
assert bank == module.build_bank()[0] == (root / "Code/Assets/placeholder-original.sf2").read_bytes()
assert bank[:4] == b"RIFF" and bank[8:12] == b"sfbk"
assert struct.unpack_from("<I", bank, 4)[0] + 8 == len(bank)


def chunks(start, end):
    found = []
    while start < end:
        name = bank[start:start+4].decode("ascii")
        size = struct.unpack_from("<I", bank, start+4)[0]
        assert size % 2 == 0, f"SF2 {name} body size must include zero terminators to reach even length: {size}"
        assert start + 8 + size <= end
        found.append((name, size))
        if name == "LIST":
            found.extend(chunks(start+12, start+8+size))
        start += 8 + size
    assert start == end
    return found


records = chunks(12, len(bank))
assert set(range(33, 97)) == {v for low, high in module.RANGES for v in range(low, high+1)}
result = {"python": sys.version, "same_runtime_byte_reproducible": True,
          "sha256": hashlib.sha256(bank).hexdigest(), "byte_size": len(bank),
          "sf2_release_timecents": timecents, "sf2_release_seconds": 2 ** (timecents / 1200),
          "chunks": records, "hardware_playback": False, "audio_asset_downloads": False}
print(json.dumps(result, indent=2))
