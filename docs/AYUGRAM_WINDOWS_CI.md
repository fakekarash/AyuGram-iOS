# AyuGram iOS bootstrap from Windows

This repository can be edited on Windows, but an iOS device build cannot be
compiled on Windows. Apple SDKs, Xcode and the signing tools require macOS. The
manual GitHub Actions workflow in `.github/workflows/ayugram-smoke-ipa.yml`
provides a macOS smoke build without publishing a release.

## Local repository checks

Run these commands from the repository root:

```powershell
git status --short --branch
git submodule status --recursive
Get-Content versions.json
```

On Windows, this source tree contains paths that exceed the legacy path limit.
Enable long paths for this clone before checkout or submodule initialization:

```powershell
git config core.longpaths true
```

## Manual smoke build

1. Fork this repository to a public GitHub repository.
2. Keep the fork's source public and preserve the applicable license notices.
3. Add Actions secrets named `TELEGRAM_API_ID` and `TELEGRAM_API_HASH`, using
   credentials created for your own application at `https://my.telegram.org/apps`.
4. Open Actions, select **AyuGram iOS smoke IPA**, and choose **Run workflow**.
5. Only after the job succeeds, download the seven-day artifact from the run.

The workflow intentionally does not run on every push, create a GitHub Release,
or use an Apple account. It uses the fake signing material already present in
the upstream source so that Bazel can produce an intermediate IPA. The resulting
IPA must be re-signed by each user with AltStore, SideStore, Sideloadly, or an
equivalent tool.

The smoke workflow retains Telegram's upstream bundle/team identifiers only
because the upstream fake provisioning profiles are bound to those identifiers.
It is not a final AyuGram release configuration. Do not distribute the artifact
as AyuGram until the name, icon, bundle identifiers, legal notices, privacy
review, and AyuGram features have been implemented and verified.

## Real development signing

Copy `build-system/ayugram-development-configuration.example.json` to
`build-system/ayugram-development-configuration.json` and replace every
placeholder. The non-example filename is ignored by Git so credentials are not
committed accidentally. On a Mac signed into Xcode, generate a project with:

```bash
python3 build-system/Make/Make.py \
  --cacheDir="$HOME/telegram-bazel-cache" \
  generateProject \
  --configurationPath=build-system/ayugram-development-configuration.json \
  --xcodeManagedCodesigning
```

Creating a device IPA with a custom bundle ID in unattended CI additionally
requires matching certificates and provisioning profiles. Never commit a `.p12`
file, its password, an Apple session, or an app-specific password to the repo.

## Known distribution limits

- A free Apple Personal Team profile expires after seven days and must be
  refreshed. Apple also limits free provisioning to three installed apps per
  device and ten registered App IDs in a seven-day period.
- Telegram embeds several app extensions. Every extension can consume an App ID
  during re-signing, so free-account signing may need extensions removed. Some
  capabilities (for example push notifications, iCloud, Siri, app groups, and
  associated domains) can be unavailable or changed after free re-signing.
- Publishing an IPA file does not make it permanently installable. Each user
  still needs their own Apple signing identity, and a paid Apple Developer
  membership is required for normal App Store/TestFlight distribution.
- The project is large. A cold GitHub-hosted macOS build can approach runner
  time or storage limits. Avoid automatic builds until one manual run has
  established the actual duration and artifact size.

