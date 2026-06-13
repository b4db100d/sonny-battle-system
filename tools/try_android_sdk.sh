#!/usr/bin/env bash
# Best-effort Android toolchain setup for headless APK export.
# Downloads Godot export templates (GitHub) and the Android command-line
# tools (dl.google.com). On networks where dl.google.com is blocked this
# fails at the SDK step — follow docs/ANDROID_EXPORT.md locally instead.
set -uo pipefail

GODOT_VERSION="4.4.1-stable"
TEMPLATE_VERSION="4.4.1.stable"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/$TEMPLATE_VERSION"
SDK_ROOT="$HOME/android-sdk"

echo "==> Step 1/4: Godot export templates"
if [ -f "$TEMPLATES_DIR/android_debug.apk" ]; then
    echo "Templates already installed."
else
    mkdir -p "$TEMPLATES_DIR"
    TPZ_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
    echo "Downloading export templates (~900 MB)..."
    if ! curl -sL -o /tmp/templates.tpz "$TPZ_URL"; then
        echo "FAILED to download export templates."
        exit 1
    fi
    unzip -o -q /tmp/templates.tpz -d /tmp/godot-templates
    mv /tmp/godot-templates/templates/* "$TEMPLATES_DIR/"
    rm -rf /tmp/templates.tpz /tmp/godot-templates
    echo "Templates installed to $TEMPLATES_DIR"
fi

echo "==> Step 2/4: Android command-line tools"
CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
if [ -d "$SDK_ROOT/cmdline-tools/latest" ]; then
    echo "cmdline-tools already installed."
elif curl -fsL -o /tmp/cmdline-tools.zip "$CMDLINE_URL"; then
    mkdir -p "$SDK_ROOT/cmdline-tools"
    unzip -o -q /tmp/cmdline-tools.zip -d "$SDK_ROOT/cmdline-tools"
    mv "$SDK_ROOT/cmdline-tools/cmdline-tools" "$SDK_ROOT/cmdline-tools/latest"
    rm /tmp/cmdline-tools.zip
else
    echo "FAILED: dl.google.com unreachable (expected on restricted networks)."
    echo "Run the remaining steps locally — see docs/ANDROID_EXPORT.md."
    exit 1
fi

echo "==> Step 3/4: SDK packages + debug keystore"
yes | "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK_ROOT" \
    "platform-tools" "build-tools;34.0.0" "platforms;android-34" || exit 1
KEYSTORE="$HOME/.android/debug.keystore"
if [ ! -f "$KEYSTORE" ]; then
    mkdir -p "$HOME/.android"
    keytool -genkeypair -keyalg RSA -alias androiddebugkey -keypass android \
        -storepass android -keystore "$KEYSTORE" \
        -dname "CN=Android Debug,O=Android,C=US" -validity 9999
fi

echo "==> Step 4/4: Godot editor settings + export"
EDITOR_SETTINGS="$HOME/.config/godot/editor_settings-4.4.tres"
mkdir -p "$(dirname "$EDITOR_SETTINGS")"
if [ ! -f "$EDITOR_SETTINGS" ]; then
    cat > "$EDITOR_SETTINGS" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK_ROOT"
export/android/debug_keystore = "$KEYSTORE"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOF
fi
mkdir -p "$ROOT/build"
"$ROOT/.godot-bin/godot" --headless --path "$ROOT" --export-debug "Android" \
    "$ROOT/build/static-protocol-debug.apk"
echo "APK at build/static-protocol-debug.apk"
