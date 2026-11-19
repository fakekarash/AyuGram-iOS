#!/usr/bin/env bash
# Build a re-signable AyuGram IPA on a local Mac.
#
# Requirements: macOS with Xcode (26.x), python3, git, and the two credentials
# in the environment:
#
#   export TELEGRAM_API_ID=1234567
#   export TELEGRAM_API_HASH=0123456789abcdef0123456789abcdef
#   ./build-system/build_sideload_on_mac.sh
#
# The result is build/ayugram-sideload/AyuGram.ipa plus manifest.json. The IPA
# still has to be re-signed with your own Apple identity before installing.
#
# Set AYUGRAM_ALLOW_UNPINNED=1 if your Xcode/macOS differs from versions.json.
set -euo pipefail

cd "$(dirname "$0")/.."

: "${TELEGRAM_API_ID:?set TELEGRAM_API_ID to the api_id of your Telegram application}"
: "${TELEGRAM_API_HASH:?set TELEGRAM_API_HASH to the api_hash of your Telegram application}"

export AYUGRAM_LOCAL_BUILD=1

echo "== toolchain =="
python3 build-system/ayugram_ci.py preflight

echo "== submodules =="
git config submodule.submodules/rlottie/rlottie.url https://github.com/TelegramMessenger/rlottie.git
git config submodule.submodules/TgVoipWebrtc/tgcalls.url https://github.com/TelegramMessenger/tgcalls.git
git submodule update --init --recursive --jobs 4
git submodule status --recursive > "${TMPDIR:-/tmp}/ayugram-submodules.txt"
if grep -Eq '^[-+U]' "${TMPDIR:-/tmp}/ayugram-submodules.txt"; then
    echo "a submodule is missing, conflicted or at the wrong revision" >&2
    exit 1
fi

echo "== profiles =="
python3 build-system/renew_fake_profiles.py --check

echo "== sideload patches =="
python3 build-system/ayugram_sideload_ci.py patch

echo "== build (this takes ~40-60 minutes on a cold cache) =="
python3 -u build-system/ayugram_sideload_ci.py build

echo "== verify =="
python3 build-system/ayugram_sideload_ci.py verify

echo
echo "IPA:  build/ayugram-sideload/AyuGram.ipa"
echo "Info: build/ayugram-sideload/manifest.json"
echo "Re-sign it with AltStore, SideStore, Sideloadly or Xcode before installing."
