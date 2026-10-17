"""Build and launch the App Group fallback in an iOS Simulator."""

import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import time
import zipfile

import ayugram_ci as baseline
import ayugram_sideload_ci as sideload


ROOT = Path(__file__).resolve().parent.parent
ARTIFACTS = ROOT / "build" / "ayugram-simulator"
RESULTS = ARTIFACTS / "results"
BUNDLE_ID = sideload.CUSTOM_BUNDLE_ID


def output(*args):
    return subprocess.check_output(args, text=True).strip()


def build():
    baseline.ARTIFACTS = ARTIFACTS
    previous_scheme = os.environ.get("AYUGRAM_APP_SPECIFIC_URL_SCHEME")
    previous_configuration = os.environ.get("AYUGRAM_BUILD_CONFIGURATION")
    os.environ["AYUGRAM_APP_SPECIFIC_URL_SCHEME"] = "ayugram"
    os.environ["AYUGRAM_BUILD_CONFIGURATION"] = "release_sim_arm64"
    try:
        baseline.build()
    finally:
        if previous_scheme is None:
            os.environ.pop("AYUGRAM_APP_SPECIFIC_URL_SCHEME", None)
        else:
            os.environ["AYUGRAM_APP_SPECIFIC_URL_SCHEME"] = previous_scheme
        if previous_configuration is None:
            os.environ.pop("AYUGRAM_BUILD_CONFIGURATION", None)
        else:
            os.environ["AYUGRAM_BUILD_CONFIGURATION"] = previous_configuration


def select_simulator():
    devices = json.loads(output("xcrun", "simctl", "list", "devices", "available", "-j"))["devices"]
    preferred = []
    fallback = []
    for runtime, entries in devices.items():
        if "iOS" not in runtime:
            continue
        for entry in entries:
            if not entry.get("isAvailable") or not entry.get("name", "").startswith("iPhone"):
                continue
            fallback.append(entry)
            if entry["name"] == "iPhone 17 Pro":
                preferred.append(entry)
    candidates = preferred or fallback
    if not candidates:
        raise RuntimeError("No available iPhone simulator is installed")
    return candidates[0]


def prepare_app():
    ipa = ARTIFACTS / "Telegram.ipa"
    app_dir = ARTIFACTS / "SimulatorPayload"
    if not ipa.is_file():
        raise RuntimeError("Simulator build did not produce Telegram.ipa")
    if app_dir.exists():
        shutil.rmtree(app_dir)
    app_dir.mkdir(parents=True)
    with zipfile.ZipFile(ipa) as archive:
        if archive.testzip() is not None:
            raise RuntimeError("Simulator IPA has corrupt ZIP members")
        archive.extractall(app_dir)
    apps = list((app_dir / "Payload").glob("*.app"))
    if len(apps) != 1:
        raise RuntimeError("Expected one simulator application bundle")
    app = apps[0]
    for directory in (app / "PlugIns", app / "Watch"):
        if directory.exists():
            shutil.rmtree(directory)
    for signature in app.rglob("_CodeSignature"):
        if signature.is_dir():
            shutil.rmtree(signature)
    for profile in app.rglob("embedded.mobileprovision"):
        profile.unlink()
    info_path = app / "Info.plist"
    info = sideload.replace_bundle_strings(plistlib.loads(info_path.read_bytes()))
    info["CFBundleIdentifier"] = BUNDLE_ID
    info["CFBundleDisplayName"] = "AyuGram"
    info["CFBundleName"] = "AyuGram"
    info["CFBundleURLTypes"] = [{
        "CFBundleTypeRole": "Viewer",
        "CFBundleURLName": BUNDLE_ID,
        "CFBundleURLSchemes": ["ayugram"],
    }]
    info_path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_BINARY, sort_keys=False))
    subprocess.run(["codesign", "--force", "--deep", "--sign", "-", str(app)], check=True)
    return app, info


def copy_runtime_diagnostics(udid, result_dir):
    containers = []
    try:
        data_container = Path(output(
            "xcrun", "simctl", "get_app_container", udid, BUNDLE_ID, "data"
        ))
        containers.append(("data", data_container))
    except subprocess.CalledProcessError as error:
        (result_dir / "data-container-error.txt").write_text(
            "simctl get_app_container failed: " + str(error) + "\n",
            encoding="utf-8",
        )

    for label, container in containers:
        root = container / "Library" / "Application Support" / "AyuGram" / "telegram-data"
        inventory = []
        if root.exists():
            for path in sorted(root.rglob("*")):
                relative = path.relative_to(container)
                if path.is_file():
                    inventory.append(str(relative) + "\t" + str(path.stat().st_size))
                else:
                    inventory.append(str(relative) + "/")
        (result_dir / (label + "-container-inventory.txt")).write_text(
            "\n".join(inventory) + ("\n" if inventory else ""),
            encoding="utf-8",
        )

        logs = root / "logs" / "app-logs"
        log_files = list(logs.glob("log-*")) if logs.is_dir() else []
        safe_markers = {
            "logger_file_count": len(log_files),
            "logger_total_bytes": sum(path.stat().st_size for path in log_files),
            "received_context": False,
            "received_authorized_context": False,
            "received_unauthorized_context": False,
            "postbox_activity": False,
        }
        for path in log_files:
            content = path.read_text(encoding="utf-8", errors="replace")
            safe_markers["received_context"] |= "received context" in content
            safe_markers["received_authorized_context"] |= "received context Optional" in content
            safe_markers["received_unauthorized_context"] |= "received auth context Optional" in content
            safe_markers["postbox_activity"] |= "[Postbox]" in content
        (result_dir / (label + "-startup-markers.json")).write_text(
            json.dumps(safe_markers, indent=2) + "\n",
            encoding="utf-8",
        )


def launch(mode):
    result_dir = RESULTS / mode
    if result_dir.exists():
        shutil.rmtree(result_dir)
    result_dir.mkdir(parents=True)
    app, info = prepare_app()
    signature = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(app)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    (result_dir / "codesign-entitlements.txt").write_text(signature.stdout, encoding="utf-8")
    device = select_simulator()
    udid = device["udid"]
    subprocess.run(["xcrun", "simctl", "boot", udid], check=False)
    subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True)
    subprocess.run(["xcrun", "simctl", "uninstall", udid, BUNDLE_ID], check=False)
    subprocess.run(["xcrun", "simctl", "install", udid, str(app)], check=True)
    launch_output = output("xcrun", "simctl", "launch", udid, BUNDLE_ID)
    match = re.search(r":\s*([0-9]+)$", launch_output)
    if not match:
        raise RuntimeError("simctl did not return an application process id")
    pid = int(match.group(1))
    smoke_window_seconds = 30
    time.sleep(smoke_window_seconds)
    processes = output("xcrun", "simctl", "spawn", udid, "/bin/ps", "-ax")
    if not re.search(r"^\s*" + str(pid) + r"\s", processes, re.MULTILINE):
        raise RuntimeError("AyuGram process exited during the simulator smoke window")
    screenshot = result_dir / "ayugram-simulator.png"
    subprocess.run(["xcrun", "simctl", "io", udid, "screenshot", str(screenshot)], check=True)
    log_path = result_dir / "ayugram-simulator.log"
    with log_path.open("w", encoding="utf-8") as target:
        subprocess.run([
            "xcrun", "simctl", "spawn", udid, "log", "show", "--style", "compact",
            "--last", "2m", "--predicate", 'process == "Telegram"',
        ], stdout=target, stderr=subprocess.STDOUT, text=True, check=False)
    copy_runtime_diagnostics(udid, result_dir)
    result = {
        "commit": output("git", "rev-parse", "HEAD"),
        "device": device["name"],
        "udid": udid,
        "bundle_id": BUNDLE_ID,
        "display_name": info.get("CFBundleDisplayName"),
        "supported_platforms": info.get("CFBundleSupportedPlatforms"),
        "launch_output": launch_output,
        "smoke_window_seconds": smoke_window_seconds,
        "pid_after_smoke_window": pid,
        "screenshot": screenshot.name,
        "mode": mode,
        "app_group_entitlement": False,
        "device_installation_tested": False,
        "simulator_launch_tested": True,
    }
    (result_dir / "simulator-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(mode + " launch remained alive for " + str(smoke_window_seconds) + " seconds; pid=" + str(pid))


if __name__ == "__main__":
    os.chdir(ROOT)
    try:
        if len(sys.argv) == 2 and sys.argv[1] == "build":
            build()
        elif len(sys.argv) == 3 and sys.argv[1] == "launch" and sys.argv[2] == "sideload":
            launch(sys.argv[2])
        else:
            raise RuntimeError("Usage: ayugram_simulator_ci.py build | launch sideload")
    except RuntimeError as error:
        print("::error::" + str(error))
        sys.exit(1)
    except Exception:
        print("::error::Simulator smoke test failed; no launch success is claimed.")
        sys.exit(1)
