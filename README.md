# task3 — Calculator • Scan • Records

A 3-page Flutter app:

1. **Calculator** — a basic keypad in portrait that automatically becomes a
   scientific keypad when the device is tilted into landscape (DEG/RAD toggle,
   trig, logs, roots, powers, constants).
2. **Scan** — take a photo (or pick one from the gallery) and extract the
   numbers it contains using on-device ML Kit text recognition. Captured numbers
   can be sent straight into the calculator, edited, or typed manually.
3. **Records** — every calculation and scan is saved and browsable, with search,
   type filters, detail sheets, swipe-to-delete and bulk clearing.

All history is persisted locally with `shared_preferences`.

## Project structure

```
lib/
├── main.dart                     # App root + 3-tab shell
├── models/
│   └── app_record.dart           # Persisted calculation / scan record
├── pages/
│   ├── calculator_page.dart      # Page 1 (basic ↔ scientific)
│   ├── scan_page.dart            # Page 2 (camera / gallery + OCR)
│   └── records_page.dart         # Page 3 (history)
└── services/
    ├── calculator_engine.dart    # Expression parsing / evaluation
    ├── ocr_service.dart          # ML Kit wrapper + number extraction
    └── record_repository.dart    # Persistent history storage
```

## Getting started

```bash
flutter pub get
flutter run
```

## Platform notes

- **OCR** uses `google_mlkit_text_recognition`, which only ships native
  implementations for **Android, iOS and macOS**. On other platforms the scan
  page falls back to manual number entry.
- **Android:** `minSdk` is set to 24; the `CAMERA` permission is declared in
  `android/app/src/main/AndroidManifest.xml`.
- **iOS:** deployment target is 15.5 (ML Kit requirement), camera and photo
  library usage descriptions are set in `ios/Runner/Info.plist`, and the Podfile
  excludes the 32-bit `armv7` architecture.

## Tests

```bash
flutter test      # engine + number extraction + app boot
flutter analyze
```

## Building an iPhone (.ipa) with GitHub Actions

The workflow at `.github/workflows/build-ios.yml` builds an **.ipa** on a macOS
runner and uploads it as a build artifact (and attaches it to the GitHub Release
when you push a `v*` tag).

### Unsigned IPA (no Apple account needed — default)

Just push to GitHub and run the workflow. By default it produces an unsigned
IPA (`task3-ipa-unsigned`) that you can sideload/re-sign with tools like
AltStore, Sideloadly or TrollStore.

### Signed IPA (distribution)

Add these to **Settings → Secrets and variables → Actions**:

**Variables** (the *Variables* tab):

| Variable | Description |
|----------|-------------|
| `APPSTORE_ISSUER_ID` | App Store Connect API Issuer ID |
| `APPSTORE_API_KEY_ID` | App Store Connect API Key ID |
| `TEAM_ID` | Your Apple Developer Team ID (10 chars) |
| `BUNDLE_ID` | Optional. Overrides `com.example.task3` (must have a matching profile) |

**Secrets** (the *Secrets* tab):

| Secret | Description |
|--------|-------------|
| `APPSTORE_API_PRIVATE_KEY` | Contents of the `.p8` API key |
| `APPSTORE_CERTIFICATES_FILE_BASE64` | Base64 of your exported `.p12` signing cert |
| `APPSTORE_CERTIFICATES_PASSWORD` | Password for the `.p12` |

Then run the workflow manually with **unsigned = false** (Actions → Build iOS
IPA → Run workflow). The signed IPA is uploaded as `task3-ipa-signed`.

> The easiest way to produce the cert/profile secrets is the
> [`download-provisioning-profiles`](https://github.com/Apple-Actions/download-provisioning-profiles)
> `scripts/setup.sh`. Replace `com.example.task3` with your own bundle identifier
> before shipping.

### First push to GitHub

```bash
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```

