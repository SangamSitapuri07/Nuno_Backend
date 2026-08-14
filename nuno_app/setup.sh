#!/usr/bin/env bash
#
# Nuno app — one-time setup.
#
#   ./setup.sh
#
# Generates the native platform folders, installs packages, and patches
# Android/iOS so the app may talk to a local backend over plain HTTP.

set -euo pipefail

cd "$(dirname "$0")"

echo "=== Nuno app setup ==="
echo

# ── 1. Flutter present? ──────────────────────────────────────
if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: 'flutter' was not found on your PATH."
  echo "Install Flutter 3.27 or newer: https://docs.flutter.dev/get-started/install"
  exit 1
fi

echo "--- Flutter version ---"
flutter --version
echo

# ── 2. Native platform folders ───────────────────────────────
# The repo ships only lib/, so generate android/, ios/, etc. in place.
if [ ! -d android ] && [ ! -d ios ] && [ ! -d windows ]; then
  echo "--- Generating platform folders ---"
  flutter create --project-name nuno_app --org com.nuno .
else
  echo "--- Platform folders already exist, skipping generate ---"
fi
echo

# ── 3. Packages ──────────────────────────────────────────────
echo "--- Fetching packages ---"
flutter pub get
echo

# ── 4. Allow cleartext HTTP to a local backend (Android) ─────
MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ] && ! grep -q "usesCleartextTraffic" "$MANIFEST"; then
  echo "--- Enabling cleartext HTTP for local dev (Android) ---"
  # Insert the attribute on the <application> tag.
  perl -0pi -e 's/(<application\b)/$1\n        android:usesCleartextTraffic="true"/' "$MANIFEST"
fi

# Android also needs the INTERNET permission for a release build.
if [ -f "$MANIFEST" ] && ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  perl -0pi -e 's/(<manifest\b[^>]*>)/$1\n    <uses-permission android:name="android.permission.INTERNET"\/>/' "$MANIFEST"
fi

# ── 5. Allow cleartext HTTP to a local backend (iOS) ─────────
PLIST="ios/Runner/Info.plist"
if [ -f "$PLIST" ] && ! grep -q "NSAppTransportSecurity" "$PLIST"; then
  echo "--- Enabling cleartext HTTP for local dev (iOS) ---"
  perl -0pi -e 's|(<dict>)|$1\n\t<key>NSAppTransportSecurity</key>\n\t<dict>\n\t\t<key>NSAllowsArbitraryLoads</key>\n\t\t<true/>\n\t</dict>|' "$PLIST"
fi

# ── 6. Sanity check ──────────────────────────────────────────
echo
echo "--- Analyzing ---"
flutter analyze || echo "(analyzer reported issues — see above)"

cat <<'EOF'

=== Setup complete ===

Run the app (the backend must be running):

  # Android emulator — 10.0.2.2 is the host's localhost
  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

  # iOS simulator / desktop
  flutter run --dart-define=API_BASE_URL=http://localhost:3000

  # Physical device — use your machine's LAN IP
  flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000

In VS Code just press F5 and pick a launch configuration.

NOTE: the app is LANDSCAPE-only — use a landscape emulator/device.
EOF
