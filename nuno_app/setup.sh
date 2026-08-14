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
# Not needed for the hosted https:// backend, but harmless and saves pain
# if you later point at a local server over plain http://.
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

# ── 5b. Launcher icons ───────────────────────────────────────
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  SRC="assets/launcher/ic_launcher_$d.png"
  DST="android/app/src/main/res/mipmap-$d"
  if [ -f "$SRC" ] && [ -d "$DST" ]; then
    cp "$SRC" "$DST/ic_launcher.png"
  fi
done
echo "--- Launcher icons installed ---"

# ── 6. Sanity check ──────────────────────────────────────────
echo
echo "--- Analyzing ---"
flutter analyze || echo "(analyzer reported issues — see above)"

cat <<'EOF'

=== Setup complete ===

The app defaults to the hosted backend, so just run:

  flutter run

In VS Code, press F5 and choose "Nuno (hosted backend — default)".

To use a local backend instead:

  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000     # Android emulator
  flutter run --dart-define=API_BASE_URL=http://localhost:3000    # iOS sim / desktop

NOTES
  * The app is LANDSCAPE-only — use a landscape emulator/device.
  * The hosted backend is on a free tier that sleeps when idle. The first
    launch may sit on "Waking the server..." for up to a minute.
EOF
