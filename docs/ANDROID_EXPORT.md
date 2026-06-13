# Exporting the Android APK

The repository ships a ready-to-use Android export preset
(`export_presets.cfg`: ARM64, landscape, immersive, package
`com.auho.staticprotocol`). Producing the APK needs the Godot export
templates and an Android SDK, which must be installed once on your machine.

## Quick path (automated)

On a machine with unrestricted network access:

```bash
tools/setup_godot.sh        # downloads Godot 4.4.1 headless to .godot-bin/
tools/try_android_sdk.sh    # templates + SDK + keystore + export
```

If that succeeds you'll have `build/static-protocol-debug.apk`. Install it:

```bash
adb install build/static-protocol-debug.apk
```

## Manual path (editor)

1. **Install Godot 4.4.1** (must match exactly — export templates are
   version-locked): <https://godotengine.org/download/archive/4.4.1-stable/>
2. **Install export templates**: Editor → *Editor* menu → *Manage Export
   Templates...* → Download and Install. (Or download
   `Godot_v4.4.1-stable_export_templates.tpz` from the GitHub release and
   choose *Install from file*.)
3. **Install the Android SDK** — either Android Studio, or just the
   command-line tools:

   ```bash
   # with cmdline-tools unzipped to ~/android-sdk/cmdline-tools/latest
   sdkmanager --sdk_root=$HOME/android-sdk \
       "platform-tools" "build-tools;34.0.0" "platforms;android-34"
   ```

4. **Create a debug keystore** (skip if `~/.android/debug.keystore` exists):

   ```bash
   keytool -genkeypair -keyalg RSA -alias androiddebugkey -keypass android \
       -storepass android -keystore ~/.android/debug.keystore \
       -dname "CN=Android Debug,O=Android,C=US" -validity 9999
   ```

5. **Point Godot at them**: Editor → *Editor Settings* → *Export > Android*:
   - *Android SDK Path* → your SDK root
   - *Debug Keystore* → `~/.android/debug.keystore`, user
     `androiddebugkey`, password `android`
6. **Export**: *Project → Export… → Android → Export Project*, or headless:

   ```bash
   godot --headless --path . --export-debug "Android" build/static-protocol-debug.apk
   ```

## Release builds

For Play-store/release builds, generate a real keystore, fill in the
release keystore fields in Editor Settings, bump `version/code` and
`version/name` in `export_presets.cfg`, and use `--export-release`.
Consider `gradle_build/export_format=1` (AAB) for Play submission.

## Troubleshooting

- **"No export template found"** — template version must match the editor
  version exactly (4.4.1.stable).
- **"Unable to find Android SDK / adb"** — check *Android SDK Path*; it must
  contain `platform-tools/adb`.
- **Invalid keystore** — re-run the `keytool` command above; passwords in
  Editor Settings must match (`android`/`android` for debug).
- **Black screen on device** — the project uses the `gl_compatibility`
  renderer which works on virtually all devices; if you changed the
  renderer, change it back in `project.godot`.
