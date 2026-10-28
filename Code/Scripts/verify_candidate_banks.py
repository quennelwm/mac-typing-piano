#!/usr/bin/env python3
"""Read-only A-001B input verification and C-001B result aggregation.

Uses the existing jsonschema installation; never rebuilds or changes candidates.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import platform
import subprocess
import sys
import wave

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
INPUT = ROOT / "Design/Audio/probes/A-001B"
OUT = ROOT / "docs/evidence/C-001B"
IMPLEMENTATION_PATHS = {"Code/Tests/PianoAudioTests/CandidateBankTests.swift",
                        "Code/Scripts/verify_candidate_banks.py"}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def contained(base, relative):
    p = PurePosixPath(relative)
    assert isinstance(relative, str) and relative and not p.is_absolute()
    assert ".." not in p.parts and ":" not in relative and "\\" not in relative, relative
    result = (base / relative).resolve(strict=True)
    assert result.is_relative_to(base.resolve()), relative
    assert result.is_file(), relative
    return result


def inventory(paths):
    return [{"path": p.relative_to(ROOT).as_posix(), "byteSize": p.stat().st_size, "sha256": sha(p)}
            for p in sorted(set(paths))]


def preflight():
    from jsonschema import Draft202012Validator
    index_path = INPUT / "trial-index.json"
    handoff = ROOT / "docs/handoffs/A-001B.md"
    schema_path = ROOT / "contracts/audio.manifest.schema.json"
    schema = json.loads(schema_path.read_text())
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(schema)
    index = json.loads(index_path.read_text())
    assert handoff.is_file()
    handoff_text = handoff.read_text()
    assert index["artifactState"] == "candidate"
    assert index["runtimeApproved"] is False and index["finalInstrumentSelected"] is False
    assert index["midiTargetRange"] == {"min": 33, "max": 96}
    assert {t["id"] for t in index["trials"]} == {"vcsl-kawai", "vcsl-steinway-b"}
    script = contained(INPUT, index["buildScript"])
    assert sha(script) == index["buildScriptSHA256"]
    trials = []
    paths = [handoff, schema_path, ROOT / "docs/tasks/C-001B.md",
             ROOT / "Code/Sources/PianoAudio/SamplerAudio.swift"]
    paths += [ROOT / path for path in IMPLEMENTATION_PATHS]
    for path in INPUT.rglob("*"):
        if path.is_file():
            assert path.resolve().is_relative_to(INPUT.resolve()), str(path)
            paths.append(path)
    for trial in index["trials"]:
        bank = contained(INPUT, trial["bankFile"])
        manifest_path = contained(INPUT, trial["manifestFile"])
        parameter_path = contained(INPUT, trial["parametersFile"])
        manifest = json.loads(manifest_path.read_text())
        parameters = json.loads(parameter_path.read_text())
        validator.validate(manifest)
        assert manifest["artifactState"] == parameters["artifactState"] == "candidate"
        assert manifest["runtimeFormat"] == "sf2"
        assert manifest["audioPackVersion"] == parameters["audioPackVersion"] == index["trialVersion"]
        for key, value in {"program": 0, "bankMSB": 121, "bankLSB": 0, "sf2Preset": 0, "sf2Bank": 0}.items():
            assert trial[key] == manifest["instrument"][key] == parameters[key] == value
        for key, value in {"sampleRate": 48000, "sampleChannels": 1, "sampleBits": 16,
                           "releaseTimecents": -1200, "releaseSecondsEncoded": 0.5}.items():
            assert trial[key] == parameters[key] == value
        assert parameters["sampleModes"] == 0 and parameters["loop"] is None
        assert contained(manifest_path.parent, manifest["instrument"]["bankFile"]) == bank
        assert contained(manifest_path.parent, manifest["instrument"]["parametersFile"]) == parameter_path
        seen = set()
        listed = []
        for file in manifest["files"]:
            path = contained(manifest_path.parent, file["path"])
            assert path not in seen
            seen.add(path)
            assert path.stat().st_size == file["byteSize"], str(path)
            assert sha(path) == file["sha256"], str(path)
            listed.append(file["path"])
        assert bank in seen and parameter_path in seen
        for key in ("processingRecipePath", "qaReportPath"):
            assert contained(manifest_path.parent, manifest[key]) in seen
        for license_record in manifest["licenseRecords"]:
            assert contained(manifest_path.parent, license_record["licenseFile"]) in seen
            assert license_record["licenseID"] == "CC0-1.0"
            assert license_record["sourceVersion"] == "c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e"
        coverage = []
        for z, p in zip(trial["zones"], parameters["zones"], strict=True):
            assert all(z[k] == p[k] for k in ("rootMIDI", "lowMIDI", "highMIDI"))
            assert 33 <= z["lowMIDI"] <= z["rootMIDI"] <= z["highMIDI"] <= 96
            coverage += list(range(z["lowMIDI"], z["highMIDI"]+1))
            source = contained(ROOT, p["sourceCandidatePath"])
            assert sha(source) == p["sourceSHA256"]
            paths.append(source)
        assert len(set(coverage)) == len(coverage)
        assert sorted(coverage) == trial["coverageMIDI"] == manifest["coverageMIDI"]
        assert sorted(set(range(33, 97)) - set(coverage)) == trial["uncoveredMIDI"]
        assert [z["rootMIDI"] for z in trial["zones"]] == trial["rootMIDI"]
        assert len(coverage) == (10 if trial["id"] == "vcsl-kawai" else 11)
        assert bank.stat().st_size == trial["byteSize"] and sha(bank) == trial["sha256"]
        assert trial["sha256"] in handoff_text and f'{trial["byteSize"]:,}' in handoff_text
        trials.append({"id": trial["id"], "bankPath": bank.relative_to(ROOT).as_posix(),
                       "sha256": sha(bank), "byteSize": bank.stat().st_size,
                       "manifestFilesVerified": listed, "coverageCount": len(coverage),
                       "coverageMIDI": trial["coverageMIDI"], "uncoveredMIDI": trial["uncoveredMIDI"],
                       "selectors": {k: trial[k] for k in ("program", "bankMSB", "bankLSB")},
                       "state": "candidate", "schemaValid": True, "selectorsAgree": True})
    assert sum(t["byteSize"] for t in trials) == index["totalBankBytes"] <= index["bankBudgetBytes"]
    result = {"status": "passed", "task": "C-001B", "inputState": "candidate",
              "jsonSchema": "Draft2020-12, existing jsonschema package", "trials": trials,
              "inputFiles": inventory(paths), "platform": platform.platform(),
              "python": sys.version, "headAtPreflight": subprocess.check_output(
                  ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "command": "python3 Code/Scripts/verify_candidate_banks.py preflight",
              "candidateWrites": False, "audioAssetDownloads": False}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "input-verification.json").write_text(json.dumps(result, indent=2, ensure_ascii=False)+"\n")
    print(json.dumps({"status": "passed", "inputFiles": len(result["inputFiles"]), "trials": trials}, ensure_ascii=False))


def unchanged():
    verified = json.loads((OUT / "input-verification.json").read_text())
    for file in verified["inputFiles"]:
        p = contained(ROOT, file["path"])
        assert p.stat().st_size == file["byteSize"] and sha(p) == file["sha256"], file["path"]
    return verified


def validate_result_binding(trial, snapshot_sha, implementation, report, wav):
    assert report["status"] == "passed" and report["failures"] == []
    assert report["inputState"] == "candidate"
    assert report["inputVerificationSHA256"] == snapshot_sha, "Stale input snapshot"
    assert report["inputSnapshotUnchangedAfterRender"] is True
    assert report["candidateID"] == trial["id"], "Candidate ID mismatch"
    assert report["bankSHA256"] == trial["sha256"], "Bank hash mismatch"
    assert report["coveredMIDI"] == trial["coverageMIDI"], "Coverage mismatch"
    assert report["uncoveredMIDI"] == trial["uncoveredMIDI"], "Uncovered list mismatch"
    assert report["loadedSelectors"] == trial["selectors"], "Selector mismatch"
    assert report["verificationImplementation"] == implementation, "Verification source version mismatch"
    reported_wav = report["representativeWAV"]
    assert reported_wav["filename"] == trial["id"] + "-offline-representative.wav"
    for field in ("filename", "sha256", "frames", "byteSize"):
        assert reported_wav[field] == wav[field], "WAV " + field + " mismatch"


def summarize():
    verified = unchanged()
    snapshot_sha = sha(OUT / "input-verification.json")
    implementation = [f for f in verified["inputFiles"] if f["path"] in IMPLEMENTATION_PATHS]
    assert {f["path"] for f in implementation} == IMPLEMENTATION_PATHS
    results = [json.loads((OUT / (t["id"]+"-results.json")).read_text()) for t in verified["trials"]]
    wavs = sorted(OUT.glob("*.wav"))
    assert len(wavs) <= 2
    assert sum(p.stat().st_size for p in wavs) <= 20*1024*1024
    artifacts = []
    for p in wavs:
        with wave.open(str(p), "rb") as f:
            assert f.getnchannels() == 1 and f.getframerate() == 48000 and f.getsampwidth() == 2
            artifacts.append({"path": p.relative_to(ROOT).as_posix(), "filename": p.name, "sha256": sha(p),
                              "byteSize": p.stat().st_size, "frames": f.getnframes(),
                              "seconds": f.getnframes()/48000, "format": "48kHz mono PCM16 WAV"})
    assert {p.name for p in wavs} == {t["id"]+"-offline-representative.wav" for t in verified["trials"]}
    for trial, report in zip(verified["trials"], results, strict=True):
        wav = next(a for a in artifacts if a["filename"] == trial["id"]+"-offline-representative.wav")
        validate_result_binding(trial, snapshot_sha, implementation, report, wav)
    calibration = json.loads((OUT / "pitch-estimator-calibration.json").read_text())
    assert calibration["status"] == "passed" and calibration["inputVerificationSHA256"] == snapshot_sha
    test_source = next(f for f in implementation if f["path"].endswith("CandidateBankTests.swift"))
    assert calibration["testSourceSHA256"] == test_source["sha256"]
    result = {"task": "C-001B", "status": "passed" if all(r["status"] == "passed" for r in results) else "failed",
              "inputVerificationSHA256": snapshot_sha,
              "inputFilesUnchanged": True, "inputStateRemains": "candidate", "banks": results,
              "verificationImplementation": implementation,
              "pitchEstimatorCalibration": calibration,
              "wavArtifacts": artifacts, "wavTotalBytes": sum(p.stat().st_size for p in wavs),
              "hardwarePlayback": False, "actualInputCaptured": False,
              "limitations": ["Partial 10/11 pitch coverage only", "Pitch estimator uses expected-period search and is not an absolute tuning certification",
                              "Mixed peaks do not establish internal voice counts", "No listening, hardware latency or real device switch tests"]}
    (OUT / "results.json").write_text(json.dumps(result, indent=2, ensure_ascii=False)+"\n")
    print(json.dumps({"status": result["status"], "inputFilesUnchanged": True, "wavTotalBytes": result["wavTotalBytes"]}))
    if result["status"] != "passed": sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["preflight", "unchanged", "summarize"])
    action = parser.parse_args().action
    if action == "preflight": preflight()
    elif action == "summarize": summarize()
    else:
        value = unchanged()
        print(json.dumps({"inputFilesUnchanged": True, "count": len(value["inputFiles"])}))
