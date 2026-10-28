#!/usr/bin/env python3
"""In-memory regression cases: never mutate candidates or current evidence."""
import copy
import importlib.util
from pathlib import Path
import sys
import unittest

sys.dont_write_bytecode = True
root = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location("candidate_verifier", root / "Code/Scripts/verify_candidate_banks.py")
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class EvidenceBindingTests(unittest.TestCase):
    def setUp(self):
        self.trial = {"id": "vcsl-kawai", "sha256": "b" * 64,
                      "coverageMIDI": [33, 34], "uncoveredMIDI": list(range(35, 97)),
                      "selectors": {"program": 0, "bankMSB": 121, "bankLSB": 0}}
        self.implementation = [{"path": "Code/Tests/PianoAudioTests/CandidateBankTests.swift", "sha256": "c" * 64, "byteSize": 100},
                               {"path": "Code/Scripts/verify_candidate_banks.py", "sha256": "d" * 64, "byteSize": 200}]
        self.wav = {"filename": "vcsl-kawai-offline-representative.wav", "sha256": "e" * 64,
                    "frames": 48_000, "byteSize": 96_044}
        self.report = {"status": "passed", "failures": [], "inputState": "candidate",
                       "candidateID": self.trial["id"], "bankSHA256": self.trial["sha256"],
                       "coveredMIDI": self.trial["coverageMIDI"], "uncoveredMIDI": self.trial["uncoveredMIDI"],
                       "loadedSelectors": self.trial["selectors"], "inputVerificationSHA256": "a" * 64,
                       "verificationImplementation": self.implementation,
                       "inputSnapshotUnchangedAfterRender": True, "representativeWAV": self.wav}

    def validate(self, report):
        verifier.validate_result_binding(self.trial, "a" * 64, self.implementation, report, self.wav)

    def testValidBoundReportAccepted(self):
        self.validate(copy.deepcopy(self.report))

    def testStaleSnapshotRejected(self):
        report = copy.deepcopy(self.report)
        report["inputVerificationSHA256"] = "f" * 64
        with self.assertRaises(AssertionError): self.validate(report)

    def testWrongCandidateRejected(self):
        report = copy.deepcopy(self.report)
        report["candidateID"] = "vcsl-steinway-b"
        with self.assertRaises(AssertionError): self.validate(report)

    def testWrongBankRejected(self):
        report = copy.deepcopy(self.report)
        report["bankSHA256"] = "f" * 64
        with self.assertRaises(AssertionError): self.validate(report)

    def testWrongCoverageRejected(self):
        report = copy.deepcopy(self.report)
        report["coveredMIDI"] = [33]
        with self.assertRaises(AssertionError): self.validate(report)

    def testWrongUncoveredListRejected(self):
        report = copy.deepcopy(self.report)
        report["uncoveredMIDI"] = []
        with self.assertRaises(AssertionError): self.validate(report)

    def testWrongSelectorRejected(self):
        report = copy.deepcopy(self.report)
        report["loadedSelectors"]["program"] = 1
        with self.assertRaises(AssertionError): self.validate(report)

    def testWrongImplementationRejected(self):
        report = copy.deepcopy(self.report)
        report["verificationImplementation"][0]["sha256"] = "f" * 64
        with self.assertRaises(AssertionError): self.validate(report)

    def testWrongWAVHashRejected(self):
        report = copy.deepcopy(self.report)
        report["representativeWAV"]["sha256"] = "f" * 64
        with self.assertRaises(AssertionError): self.validate(report)

    def testWrongWAVFramesRejected(self):
        report = copy.deepcopy(self.report)
        report["representativeWAV"]["frames"] = 96_000
        with self.assertRaises(AssertionError): self.validate(report)

    def testWrongWAVNameRejected(self):
        report = copy.deepcopy(self.report)
        report["representativeWAV"]["filename"] = "old.wav"
        with self.assertRaises(AssertionError): self.validate(report)

    def testWrongWAVSizeRejected(self):
        report = copy.deepcopy(self.report)
        report["representativeWAV"]["byteSize"] = 96_000
        with self.assertRaises(AssertionError): self.validate(report)


if __name__ == "__main__": unittest.main(verbosity=2)
