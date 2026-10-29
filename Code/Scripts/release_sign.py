#!/usr/bin/env python3
"""Verify a release, or sign a new copy using an explicitly pinned certificate.

Never builds, installs, starts an App, changes TCC, or rewrites an input bundle.
Only Python's standard library and macOS system tools are required.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile

BUNDLE_ID = "local.typingpiano.trial"


class ReleaseError(Exception):
    pass


def command(args, failure):
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode:
        # Do not print keychain identities, certificate subjects or raw tool diagnostics.
        raise ReleaseError(failure)
    return result.stdout + result.stderr


def bundle(app):
    if not app.is_dir() or app.suffix != ".app":
        raise ReleaseError("app must be an existing .app directory")
    try:
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    except (OSError, ValueError):
        raise ReleaseError("cannot read bundle Info.plist") from None
    if info.get("CFBundleIdentifier") != BUNDLE_ID:
        raise ReleaseError("Bundle ID must be " + BUNDLE_ID)
    return info


def inspect(app, identity):
    bundle(app)
    detail = command(["/usr/bin/codesign", "-d", "--verbose=4", str(app)], "signature metadata unavailable")
    if "Signature=adhoc" in detail or re.search(r"flags=.*\badhoc\b", detail):
        raise ReleaseError("ad-hoc signatures are not release identities")
    if not re.search(r"^Identifier=" + re.escape(BUNDLE_ID) + r"$", detail, re.M):
        raise ReleaseError("signed Bundle ID mismatch")
    command(["/usr/bin/codesign", "--verify", "--deep", "--strict", "--all-architectures", str(app)],
            "strict signature verification failed")
    with tempfile.TemporaryDirectory(prefix="typing-piano-release-cert-") as tmp:
        prefix = str(Path(tmp) / "certificate")
        command(["/usr/bin/codesign", "-d", "--extract-certificates=" + prefix, str(app)],
                "certificate-backed identity required")
        leaf = Path(prefix + "0")
        if not leaf.is_file() or hashlib.sha1(leaf.read_bytes()).hexdigest().upper() != identity:
            raise ReleaseError("signing identity does not match explicit certificate SHA-1")
    text = command(["/usr/bin/codesign", "-d", "-r-", str(app)], "designated requirement unavailable")
    requirements = [line.strip() for line in text.splitlines() if line.startswith("designated => ")]
    if len(requirements) != 1:
        raise ReleaseError("expected exactly one designated requirement")
    return requirements[0]


def verify(app, previous_requirement, identity):
    actual = inspect(app, identity)
    if actual != previous_requirement:
        raise ReleaseError("designated requirement differs from previous public release")
    return actual


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", required=True, type=Path, help="input App; always read-only")
    parser.add_argument("--previous", required=True, type=Path, help="trusted previous public App")
    parser.add_argument("--identity", default=os.environ.get("TYPING_PIANO_RELEASE_IDENTITY"),
                        help="exact 40-hex certificate SHA-1; or TYPING_PIANO_RELEASE_IDENTITY")
    parser.add_argument("--verify-only", action="store_true", help="no private key needed; writes only temporary certificate files")
    parser.add_argument("--output", type=Path, help="new .app destination; required when signing")
    args = parser.parse_args()
    if not args.identity or not re.fullmatch(r"[0-9A-Fa-f]{40}", args.identity):
        raise ReleaseError("explicit release identity must be a 40-hex certificate SHA-1; no ad-hoc fallback")
    identity = args.identity.upper()
    app, previous = args.app.resolve(), args.previous.resolve()
    if args.verify_only and args.output is not None:
        raise ReleaseError("verify-only cannot specify output")
    if not args.verify_only and args.output is None:
        raise ReleaseError("signing requires a new --output App path")
    requirement = inspect(previous, identity)
    bundle(app)
    if args.verify_only:
        verify(app, requirement, identity)
        destination = app
    else:
        raw_output = args.output.expanduser()
        # Refuse symlinks, existing paths and writing anywhere inside either input.
        if raw_output.exists() or raw_output.is_symlink():
            raise ReleaseError("output already exists; refusing to overwrite")
        output = raw_output.resolve()
        if output.suffix != ".app" or not output.parent.is_dir():
            raise ReleaseError("output must be a new .app in an existing directory")
        if any(parent == source for source in (app, previous) for parent in (output, *output.parents)):
            raise ReleaseError("output must not be inside either input App")
        available = command(["/usr/bin/security", "find-identity", "-v", "-p", "codesigning"],
                            "cannot check available signing identities")
        identities = re.findall(r'^\s*\d+\)\s+([A-Fa-f0-9]{40})\s', available, re.M)
        if identity not in [value.upper() for value in identities]:
            raise ReleaseError("requested signing identity is unavailable; no fallback")
        with tempfile.TemporaryDirectory(prefix=".typing-piano-release-", dir=output.parent) as tmp:
            staged = Path(tmp) / "release.app"
            command(["/usr/bin/ditto", "--norsrc", "--noextattr", "--noacl", str(app), str(staged)],
                    "cannot copy input App")
            if any(path.is_symlink() and not path.resolve().is_relative_to(staged)
                   for path in staged.rglob("*")):
                raise ReleaseError("input contains an external symlink; refusing to sign outside the copy")
            command(["/usr/bin/codesign", "--force", "--sign", identity, str(staged)],
                    "release signing failed; no fallback")
            verify(staged, requirement, identity)
            # Reserve the destination without clobbering any concurrent creator.
            output.mkdir()
            try:
                for child in staged.iterdir():
                    child.rename(output / child.name)
            except OSError:
                raise ReleaseError("cannot finish release copy; output may be incomplete and must not be published") from None
        verify(output, requirement, identity)
        destination = output
    print(json.dumps({"mode": "verify-only" if args.verify_only else "sign-copy", "app": str(destination),
                      "bundleID": BUNDLE_ID, "strictSignature": True, "explicitIdentityMatches": True,
                      "designatedRequirementMatches": True,
                      "designatedRequirementSHA256": hashlib.sha256(requirement.encode()).hexdigest(),
                      "inputBundlesModified": False, "TCCRetentionTested": False}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (ReleaseError, OSError, ValueError) as error:
        message = str(error) if isinstance(error, ReleaseError) else "filesystem or metadata operation failed"
        print("release-sign: " + message, file=sys.stderr)
        sys.exit(1)
