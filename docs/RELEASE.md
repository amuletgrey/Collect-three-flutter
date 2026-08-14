# Releasing Tessera

Identity, artifacts, signing and CI. Read this before touching `android/`, `ios/`,
`web/`, `windows/` or `.github/workflows/`.

## Identity

| Field | Value |
| --- | --- |
| App name | **Tessera** |
| Tagline | Line up the mosaic. |
| Dart package | `tessera` |
| Android `applicationId` / namespace | `com.vibebyteforge.tessera` |
| iOS bundle id | `com.vibebyteforge.tessera` |
| Windows binary | `tessera.exe` |
| Publisher | VibeByteForge |
| Play developer id | `4878428078632637194` |
| Account owner | byteforge1248@gmail.com |

The Play developer page is
`https://play.google.com/store/apps/dev?id=4878428078632637194`. There is no Play
*application* id yet — Play assigns nothing extra; the listing is keyed on
`com.vibebyteforge.tessera`, which is fixed forever once the first upload lands.
**Get it right before the first upload.**

## Artifacts

`.github/workflows/release.yml` builds all of these on every push to `main`, on
any `v*` tag, and on demand from the Actions tab.

| Platform | Artifact | Notes |
| --- | --- | --- |
| Android | `tessera-<v>-armeabi-v7a.apk` | 32-bit ARM, ~13 MB |
| Android | `tessera-<v>-arm64-v8a.apk` | 64-bit ARM, ~16 MB — almost every modern phone |
| Android | `tessera-<v>-x86_64.apk` | emulators, ~17 MB |
| Android | `tessera-<v>-universal.apk` | all three ABIs, ~44 MB — sideloading when you don't know the target |
| Android | `tessera-<v>.aab` | **the Play upload**, all ABIs/languages/densities |
| Web | `tessera-<v>-web.zip` | static bundle, serve at any base href |
| Windows | `tessera-<v>-windows-x64.zip` | portable; unzip and run `tessera.exe` |

Version comes from the tag (`v1.2.0` → `1.2.0`) or from `pubspec.yaml` otherwise;
the build number is always the workflow run number, which is monotonic and is what
Play requires of `versionCode`.

iOS is deliberately not built. The folder carries the right bundle id, but there
is no Apple account, no signing material and no macOS runner in the matrix. Adding
it is a job in itself — see the M9 notes in `docs/TASKS.md`.

## Signing

The keystore never enters the repository. `android/app/build.gradle.kts` looks for
it in two places, in order:

1. `android/key.properties` — for local release builds (git-ignored).
2. `TESSERA_KEYSTORE_PATH` / `TESSERA_KEYSTORE_PASSWORD` / `TESSERA_KEY_ALIAS` /
   `TESSERA_KEY_PASSWORD` environment variables — for CI.

If neither is present the release build **falls back to the debug key** and says
so in the Gradle log and the workflow summary. Those artifacts run fine and are
useless for Play.

### Creating the keystore — do this yourself

Generating the keystore means choosing and storing passwords, so it is a manual
step; nothing in this repo or in CI should ever hold those in plain text.

```bash
keytool -genkey -v -keystore tessera-release.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias tessera
```

Keep `tessera-release.jks` somewhere backed up and outside the repository. **If it
is lost, no further update to the Play listing can ever be signed** — short of
enrolling in Play App Signing key rotation, which has its own conditions.

Then create `android/key.properties`, which `.gitignore` already excludes:

```properties
storeFile=C:/path/to/tessera-release.jks
storePassword=<the store password you chose>
keyAlias=tessera
keyPassword=<the key password you chose>
```

### CI secrets

Add these four under Settings → Secrets and variables → Actions. Until they exist,
the Android job still succeeds and produces debug-signed artifacts.

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 tessera-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | store password |
| `ANDROID_KEY_ALIAS` | `tessera` |
| `ANDROID_KEY_PASSWORD` | key password |

## Cutting a release

```bash
git tag v1.0.0
git push origin v1.0.0
```

The workflow builds every artifact and opens a GitHub Release with them attached
and generated notes.

## Store assets

`tool/icons/generate_icons.py` writes these into `assets/branding/`:

- `icon_master_1024.png` — the 1024 master, rounded field
- `play_store_512.png` — the Play listing icon
- `play_feature_graphic_1024x500.png` — the Play feature graphic

They are committed, so neither CI nor a fresh clone needs Python or Pillow. Re-run
the script only when the artwork changes, and commit the whole diff — it rewrites
every platform's icons at once, which is the point.

Still to write for the listing itself: short description, full description,
phone/tablet screenshots, content rating questionnaire, privacy policy URL. The
game collects nothing and has no backend, which makes the data-safety form short.

## Gotchas

- **`flutter build appbundle` needs `cmdline-tools`.** Without it the build fails
  with "Release app bundle failed to strip debug symbols from native libraries",
  which points at the NDK and is misleading — the real message is one line up in
  `--verbose`: "Failed to find cmdline-tools". The AAB itself is written correctly
  before the check runs. GitHub's `ubuntu-latest` has cmdline-tools; the CI job
  asserts it up front so the failure is legible. This machine does **not** have it,
  so local `flutter build appbundle` exits non-zero on an otherwise good bundle.
- **The universal APK must carry all three ABIs.** A single-ABI APK installs and
  then dies with `dlopen failed: library "libflutter.so" not found`, which reads
  like a crash rather than a packaging fault. The workflow asserts the ABI list.
- **Renaming the Windows binary needs `build/windows/` deleted.** The cached `CMakeCache.txt`
  keeps the old target, so the next build fails with `No target "collect_three"` even though
  the source no longer mentions it. CI starts from an empty tree and never sees this.
- Release builds mangle resource paths, so `unzip -l app.apk | grep ic_launcher`
  finds nothing even when the icons are fine. Check with
  `aapt2 dump badging app.apk` (shows `label='Tessera'`) and
  `aapt2 dump resources app.apk | grep mipmap/`.
