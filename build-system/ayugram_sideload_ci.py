"""Build and package a manual AyuGram IPA that can run without App Groups."""

import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

import ayugram_ci as baseline


ROOT = Path(__file__).resolve().parent.parent
ARTIFACTS = ROOT / "build" / "ayugram-sideload"
CUSTOM_BUNDLE_ID = "com.fakekarash.ayugram"
PATCHES = (
    (ROOT / "submodules" / "TelegramUI", ROOT / "build-system" / "patches" / "sideload-telegramui.patch"),
    (ROOT / "submodules" / "PasscodeCore", ROOT / "build-system" / "patches" / "sideload-passcodecore.patch"),
)


def output(*args):
    return subprocess.check_output(args, text=True).strip()


def apply_patches():
    for repository, patch_path in PATCHES:
        if not repository.is_dir():
            raise RuntimeError("Required source directory is missing")
        if not patch_path.is_file():
            raise RuntimeError("Required compatibility patch is missing")
        subprocess.run(
            ["git", "-C", str(repository), "apply", "--check", str(patch_path)],
            check=True,
        )
        subprocess.run(
            ["git", "-C", str(repository), "apply", str(patch_path)],
            check=True,
        )
    print("Applied reviewed App Group fallback and private-keychain patches")


def replace_bundle_strings(value):
    if isinstance(value, str):
        return value.replace("ph.telegra.Telegraph", CUSTOM_BUNDLE_ID)
    if isinstance(value, list):
        return [replace_bundle_strings(item) for item in value]
    if isinstance(value, dict):
        return {key: replace_bundle_strings(item) for key, item in value.items()}
    return value


def repackage():
    source = ARTIFACTS / "Telegram.ipa"
    target = ARTIFACTS / "AyuGram.ipa"
    temporary = ARTIFACTS / "AyuGram.ipa.tmp"
    if not source.is_file():
        raise RuntimeError("The upstream build did not produce Telegram.ipa")

    with zipfile.ZipFile(source, "r") as incoming:
        names = incoming.namelist()
        app_plists = [name for name in names if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)]
        if len(app_plists) != 1:
            raise RuntimeError("Expected exactly one main application plist")
        main_plist = app_plists[0]
        app_root = main_plist.removesuffix("Info.plist")

        with zipfile.ZipFile(temporary, "w", allowZip64=True) as outgoing:
            for info in incoming.infolist():
                name = info.filename
                relative = name.removeprefix(app_root)
                if name.startswith(app_root + "PlugIns/") or name.startswith(app_root + "Watch/"):
                    continue
                if "/_CodeSignature/" in name:
                    continue
                if name.endswith("embedded.mobileprovision"):
                    continue
                data = incoming.read(name)
                if name == main_plist:
                    plist = replace_bundle_strings(plistlib.loads(data))
                    plist["CFBundleIdentifier"] = CUSTOM_BUNDLE_ID
                    plist["CFBundleDisplayName"] = "AyuGram"
                    plist["CFBundleName"] = "AyuGram"
                    plist["CFBundleURLTypes"] = [
                        {
                            "CFBundleTypeRole": "Viewer",
                            "CFBundleURLName": CUSTOM_BUNDLE_ID,
                            "CFBundleURLSchemes": ["ayugram"],
                        }
                    ]
                    data = plistlib.dumps(plist, fmt=plistlib.FMT_BINARY, sort_keys=False)
                outgoing.writestr(info, data)

    temporary.replace(target)
    source.unlink()
    print("Created extension-free AyuGram.ipa with bundle id " + CUSTOM_BUNDLE_ID)


def build():
    baseline.ARTIFACTS = ARTIFACTS
    previous_scheme = os.environ.get("AYUGRAM_APP_SPECIFIC_URL_SCHEME")
    os.environ["AYUGRAM_APP_SPECIFIC_URL_SCHEME"] = "ayugram"
    try:
        baseline.build()
    finally:
        if previous_scheme is None:
            os.environ.pop("AYUGRAM_APP_SPECIFIC_URL_SCHEME", None)
        else:
            os.environ["AYUGRAM_APP_SPECIFIC_URL_SCHEME"] = previous_scheme
    repackage()


def verify():
    ipa = ARTIFACTS / "AyuGram.ipa"
    if not ipa.is_file() or ipa.stat().st_size == 0:
        raise RuntimeError("No AyuGram IPA was produced")
    with zipfile.ZipFile(ipa) as archive:
        if archive.testzip() is not None:
            raise RuntimeError("IPA has corrupt ZIP members")
        names = archive.namelist()
        app_plists = [name for name in names if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)]
        if len(app_plists) != 1:
            raise RuntimeError("Expected exactly one Payload/*.app/Info.plist")
        app_root = app_plists[0].removesuffix("Info.plist")
        info = plistlib.loads(archive.read(app_plists[0]))
        if info.get("CFBundleIdentifier") != CUSTOM_BUNDLE_ID:
            raise RuntimeError("Unexpected sideload bundle identifier")
        if info.get("CFBundleDisplayName") != "AyuGram":
            raise RuntimeError("Unexpected sideload application name")
        if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
            raise RuntimeError("Expected an iPhoneOS device build")
        forbidden = [
            name for name in names
            if name.startswith(app_root + "PlugIns/")
            or name.startswith(app_root + "Watch/")
            or "/_CodeSignature/" in name
            or name.endswith("embedded.mobileprovision")
        ]
        if forbidden:
            raise RuntimeError("Sideload package still contains extensions or stale signing material")
        executable = app_root + info["CFBundleExecutable"]
        if not archive.getinfo(executable).file_size:
            raise RuntimeError("IPA has no app executable")
        with tempfile.TemporaryDirectory(dir=os.environ["RUNNER_TEMP"]) as temp:
            binary = Path(temp) / "executable"
            with archive.open(executable) as source, binary.open("wb") as target:
                shutil.copyfileobj(source, target)
            subprocess.run(["lipo", str(binary), "-verify_arch", "arm64"], check=True)

    patch_hashes = {
        patch.name: hashlib.sha256(patch.read_bytes()).hexdigest()
        for _, patch in PATCHES
    }
    manifest = {
        "commit": output("git", "rev-parse", "HEAD"),
        "versions": baseline.pinned_versions(),
        "macos_actual": output("sw_vers", "-productVersion"),
        "xcode_actual": output("xcodebuild", "-version"),
        "runner_image": os.environ.get("ImageVersion"),
        "bundle_id": CUSTOM_BUNDLE_ID,
        "display_name": "AyuGram",
        "patches": patch_hashes,
        "ipa_sha256": hashlib.sha256(ipa.read_bytes()).hexdigest(),
        "ipa_bytes": ipa.stat().st_size,
        "extensions": [],
        "signing": "re-signable package; stale fake signature and profiles removed",
        "compatibility": "main app uses its private sandbox when App Groups are unavailable",
        "limitations": ["no app extensions", "no push entitlement guarantee"],
        "device_installation_tested": False,
    }
    (ARTIFACTS / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("Validated sideload IPA; SHA256: " + manifest["ipa_sha256"])


if __name__ == "__main__":
    os.chdir(ROOT)
    try:
        if len(sys.argv) != 2 or sys.argv[1] not in ("patch", "build", "verify"):
            raise RuntimeError("Usage: ayugram_sideload_ci.py patch|build|verify")
        {"patch": apply_patches, "build": build, "verify": verify}[sys.argv[1]]()
    except RuntimeError as error:
        print("::error::" + str(error))
        sys.exit(1)
    except Exception:
        print("::error::Sideload CI step failed; no artifact success is claimed.")
        sys.exit(1)
