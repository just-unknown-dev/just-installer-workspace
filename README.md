# Just Installer Workspace

Showcase workspace for [`just_installer`](packages/just_installer) — a
modern, self-hosted APK auto-updater for Flutter with no dependency on
Google Play Store or Play Services — and its companion download engine,
[`just_downloader`](packages/just_downloader).

## Structure

```
packages/just_installer/   The updater: manifest check, sealed-class state
                            machine, Android PackageInstaller Session API
                            install, APK signature verification.
packages/just_downloader/  The generic resumable/chunked download engine,
                            checksum verification, and TLS pinning that
                            just_installer builds on.
lib/                        This showcase app.
  update_config.dart        GitHub Releases hosting config — the only file
                             that knows about a specific repo/token.
  demo_server.dart           Local dev-server fallback (see below).
  main.dart                  The demo UI: a StreamBuilder-driven exhaustive
                             switch over UpdateState.
```

Both packages are consumed via `path:` dependencies (see this project's
`pubspec.yaml`) since neither is published to pub.dev yet.

## Running the showcase app

```
flutter run -d windows   # or chrome / your platform of choice
```

By default `update_config.dart`'s `githubReleaseHost` is left blank, so the
app falls back to `demo_server.dart` — a local HTTP server bundled into the
app that serves a placeholder update artifact
(`assets/demo/sample-update.bin`) and a matching `manifest.json`. This
proves the full check → download → checksum-verify pipeline on any
platform without needing a real backend, but it is **not** a real APK, so
the install step only makes sense once you point the app at a real release
(see below) and run it on Android.

## Publishing a real demo release

To exercise the full pipeline for real — including Android's
`PackageInstaller` install and APK signature verification — you need an
actual APK hosted somewhere `just_installer` can reach it. The recommended
free option is GitHub Releases, using the stable
`.../releases/latest/download/<asset-name>` URL pattern (works for public
repos with no auth, and for private repos with a bearer token).

1. **Build a genuinely newer version of this app.** Bump `version` in this
   `pubspec.yaml` (the part after `+` is the version code), then:
   ```
   flutter build apk --debug
   ```
   The output APK is at `build/app/outputs/flutter-apk/app-debug.apk`.
2. **Compute its checksum and write a manifest** (`manifest.json`):
   ```json
   {
     "version": "1.1.0",
     "versionCode": 2,
     "downloadUrl": "https://github.com/<owner>/<repo>/releases/latest/download/app-debug.apk",
     "sha256": "<sha256 of app-debug.apk>",
     "size": 12345678,
     "releaseNotes": "Demo release",
     "mandatory": false
   }
   ```
   `signingCertSha256` is optional — set it to the SHA-256 of the signing
   certificate (the debug keystore's, for a debug build) if you want to
   exercise the signature-verification step too.
3. **Publish both files as assets on a GitHub Release** in your own repo
   (e.g. via `gh release create v1.1.0 app-debug.apk manifest.json`). This
   is an external, visible action — do it deliberately, not as part of a
   routine build.
4. **Point the app at it**: fill in `githubReleaseHost` in
   `lib/update_config.dart` with your `owner`/`repo` (and `token` if the
   repo is private).
5. Rebuild the **older** version of the app (lower version code) and run it
   on a real Android device — `flutter run -d <device>` — then use "Check
   for update" to drive the full pipeline against your real release.

## Testing

```
cd packages/just_downloader && flutter test
cd packages/just_installer && flutter test
```

Both suites run without a device (mocked HTTP clients and fakes for the
platform interface / storage). The Android install flow itself
(PackageInstaller session, confirmation dialog, Device-Owner silent path)
can only be verified manually on a real device or emulator — see
`packages/just_installer`'s implementation notes for the on-device
checklist.

## Platform support

| Platform | Check for update | Download + verify | Install |
| --- | --- | --- | --- |
| Android | ✅ | ✅ | ✅ (Session API, optional silent MDM path) |
| Windows / macOS / Linux | ✅ | ✅ | Manual — verified file is handed to the user to run/reveal, never auto-launched |
| iOS | ✅ | — | Unsupported in this version (Apple doesn't allow sideloaded installs outside the App Store) |
| Web | ✅ | — | Unsupported (no install concept) |
