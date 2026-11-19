"""Re-sign (and, if needed, extend) the public fake provisioning profiles.

The upstream repository ships self-signed "fake" provisioning profiles. Bazel
extracts their plist payload with `openssl smime -verify -noverify`, which fails
if the CMS signature no longer matches the payload — for example after the
ExpirationDate has been adjusted, or once the original date has passed.

This helper rewrites the payload (extending an expired ExpirationDate) and signs
it again with the self-signed identity from `fake-codesigning/certs/SelfSigned.p12`.
`-noverify` means the signing certificate itself is never validated, so a fresh
self-signed signature is enough for the build.

Usage:
    python3 build-system/renew_fake_profiles.py            # renew and re-sign
    python3 build-system/renew_fake_profiles.py --check    # verify signatures only

Requires the `cryptography` package (available on GitHub runners via pip).
"""

import argparse
import datetime
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent
PROFILES = ROOT / "fake-codesigning" / "profiles"
IDENTITY = ROOT / "fake-codesigning" / "certs" / "SelfSigned.p12"
PAYLOAD = re.compile(rb"<\?xml.*?</plist>", re.DOTALL)
EXPIRATION = re.compile(rb"<key>ExpirationDate</key>\s*<date>([0-9T:Z\-]+)</date>")
EXTENSION_YEARS = 10


def now() -> datetime.datetime:
    return datetime.datetime.now(datetime.timezone.utc)


def load_identity() -> tuple:
    # Imported lazily so that --check works without the cryptography package.
    from cryptography.hazmat.primitives.serialization import pkcs12

    key, certificate, _ = pkcs12.load_key_and_certificates(IDENTITY.read_bytes(), b"")
    if key is None or certificate is None:
        raise RuntimeError("the fake signing identity has no key or certificate")
    return certificate, key


def payload_of(data: bytes) -> tuple:
    match = PAYLOAD.search(data)
    if match is None:
        raise RuntimeError("profile has no plist payload")
    return match.start(), match.end(), match.group(0)


def expiration_of(payload: bytes) -> datetime.datetime:
    match = EXPIRATION.search(payload)
    if match is None:
        raise RuntimeError("profile has no ExpirationDate")
    return datetime.datetime.strptime(match.group(1).decode("ascii"), "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc)


def renew(profile: pathlib.Path, certificate, key) -> str:
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.serialization import Encoding, pkcs7

    data = profile.read_bytes()
    start, end, payload = payload_of(data)
    expiration = expiration_of(payload)
    moment = now()

    changed = False
    if expiration <= moment:
        try:
            expiration = expiration.replace(year=expiration.year + EXTENSION_YEARS)
        except ValueError:
            expiration = expiration + datetime.timedelta(days=365 * EXTENSION_YEARS)
        payload = EXPIRATION.sub(
            b"<key>ExpirationDate</key><date>" + expiration.strftime("%Y-%m-%dT%H:%M:%SZ").encode("ascii") + b"</date>",
            payload,
        )
        changed = True

    signature = (
        pkcs7.PKCS7SignatureBuilder()
        .set_data(payload)
        .add_signer(certificate, key, hashes.SHA256())
        .sign(Encoding.DER, [pkcs7.PKCS7Options.Binary, pkcs7.PKCS7Options.NoAttributes])
    )
    profile.write_bytes(signature)
    return ("extended to " + expiration.strftime("%Y-%m-%d") if changed else "re-signed, valid until " + expiration.strftime("%Y-%m-%d"))


def openssl_available() -> bool:
    try:
        subprocess.run(["openssl", "version"], check=True, capture_output=True)
        return True
    except (OSError, subprocess.CalledProcessError):
        return False


def verify(profile: pathlib.Path) -> bool:
    if not openssl_available():
        _, _, payload = payload_of(profile.read_bytes())
        return expiration_of(payload) > now()
    result = subprocess.run(
        ["openssl", "smime", "-inform", "der", "-verify", "-noverify", "-in", str(profile)],
        capture_output=True,
    )
    return result.returncode == 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="verify the CMS signature of every profile")
    arguments = parser.parse_args()

    profiles = sorted(PROFILES.glob("*.mobileprovision"))
    if not profiles:
        print("::error::No fake provisioning profiles found", file=sys.stderr)
        return 1

    if arguments.check:
        failures = 0
        for profile in profiles:
            if verify(profile):
                print("OK   " + profile.name)
            else:
                failures += 1
                print("FAIL " + profile.name)
        if failures:
            print("::error::{0} fake provisioning profile(s) failed verification".format(failures), file=sys.stderr)
            return 1
        return 0

    certificate, key = load_identity()
    for profile in profiles:
        print(profile.name + ": " + renew(profile, certificate, key))
        if not verify(profile):
            print("::error::re-signed profile does not verify: " + profile.name, file=sys.stderr)
            return 1
    print("All fake provisioning profiles re-signed and verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
