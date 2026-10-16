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


def prepare_app(app_group_control=False):
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
    codesign = ["codesign", "--force", "--deep", "--sign", "-"]
    if app_group_control:
        entitlements_path = ARTIFACTS / "simulator-app-group-entitlements.plist"
        entitlements_path.write_bytes(plistlib.dumps({
            "com.apple.security.application-groups": ["group." + BUNDLE_ID],
        }, fmt=plistlib.FMT_XML, sort_keys=True))
        codesign.extend(["--entitlements", str(entitlements_path)])
    codesign.append(str(app))
    subprocess.run(codesign, check=True)
    return app, info


def copy_runtime_diagnostics(udid, result_dir, app_group_control):
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

    if app_group_control:
        group_id = "group." + BUNDLE_ID
        try:
            group_container = Path(output(
                "xcrun", "simctl", "get_app_container", udid, BUNDLE_ID, group_id
            ))
            containers.append(("app-group", group_container))
        except subprocess.CalledProcessError as error:
            (result_dir / "app-group-container-error.txt").write_text(
                "simctl get_app_container failed: " + str(error) + "\n",
                encoding="utf-8",
            )

    for label, container in containers:
        root = container / "Library" / "Application Support" / "telegram-data"
        if label == "app-group":
            root = container / "telegram-data"
        inventory = []
        if root.exists():
            for path in sorted(root.rglob("*")):
                relative = path.relative_to(container)
                if path.is_file():
                    inventory.append(str(relative) + "\t" + str(piÑ ¹ÍÑÐ ¤¹ÍÑ}Í¥é¤¤(±Íè(¥¹Ù¹Ñ½Éä¹ÁÁ¹¡ÍÑÈ¡É±Ñ¥Ù¤¬¼¤(¡ÉÍÕ±Ñ}¥È¼¡±°¬µ½¹Ñ¥¹Èµ¥¹Ù¹Ñ½Éä¹ÑáÐ¤¤¹ÝÉ¥Ñ}ÑáÐ (q¸¹©½¥¸¡¥¹Ù¹Ñ½Éä¤¬ q¸¥¥¹Ù¹Ñ½Éä±Í¤°(¹½¥¹ôÕÑ´à°(¤((±½ÌôÉ½½Ð¼±½Ì¼ÁÀµ±½Ì(±½}¥±Ìô±¥ÍÐ¡±½Ì¹±½ ±½´¨¤¤¥±½Ì¹¥Í}¥È ¤±Ímt(Í}µÉ­ÉÌôì(±½É}¥±}½Õ¹Ðè±¸¡±½}¥±Ì¤°(±½É}Ñ½Ñ±}åÑÌèÍÕ´¡ÁÑ ¹ÍÑÐ ¤¹ÍÑ}Í¥é½ÈÁÑ ¥¸±½}¥±Ì¤°(É¥Ù}½¹ÑáÐè±Í°(É¥Ù}ÕÑ¡½É¥é}½¹ÑáÐè±Í°(É¥Ù}Õ¹ÕÑ¡½É¥é}½¹ÑáÐè±Í°(Á½ÍÑ½á}Ñ¥Ù¥Ñäè±Í°(ô(½ÈÁÑ ¥¸±½}¥±Ìè(½¹Ñ¹ÐôÁÑ ¹É}ÑáÐ¡¹½¥¹ôÕÑ´à°ÉÉ½ÉÌôÉÁ±¤(Í}µÉ­ÉÍlÉ¥Ù}½¹ÑáÐtðôÉ¥Ù½¹ÑáÐ¥¸½¹Ñ¹Ð(Í}µÉ­ÉÍlÉ¥Ù}ÕÑ¡½É¥é}½¹ÑáÐtðôÉ¥Ù½¹ÑáÐ=ÁÑ¥½¹°¥¸½¹Ñ¹Ð(Í}µÉ­ÉÍlÉ¥Ù}Õ¹ÕÑ¡½É¥é}½¹ÑáÐtðôÉ¥ÙÕÑ ½¹ÑáÐ=ÁÑ¥½¹°¥¸½¹Ñ¹Ð(Í}µÉ­ÉÍlÁ½ÍÑ½á}Ñ¥Ù¥ÑätðômA½ÍÑ½át¥¸½¹Ñ¹Ð(¡ÉÍÕ±Ñ}¥È¼¡±°¬µÍÑÉÑÕÀµµÉ­ÉÌ¹©Í½¸¤¤¹ÝÉ¥Ñ}ÑáÐ (©Í½¸¹ÕµÁÌ¡Í}µÉ­ÉÌ°¥¹¹ÐôÈ¤¬q¸°(¹½¥¹ôÕÑ´à°(¤(()±Õ¹ ¡µ½¤è(ÁÁ}É½ÕÁ}½¹ÑÉ½°ôµ½ôôÁÁÉ½ÕÀµ½¹ÑÉ½°(ÉÍÕ±Ñ}¥ÈôIMU1QL¼µ½(¥ÉÍÕ±Ñ}¥È¹á¥ÍÑÌ ¤è(Í¡ÕÑ¥°¹ÉµÑÉ¡ÉÍÕ±Ñ}¥È¤(ÉÍÕ±Ñ}¥È¹µ­¥È¡ÁÉ¹ÑÌõQÉÕ¤(ÁÀ°¥¹¼ôÁÉÁÉ}ÁÀ¡ÁÁ}É½ÕÁ}½¹ÑÉ½°õÁÁ}É½ÕÁ}½¹ÑÉ½°¤(Í¥¹ÑÕÉôÍÕÁÉ½ÍÌ¹ÉÕ¸ (l½Í¥¸°µ°´µ¹Ñ¥Ñ±µ¹ÑÌ°è´°ÍÑÈ¡ÁÀ¥t°(ÑáÐõQÉÕ°(ÍÑ½ÕÐõÍÕÁÉ½ÍÌ¹A%A°(ÍÑÉÈõÍÕÁÉ½ÍÌ¹MQ=UP°(¡¬õ±Í°(¤(¡ÉÍÕ±Ñ}¥È¼½Í¥¸µ¹Ñ¥Ñ±µ¹ÑÌ¹ÑáÐ¤¹ÝÉ¥Ñ}ÑáÐ¡Í¥¹ÑÕÉ¹ÍÑ½ÕÐ°¹½¥¹ôÕÑ´à¤(Ù¥ôÍ±Ñ}Í¥µÕ±Ñ½È ¤(Õ¥ôÙ¥lÕ¥t(ÍÕÁÉ½ÍÌ¹ÉÕ¸¡láÉÕ¸°Í¥µÑ°°½½Ð°Õ¥t°¡¬õ±Í¤(ÍÕÁÉ½ÍÌ¹ÉÕ¸¡láÉÕ¸°Í¥µÑ°°½½ÑÍÑÑÕÌ°Õ¥°µt°¡¬õQÉÕ¤(ÍÕÁÉ½ÍÌ¹ÉÕ¸¡láÉÕ¸°Í¥µÑ°°Õ¹¥¹ÍÑ±°°Õ¥°	U91}%t°¡¬õ±Í¤(ÍÕÁÉ½ÍÌ¹ÉÕ¸¡láÉÕ¸°Í¥µÑ°°¥¹ÍÑ±°°Õ¥°ÍÑÈ¡ÁÀ¥t°¡¬õQÉÕ¤(±Õ¹¡}½ÕÑÁÕÐô½ÕÑÁÕÐ áÉÕ¸°Í¥µÑ°°±Õ¹ °Õ¥°	U91}%¤(µÑ ôÉ¹ÍÉ ¡ÈéqÌ¨¡lÀ´åt¬¤°±Õ¹¡}½ÕÑÁÕÐ¤(¥¹½ÐµÑ è(É¥ÍIÕ¹Ñ¥µÉÉ½È Í¥µÑ°¥¹½ÐÉÑÕÉ¸¸ÁÁ±¥Ñ¥½¸ÁÉ½ÍÌ¥¤(Á¥ô¥¹Ð¡µÑ ¹É½ÕÀ Ä¤¤(Íµ½­}Ý¥¹½Ý}Í½¹ÌôÌÀ(Ñ¥µ¹Í±À¡Íµ½­}Ý¥¹½Ý}Í½¹Ì¤(ÁÉ½ÍÍÌô½ÕÑÁÕÐ áÉÕ¸°Í¥µÑ°°ÍÁÝ¸°Õ¥°½¥¸½ÁÌ°µà¤(¥¹½ÐÉ¹ÍÉ ¡ÈyqÌ¨¬ÍÑÈ¡Á¥¤¬ÈqÌ°ÁÉ½ÍÍÌ°É¹5U1Q%1%9¤è(É¥ÍIÕ¹Ñ¥µÉÉ½È åÕÉ´ÁÉ½ÍÌá¥ÑÕÉ¥¹Ñ¡Í¥µÕ±Ñ½ÈÍµ½­Ý¥¹½Ü¤(ÍÉ¹Í¡½ÐôÉÍÕ±Ñ}¥È¼åÕÉ´µÍ¥µÕ±Ñ½È¹Á¹(ÍÕÁÉ½ÍÌ¹ÉÕ¸¡láÉÕ¸°Í¥µÑ°°¥¼°Õ¥°ÍÉ¹Í¡½Ð°ÍÑÈ¡ÍÉ¹Í¡½Ð¥t°¡¬õQÉÕ¤(±½}ÁÑ ôÉÍÕ±Ñ}¥È¼åÕÉ´µÍ¥µÕ±Ñ½È¹±½(Ý¥Ñ ±½}ÁÑ ¹½Á¸ Ü°¹½¥¹ôÕÑ´à¤ÌÑÉÐè(ÍÕÁÉ½ÍÌ¹ÉÕ¸¡l(áÉÕ¸°Í¥µÑ°°ÍÁÝ¸°Õ¥°±½°Í¡½Ü°´µÍÑå±°½µÁÐ°(´µ±ÍÐ°É´°´µÁÉ¥Ñ°ÁÉ½ÍÌôôQ±É´°(t°ÍÑ½ÕÐõÑÉÐ°ÍÑÉÈõÍÕÁÉ½ÍÌ¹MQ=UP°ÑáÐõQÉÕ°¡¬õ±Í¤(½Áå}ÉÕ¹Ñ¥µ}¥¹½ÍÑ¥Ì¡Õ¥°ÉÍÕ±Ñ}¥È°ÁÁ}É½ÕÁ}½¹ÑÉ½°¤(ÉÍÕ±Ðôì(½µµ¥Ðè½ÕÑÁÕÐ ¥Ð°ÉØµÁÉÍ°!¤°(Ù¥èÙ¥l¹µt°(Õ¥èÕ¥°(Õ¹±}¥è	U91}%°(¥ÍÁ±å}¹µè¥¹¼¹Ð 
	Õ¹±¥ÍÁ±å9µ¤°(ÍÕÁÁ½ÉÑ}Á±Ñ½ÉµÌè¥¹¼¹Ð 
	Õ¹±MÕÁÁ½ÉÑA±Ñ½ÉµÌ¤°(±Õ¹¡}½ÕÑÁÕÐè±Õ¹¡}½ÕÑÁÕÐ°(Íµ½­}Ý¥¹½Ý}Í½¹ÌèÍµ½­}Ý¥¹½Ý}Í½¹Ì°(Á¥}ÑÉ}Íµ½­}Ý¥¹½ÜèÁ¥°(ÍÉ¹Í¡½ÐèÍÉ¹Í¡½Ð¹¹µ°(µ½èµ½°(ÁÁ}É½ÕÁ}½¹ÑÉ½±}¹Ñ¥Ñ±µ¹ÐèÁÁ}É½ÕÁ}½¹ÑÉ½°°(Ù¥}¥¹ÍÑ±±Ñ¥½¹}ÑÍÑè±Í°(Í¥µÕ±Ñ½É}±Õ¹¡}ÑÍÑèQÉÕ°(ô(¡ÉÍÕ±Ñ}¥È¼Í¥µÕ±Ñ½ÈµÉÍÕ±Ð¹©Í½¸¤¹ÝÉ¥Ñ}ÑáÐ¡©Í½¸¹ÕµÁÌ¡ÉÍÕ±Ð°¥¹¹ÐôÈ¤¬q¸°¹½¥¹ôÕÑ´à¤(ÁÉ¥¹Ð¡µ½¬±Õ¹ Éµ¥¹±¥Ù½È¬ÍÑÈ¡Íµ½­}Ý¥¹½Ý}Í½¹Ì¤¬Í½¹ÌìÁ¥ô¬ÍÑÈ¡Á¥¤¤(()¥}}¹µ}|ôô}}µ¥¹}|è(½Ì¹¡¥È¡I==P¤(ÑÉäè(¥±¸¡ÍåÌ¹ÉØ¤ôôÈ¹ÍåÌ¹ÉÙlÅtôôÕ¥±è(Õ¥± ¤(±¥±¸¡ÍåÌ¹ÉØ¤ôôÌ¹ÍåÌ¹ÉÙlÅtôô±Õ¹ ¹ÍåÌ¹ÉÙlÉt¥¸ Í¥±½°ÁÁÉ½ÕÀµ½¹ÑÉ½°¤è(±Õ¹ ¡ÍåÌ¹ÉÙlÉt¤(±Íè(É¥ÍIÕ¹Ñ¥µÉÉ½È UÍèåÕÉµ}Í¥µÕ±Ñ½É}¤¹ÁäÕ¥±ð±Õ¹ Í¥±½ñÁÁÉ½ÕÀµ½¹ÑÉ½°¤(áÁÐIÕ¹Ñ¥µÉÉ½ÈÌÉÉ½Èè(ÁÉ¥¹Ð èéÉÉ½Èèè¬ÍÑÈ¡ÉÉ½È¤¤(ÍåÌ¹á¥Ð Ä¤(áÁÐáÁÑ¥½¸è(ÁÉ¥¹Ð èéÉÉ½ÈèéM¥µÕ±Ñ½ÈÍµ½­ÑÍÐ¥±ì¹¼±Õ¹ ÍÕÍÌ¥Ì±¥µ¸¤(ÍåÌ¹á¥Ð Ä¤
