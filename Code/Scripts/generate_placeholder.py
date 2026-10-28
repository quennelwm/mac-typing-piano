#!/usr/bin/env python3
"""Generate an original, unlooped SF2 probe; no downloads or sampled recordings.

Run from anywhere: python3 Code/Scripts/generate_placeholder.py
The same generator/runtime produces byte-identical files. This is an engine
fixture, not an accepted piano instrument. Python standard library only.
"""

import array
import hashlib
import json
import math
from pathlib import Path
import struct
import sys


ASSET_DIR = Path(__file__).resolve().parent.parent / "Assets"
RATE = 22050
DURATION = 2.0
ROOTS = (36, 48, 60, 72, 84, 96)
RANGES = ((33, 41), (42, 53), (54, 65), (66, 77), (78, 89), (90, 96))
RELEASE_SECONDS = 0.450


def chunk(name, body):
    assert len(name) == 4
    # SF2 INFO strings require one or two null terminators INSIDE their even
    # declared size. Ordinary RIFF external padding alone is insufficient.
    body += b"\0" if len(body) % 2 else b""
    return name.encode("ascii") + struct.pack("<I", len(body)) + body


def list_chunk(kind, body):
    return chunk("LIST", kind.encode("ascii") + body)


def name20(value):
    encoded = value.encode("ascii")
    assert len(encoded) < 20
    return encoded.ljust(20, b"\0")


def gen(operator, value):
    return struct.pack("<HH", operator, value & 0xFFFF)


def build_bank():
    pcm = array.array("h")
    headers = []
    for root in ROOTS:
        start = len(pcm)
        frequency = 440.0 * 2.0 ** ((root - 69) / 12.0)
        count = int(RATE * DURATION)
        for frame in range(count):
            t = frame / RATE
            phase = 2.0 * math.pi * frequency * t
            # Quiet harmonic test tone. The 3 ms attack and 20 ms ending fade
            # are in the PCM; note-off release is separately encoded in SF2.
            envelope = min(1.0, t / 0.003) * math.exp(-2.7 * t)
            envelope *= min(1.0, (count - 1 - frame) / (RATE * 0.020))
            waveform = (math.sin(phase) + 0.22 * math.sin(2 * phase)
                        + 0.08 * math.sin(3 * phase)) / 1.30
            pcm.append(round(0.35 * 32767 * envelope * waveform))
        end = len(pcm)
        # SF2 requires at least 46 zero-valued guard sample points.
        pcm.extend([0] * 46)
        headers.append(struct.pack("<20sIIIIIBbHH", name20(f"Original m{root:03}"),
                                   start, end, start, end, RATE, root, 0, 0, 1))
    headers.append(struct.pack("<20sIIIIIBbHH", name20("EOS"),
                               len(pcm), len(pcm), len(pcm), len(pcm), RATE, 0, 0, 0, 1))
    if sys.byteorder != "little":
        pcm.byteswap()

    # Preset 0 / bank 0, melodic bank selected by Apple MSB 121 / LSB 0.
    phdr = struct.pack("<20sHHHIII", name20("Original Probe"), 0, 0, 0, 0, 0, 0)
    phdr += struct.pack("<20sHHHIII", name20("EOP"), 0, 0, 1, 0, 0, 0)
    pbag = struct.pack("<HHHH", 0, 0, 1, 0)
    pgen = gen(41, 0) + gen(0, 0)  # instrument index, terminal
    inst = struct.pack("<20sH", name20("Original Harmonics"), 0)
    inst += struct.pack("<20sH", name20("EOI"), len(ROOTS))
    ibag = bytearray()
    igen = bytearray()
    release_timecents = round(1200 * math.log2(RELEASE_SECONDS))
    for index, (root, (low, high)) in enumerate(zip(ROOTS, RANGES)):
        ibag.extend(struct.pack("<HH", len(igen) // 4, 0))
        # keyRange must precede other generators, sampleID must be last.
        igen.extend(gen(43, low | high << 8))
        igen.extend(gen(34, -12000))  # attackVolEnv, ~1 ms
        igen.extend(gen(38, release_timecents))
        igen.extend(gen(54, 0))  # sampleModes = no loop
        igen.extend(gen(58, root))  # overridingRootKey
        igen.extend(gen(53, index))
    ibag.extend(struct.pack("<HH", len(igen) // 4, 0))
    igen.extend(gen(0, 0))
    info = chunk("ifil", struct.pack("<HH", 2, 1))
    info += chunk("isng", b"EMU8000\0")
    info += chunk("INAM", b"Typing Piano Original Synthetic Probe\0")
    info += chunk("IENG", b"Typing Piano C-001 code task\0")
    info += chunk("ICOP", b"CC0-1.0; original generated tones; not recorded samples\0")
    info += chunk("ICMT", b"TEST PLACEHOLDER ONLY. No loops. Release target 450ms.\0")
    pdta = b"".join((chunk("phdr", phdr), chunk("pbag", pbag), chunk("pmod", bytes(10)),
                     chunk("pgen", pgen), chunk("inst", inst), chunk("ibag", ibag),
                     chunk("imod", bytes(10)), chunk("igen", igen),
                     chunk("shdr", b"".join(headers))))
    bank = chunk("RIFF", b"sfbk" + list_chunk("INFO", info)
                 + list_chunk("sdta", chunk("smpl", pcm.tobytes())) + list_chunk("pdta", pdta))
    return bank, release_timecents


def main():
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    bank, release_timecents = build_bank()
    bank_name = "placeholder-original.sf2"
    (ASSET_DIR / bank_name).write_bytes(bank)
    manifest = {
        "artifactState": "probe-placeholder-not-approved", "format": "SF2 2.1",
        "filename": bank_name, "sha256": hashlib.sha256(bank).hexdigest(), "byteSize": len(bank),
        "source": "Original analytic synthesis by Code/Scripts/generate_placeholder.py; no external audio",
        "licenseID": "CC0-1.0", "licenseFile": "PLACEHOLDER-LICENSE.txt",
        "noteRange": {"lowMIDI": 33, "highMIDI": 96},
        "instrument": {"program": 0, "bankMSB": 121, "bankLSB": 0},
        "sampleRate": RATE, "sampleBits": 16, "sampleChannels": 1,
        "sampleSeconds": DURATION, "loop": False,
        "releaseTimecents": release_timecents,
        "releaseSecondsEncoded": 2 ** (release_timecents / 1200),
        "zones": [{"rootMIDI": root, "lowMIDI": low, "highMIDI": high}
                  for root, (low, high) in zip(ROOTS, RANGES)],
        "qa": "See docs/evidence/C-001/audio-format-note.md and audio test logs; no listening or hardware acceptance",
    }
    (ASSET_DIR / "placeholder.manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"path": str(ASSET_DIR / bank_name), "byteSize": len(bank),
                      "sha256": manifest["sha256"]}, sort_keys=True))


if __name__ == "__main__":
    main()
