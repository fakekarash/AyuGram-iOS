"""Manual baseline CI helper. No Apple account or personal signing credentials."""

import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import secrets
import shlex
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile


ROOT = Path(__file__).resolve().parent.parent
ARTIFACTS = ROOT / "build" / "ayugram-baseline"
BAZEL_SHA256 = "dd466352a3e4d3581b8898740ee1ff208866ccbe25f8d367c5dcb950219587e6"


def output(*args):
    return subprocess.check_output(args, text=True).strip()


def pinned_versions():
    versions = json.loads((ROOT / "versions.json").read_text())
    expected = {"macos": "26", "xcode": "26.6", "bazel": "9.2.0:" + BAZEL_SHA256}
    for key, value in expected.items():
        if versions.get(key) != value:
            raise RuntimeError("versions.json changed; review the baseline runner/toolchain pins")
    return versions


def bazel_path():
    return ROOT / "build-input" / "bazel-9.2.0-darwin-arm64"


def preflight():
    versions = pinned_versions()
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise RuntimeError("Requires macOS 26 on ARM64 (GitHub runner macos-26)")
    if output("sw_vers", "-productVersion").split(".")[0] != versions["macos"]:
        raise RuntimeError("Runner macOS major version does not match versions.json")
    developer = Path("/Applications/Xcode_26.6.app/Contents/Developer")
    if not developer.is_dir():
        raise RuntimeError("Pinned Xcode 26.6 is absent from this runner image")
    subprocess.run(["sudo", "xcode-select", "--switch", str(developer)], check=True)
    xcode = output("xcodebuild", "-version")
    if xcode.splitlines()[0] != "Xcode 26.6":
        raise RuntimeError("Selected Xcode does not match versions.json")
    print(xcode)
    binary = bazel_path()
    binary.parent.mkdir(exist_ok=True)
    if not binary.exists():
        url = "https://github.com/bazelbuild/bazel/releases/download/9.2.0/" + binary.name
        with urllib.request.urlopen(url, timeout=120) as response, binary.open("xb") as target:
            shutil.copyfileobj(response, target)
    if hashlib.sha256(binary.read_bytes()).hexdigest() != BAZEL_SHA256:
        raise RuntimeError("Downloaded Bazel SHA256 does not match versions.json")
    binary.chmod(0o755)
    if output(str(binary), "--version") != "bazel 9.2.0":
        raise RuntimeError("Unexpected Bazel version")
    print("Verified macOS 26 / ARM64, Xcode 26.6, Bazel 9.2.0 + SHA256")


def api_credentials():
    api_id = os.environ.get("TELEGRAM_API_ID", "")
    api_hash = os.environ.get("TELEGRAM_API_HASH", "")
    if not re.fullmatch(r"[1-9][0-9]*", api_id) or int(api_id) > 2147483647:
        raise RuntimeError("Set TELEGRAM_API_ID to a positive 32-bit decimal integer")
    if not re.fullmatch(r"[0-9a-fA-F]{32}", api_hash):
        raise RuntimeError("Set TELEGRAM_API_HASH to exactly 32 hexadecimal characters")
    return api_id, api_hash


def redacted_run(command, sensitive):
    # Filter before stdout reaches Actions; never persist a raw build log.
    # Secrets are configuration input, never command arguments to Make/Bazel.
    child_env = os.environ.copy()
    for key in ("TELEGRAM_API_ID", "TELEGRAM_API_HASH"):
        child_env.pop(key, None)
    variants = sorted({v for item in sensitive for v in (item, item.lower(), item.upper()) if v},
                      key=len, reverse=True)
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, errors="replace", env=child_env) as process:
        for line in process.stdout:
            for value in variants:
                line = line.replace(value, "[REDACTED]")
            print(line, end="", flush=True)
        if process.wait() != 0:
            # Do not include command arguments (e.g. ephemeral keychain password).
            raise RuntimeError("CI subprocess failed; see redacted output above")


def build():
    pinned_versions()
    if platform.system() != "Darwin" or os.environ.get("GITHUB_ACTIONS") != "true":
        raise RuntimeError("Build is restricted to the ephemeral macOS Actions runner")
    api_id, api_hash = api_credentials()
    app_specific_url_scheme = os.environ.get("AYUGRAM_APP_SPECIFIC_URL_SCHEME", "tg")
    if not re.fullmatch(r"[a-z][a-z0-9+.-]*", app_specific_url_scheme):
        raise RuntimeError("Invalid application URL scheme")
    os.umask(0o077)
    original_keychains = shlex.split(output("security", "list-keychains", "-d", "user"))
    password = secrets.token_hex(24)
    sensitive = (api_id, api_hash, password)
    with tempfile.TemporaryDirectory(prefix="ayugram-baseline-", dir=os.environ["RUNNER_TEMP"]) as temp:
        config = Path(temp) / "configuration.json"
        keychain = str(Path(temp) / "smoke.keychain-db")
        configuration = {
            # Required by the PUBLIC upstream fake profiles; re-sign before install.
            "bundle_id": "ph.telegra.Telegraph", "team_id": "C67CF9S4VU",
            "api_id": api_id, "api_hash": api_hash,
            "app_center_id": "0", "is_internal_build": "true", "is_appstore_build": "false",
            "appstore_id": "0", "app_specific_url_scheme": app_specific_url_scheme, "premium_iap_product_id": "",
            "enable_siri": False, "enable_icloud": False,
        }
        config.write_text(json.dumps(configuration), encoding="utf-8")
        def run(*args):
            redacted_run(list(args), sensitive)
        try:
            run("security", "create-keychain", "-p", password, keychain)
            run("security", "set-keychain-settings", "-lut", "21600", keychain)
            run("security", "unlock-keychain", "-p", password, keychain)
            run("security", "list-keychains", "-d", "user", "-s", keychain, *original_keychains)
            # SelfSigned.p12 already contains its public certificate. Importing
            # Public.cer afterwards makes `security import` fail with duplicate-item.
            for certificate in ("fake-codesigning/certs/SelfSigned.p12", "AppleWWDRCAG3.cer"):
                run("security", "import", str(ROOT / "build-system" / certificate),
                    "-k", keychain, "-P", "", "-T", "/usr/bin/codesign", "-T", "/usr/bin/security")
            run("security", "set-key-partition-list", "-S", "apple-tool:,apple:", "-s",
                "-k", password, keychain)
            run(sys.executable, "-u", "build-system/Make/Make.py",
                "--bazel=" + str(bazel_path()),
                "--bazelUserRoot=" + str(Path(os.environ["RUNNER_TEMP"]) / "ayugram-bazel"),
                "build", "--configurationPath=" + str(config),
                "--codesigningInformationPath=build-system/fake-codesigning",
                "--configuration=release_arm64", "--buildNumber=" + os.environ["GITHUB_RUN_NUMBER"],
                "--outputBuildArtifactsPath=" + str(ARTIFACTS))
        finally:
            # Make.py generates an ignored Starlark configuration containing API values.
            (ROOT / "build-input/configuration-repository/variables.bzl").unlink(missing_ok=True)
            config.unlink(missing_ok=True)
            run("security", "list-keychains", "-d", "user", "-s", *original_keychains)
            if Path(keychain).exists():
                run("security", "delete-keychain", keychain)


def verify():
    ipa = ARTIFACTS / "Telegram.ipa"
    if not ipa.is_file() or ipa.stat().st_size == 0:
        raise RuntimeError("No IPA was produced")
    with zipfile.ZipFile(ipa) as archive:
        if archive.testzip() is not None:
            raise RuntimeError("IPA has corrupt ZIP members")
        names = archive.namelist()
        app_plists = [n for n in names if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", n)]
        if len(app_plists) != 1:
            raise RuntimeError("Expected exactly one Payload/*.app/Info.plist")
        info = plistlib.loads(archive.read(app_plists[0]))
        executable = app_plists[0].removesuffix("Info.plist") + info["CFBundleExecutable"]
        if not archive.getinfo(executable).file_size:
            raise RuntimeError("IPA has no app executable")
        if info.get("CFBundleIdentifier") != "ph.telegra.Telegraph":
            raise RuntimeError("Unexpected baseline bundle identifier")
        if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
            raise RuntimeError("Expected an iPhoneOS device build")
        with tempfile.TemporaryDirectory(dir=os.environ["RUNNER_TEMP"]) as temp:
            binary = Path(temp) / "executable"
            with archive.open(executable) as source, binary.open("wb") as target:
                shutil.copyfileobj(source, target)
            subprocess.run(["lipo", str(binary), "-verify_arch", "arm64"], check=True)
        extensions = sorted(n for n in names if re.fullmatch(r"Payload/[^/]+\.app/PlugIns/[^/]+\.appex/Info\.plist", n))
    manifest = {
        "commit": output("git", "rev-parse", "HEAD"),
        "versions": pinned_versions(), "macos_actual": output("sw_vers", "-productVersion"),
        "xcode_actual": output("xcodebuild", "-version"),
        "runner_image": os.environ.get("ImageVersion"),
        "submodules": output("git", "submodule", "status", "--recursive").splitlines(),
        "ipa_sha256": hashlib.sha256(ipa.read_bytes()).hexdigest(),
        "ipa_bytes": ipa.stat().st_size, "extensions": extensions,
        "signing": "upstream fake signing; must be re-signed before installation",
        "device_installation_tested": False,
    }
    (ARTIFACTS / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("Validated device IPA (arm64), ZIP integrity, bundle and executable; SHA256: " + manifest["ipa_sha256"])


if __name__ == "__main__":
    os.chdir(ROOT)
    try:
        if len(sys.argv) != 2 or sys.argv[1] not in ("preflight", "build", "verify"):
            raise RuntimeError("Usage: ayugram_ci.py preflight|build|verify")
        {"preflight": preflight, "build": build, "verify": verify}[sys.argv[1]]()
    except RuntimeError as error:
        # Our RuntimeError messages contain only fixed diagnostics, never values.
        print("::error::" + str(error))
        sys.exit(1)
    except Exception:
        # Avoid traceback/exception text that could contain configuration or credentials.
        print("::error::Baseline CI step failed. Check prerequisites and redacted output; no artifact success is claimed.")
        sys.exit(1)
