"""Extend the expiry date of the public fake provisioning profiles.

The upstream repository ships self-signed "fake" provisioning profiles that only
exist so that Bazel can generate entitlements and an intermediate signature for
an IPA that the user re-signs later. rules_apple refuses to build when a
profile's ExpirationDate is in the past, so once those dates pass the whole
build stops working.

The profiles are CMS blobs whose payload is a plain XML plist. Only the
ExpirationDate value is rewritten, in place, with a value of exactly the same
length, so every CMS length prefix and the file size stay valid.

Usage:
    python3 build-system/extend_fake_profiles.py            # extend to +10 years
    python3 build-system/extend_fake_profiles.py --check    # exit 1 if expired
"""

import argparse
import datetime
import pathlib
import re
import sys

PROFILES = pathlib.Path(__file__).resolve().parent / "fake-codesigning" / "profiles"
EXPIRATION = re.compile(rb"<key>ExpirationDate</key>\s*<date>([0-9T:Z\-]+)</date>")
EXTENSION_YEARS = 10


def find_expiration(data: bytes) -> tuple[int, int, str]:
    match = EXPIRATION.search(data)
    if match is None:
        raise RuntimeError("no ExpirationDate found in profile")
    return match.start(1), match.end(1), match.group(1).decode("ascii")


def parse(value: str) -> datetime.datetime:
    return datetime.datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc)


def render(moment: datetime.datetime) -> bytes:
    return moment.strftime("%Y-%m-%dT%H:%M:%SZ").encode("ascii")


def extend(path: pathlib.Path, now: datetime.datetime) -> str:
    data = path.read_bytes()
    start, end, current = find_expiration(data)
    expiration = parse(current)
    if expiration > now:
        return "still valid until " + current

    try:
        extended = expiration.replace(year=expiration.year + EXTENSION_YEARS)
    except ValueError:
        extended = expiration + datetime.timedelta(days=365 * EXTENSION_YEARS)

    replacement = render(extended)
    if len(replacement) != end - start:
        raise RuntimeError("replacement changes the profile length")

    path.write_bytes(data[:start] + replacement + data[end:])
    return current + " -> " + replacement.decode("ascii")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="only report expired profiles; do not modify")
    arguments = parser.parse_args()

    now = datetime.datetime.now(datetime.timezone.utc)
    profiles = sorted(PROFILES.glob("*.mobileprovision"))
    if not profiles:
        print("::error::No fake provisioning profiles found", file=sys.stderr)
        return 1

    expired = []
    for profile in profiles:
        if arguments.check:
            _, _, current = find_expiration(profile.read_bytes())
            if parse(current) <= now:
                expired.append(profile.name)
                print("EXPIRED {0} ({1})".format(profile.name, current))
        else:
            print("{0}: {1}".format(profile.name, extend(profile, now)))

    if arguments.check and expired:
        print("::error::{0} fake provisioning profile(s) expired".format(len(expired)), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
