# Releasing DrGodly (Android)

## 1. One-time setup: the upload key

The Play Store needs every release signed with the same private key.
Create it once and keep it safe: if you lose it, you cannot update the app.

```bash
keytool -genkey -v -keystore ~/drgodly-upload.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (it is gitignored, so never commit it):

```properties
storeFile=/home/<you>/drgodly-upload.jks
storePassword=<password>
keyAlias=upload
keyPassword=<password>
```

Without this file, release builds are signed with the debug key. Such a
build is fine for testing, but the Play Store rejects it. The Gradle output
then prints `WARNING: android/key.properties not found`.

Back up the `.jks` file and both passwords somewhere safe, outside the repo.

## 2. Each release

1. Raise the version in `pubspec.yaml`: `version: 1.2.3+N`. `1.2.3` is what
   users see; `N` (the build number) must be higher than the last upload.
2. Run the checks:
   ```bash
   flutter analyze
   flutter test        # includes layout and accessibility checks for every screen
   ```
3. Build:
   ```bash
   flutter build appbundle --release   # for the Play Store (.aab)
   flutter build apk --release         # for installing directly on a phone
   ```
   Outputs:
   - `build/app/outputs/bundle/release/app-release.aab`
   - `build/app/outputs/flutter-apk/app-release.apk`
4. Test the APK on a real phone (see the checklist below), then upload
   the `.aab` in Play Console.

## 3. Phone checklist before every release

- [ ] Cold start: launch screen, then the 4.5 s brand intro, then Welcome or Home
- [ ] Sign in and sign out (the profile photo is removed on sign-out)
- [ ] Home, Vitals (Health Connect sync), Doctors, Profile tabs; back goes to Home
- [ ] Book, move and cancel a visit; chat and voice intake
- [ ] Phone in dark mode: every screen readable
- [ ] Phone text size at maximum: nothing cut off
- [ ] TalkBack on: the main flows can be done by voice alone
- [ ] Airplane mode: clear error messages, no fake data

## 4. What CI checks

`.github/workflows/ci.yml` runs on every push and pull request to `main`:
analyze (infos count as errors), all tests, and a release APK (debug-signed),
which you can download from the run's artifacts.

## 5. App icon

- Source files: `assets/app_logo.jpeg` (legacy icon) and
  `assets/launcher/icon_foreground.png` (adaptive icon, Android 8+).
- Background colour: `adaptive_icon_background` in `pubspec.yaml`.
- To regenerate: `dart run flutter_launcher_icons`. Afterwards, add
  `<monochrome android:drawable="@drawable/ic_launcher_foreground"/>` to
  `android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml` again
  (Android 13+ themed icons), and revert the `ios/` changes the tool makes.
