import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / 'Code/Scripts/release_sign.py'
BASE = Path.home() / 'Library/Caches/local.typingpiano.trial'
OLD = BASE / 'github-release-0.2.6/Mac-Typing-Piano-0.2.6-arm64/打字钢琴试用.app'
NEW = BASE / 'github-release-0.2.7/Mac-Typing-Piano-0.2.7-arm64/打字钢琴试用.app'
ADHOC = BASE / 'candidate-0.2.7/打字钢琴试用.app'


class ReleaseSigningTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with tempfile.TemporaryDirectory(prefix='typing-piano-cert-') as tmp:
            prefix = str(Path(tmp) / 'cert')
            subprocess.run(['/usr/bin/codesign', '-d', '--extract-certificates=' + prefix, str(OLD)], check=True, capture_output=True)
            cls.identity = hashlib.sha1(Path(prefix + '0').read_bytes()).hexdigest().upper()

    def invoke(self, app=NEW, previous=OLD, identity=True, *extra):
        env = os.environ.copy()
        env.pop('TYPING_PIANO_RELEASE_IDENTITY', None)
        args = ['python3', str(SCRIPT), '--app', str(app), '--previous', str(previous)]
        if identity: args += ['--identity', self.identity if identity is True else identity]
        return subprocess.run(args + list(extra), env=env, capture_output=True, text=True)

    def verify(self, app=NEW, previous=OLD, identity=True):
        return self.invoke(app, previous, identity, '--verify-only')

    def reject(self, result, reason):
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(reason, result.stderr)

    def copy(self, app, tmp):
        target = Path(tmp) / 'input.app'
        subprocess.run(['/usr/bin/ditto', '--norsrc', '--noextattr', '--noacl', str(app), str(target)], check=True)
        return target

    def test_01_previous_public_release_verifies(self):
        result = self.verify(OLD)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_02_current_public_release_verifies(self):
        result = self.verify()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)['designatedRequirementMatches'])

    def test_03_adhoc_candidate_rejected(self):
        self.reject(self.verify(ADHOC), 'ad-hoc')

    def test_04_identity_required(self):
        self.reject(self.verify(identity=False), 'identity')

    def test_05_adhoc_identity_not_allowed(self):
        self.reject(self.verify(identity='-'), 'identity')

    def test_06_wrong_identity_rejected(self):
        self.reject(self.verify(identity='0' * 40), 'identity')

    def test_07_adhoc_reference_rejected(self):
        self.reject(self.verify(previous=ADHOC), 'ad-hoc')

    def test_08_wrong_bundle_id_rejected(self):
        with tempfile.TemporaryDirectory(prefix='typing-piano-release-test-') as tmp:
            app = self.copy(NEW, tmp)
            path = app / 'Contents/Info.plist'
            data = plistlib.loads(path.read_bytes()); data['CFBundleIdentifier'] = 'invalid.test'
            path.write_bytes(plistlib.dumps(data))
            self.reject(self.verify(app), 'Bundle ID')

    def test_09_broken_resource_seal_rejected(self):
        with tempfile.TemporaryDirectory(prefix='typing-piano-release-test-') as tmp:
            app = self.copy(NEW, tmp)
            (app / 'Contents/Resources/keymap.ansi64.playable.v0.2.json').write_text('{}')
            self.reject(self.verify(app), 'strict signature')

    def test_10_valid_but_different_requirement_rejected(self):
        with tempfile.TemporaryDirectory(prefix='typing-piano-release-test-') as tmp:
            app = self.copy(NEW, tmp)
            requirement = 'designated => identifier "local.typingpiano.trial" and info[CFBundleVersion] = "10"'
            subprocess.run(['/usr/bin/codesign', '--force', '--sign', self.identity, '-r', '=' + requirement, str(app)], check=True, capture_output=True)
            self.reject(self.verify(app), 'designated requirement')

    def test_11_sign_new_copy_and_verify(self):
        with tempfile.TemporaryDirectory(prefix='typing-piano-release-test-') as tmp:
            out = Path(tmp) / 'release.app'
            result = self.invoke(ADHOC, OLD, True, '--output', str(out))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.verify(out).returncode, 0)
            self.assertEqual((out / 'Contents/Resources/keymap.ansi64.playable.v0.2.json').read_bytes(), (ADHOC / 'Contents/Resources/keymap.ansi64.playable.v0.2.json').read_bytes())

    def test_12_existing_output_not_overwritten(self):
        with tempfile.TemporaryDirectory(prefix='typing-piano-release-test-') as tmp:
            out = Path(tmp) / 'sentinel'; out.write_text('keep')
            self.reject(self.invoke(ADHOC, OLD, True, '--output', str(out)), 'output')
            self.assertEqual(out.read_text(), 'keep')

    def test_13_verify_only_cannot_request_output(self):
        self.reject(self.invoke(NEW, OLD, True, '--verify-only', '--output', '/unused'), 'output')


if __name__ == '__main__': unittest.main(verbosity=2)
