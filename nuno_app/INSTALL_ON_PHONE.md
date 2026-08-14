# Installing Nuno on your phone

The app is built for phones — this is the intended way to run it.

You have two options. **Option A** is best while developing (hot reload).
**Option B** gives you a standalone APK you can install and share.

---

## Before either option: patch the Android manifest

Run this once, from the `nuno_app` folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\fix_android.ps1
```

It adds `android.permission.INTERNET` to the manifest. **This matters:** Flutter
only puts that permission in the debug and profile manifests, so a *release*
APK builds and installs fine but has **no network access at all** — the app
would sit forever on "Waking the server…". The script also enables cleartext
HTTP in case you later point at a local backend.

> On macOS/Linux `./setup.sh` already did this.

---

## Option A — Run directly from your PC (recommended)

Best while developing: hot reload, and you see logs in the terminal.

### 1. Enable Developer options on the phone

1. **Settings → About phone**
2. Tap **Build number** seven times ("You are now a developer!")
3. Go back → **System → Developer options**
4. Turn on **USB debugging**

*Samsung: Settings → About phone → Software information → Build number.*
*Xiaomi: Settings → About phone → MIUI version.*

### 2. Connect by USB

Plug in the phone. A prompt appears on the phone:
**"Allow USB debugging?"** → tick *Always allow* → **OK**.

If no prompt appears, pull down the notification shade, tap the USB
notification and change the mode from *Charging* to **File transfer (MTP)**.

### 3. Verify the phone is visible

```powershell
flutter devices
```

Your phone should now be listed alongside Windows/Chrome/Edge.

### 4. Run

```powershell
flutter run
```

If several devices are connected, pick your phone from the numbered list, or
target it directly:

```powershell
flutter devices                      # copy the device id
flutter run -d <device-id>
```

Hot reload with **`r`**, hot restart with **`R`**, quit with **`q`**.

---

## Option B — Build a standalone APK

Install without a cable, and share the file with friends for testing.

```powershell
flutter build apk --release
```

Output:

```
build\app\outputs\flutter-apk\app-release.apk
```

### Smaller downloads (optional)

A universal APK carries every CPU architecture. To emit one per architecture
(roughly 40% smaller each):

```powershell
flutter build apk --split-per-abi
```

Then use `app-arm64-v8a-release.apk` — correct for essentially all phones from
the last several years.

### Getting the APK onto the phone

Any of these work:

* **USB** — copy the file to the phone, then open it with a file manager
* **Google Drive / email it to yourself** — download it on the phone and tap
* **`adb install`** — `adb install build\app\outputs\flutter-apk\app-release.apk`

On first open Android will warn about installing from an unknown source.
Allow it for your browser or file manager, then tap **Install**.

> The APK is unsigned for the Play Store — fine for sideloading and testing,
> but you'd need a signing key to publish it.

---

## Wireless debugging (Android 11+, no cable)

1. Phone: **Developer options → Wireless debugging → On**
2. Tap **Pair device with pairing code** — note the IP, port and code
3. On your PC:

```powershell
adb pair 192.168.1.50:37021        # enter the 6-digit code when asked
adb connect 192.168.1.50:37019     # the port under "Wireless debugging"
flutter devices
flutter run
```

The two ports differ — pairing uses one, connecting another.

---

## Notes

* **Landscape.** The UI is landscape-only and will rotate itself. Make sure the
  phone's auto-rotate lock is off.
* **No backend setup needed.** The app points at
  `https://nuno-backend-by35.onrender.com` by default, over HTTPS, from
  anywhere — you do not have to be on the same network as your PC.
* **First launch is slow.** Render's free tier sleeps after ~15 minutes idle;
  the splash shows "Waking the server…" for up to a minute, then it's fast.
* **Playing a real match needs two players.** Install on two phones, or pair a
  phone with the Windows build, and use Create Room → share the code →
  Join Room.

---

## Troubleshooting

**`flutter devices` doesn't list the phone**
Confirm USB debugging is on and you accepted the prompt. Try a different cable —
many are charge-only and carry no data. Then `adb kill-server; adb devices`.

**"device unauthorized"**
The prompt was dismissed. Developer options → **Revoke USB debugging
authorizations**, unplug, replug, accept.

**App installs but hangs on "Waking the server…"**
Missing INTERNET permission — run `fix_android.ps1`, then rebuild. Otherwise
check the backend is up:
`https://nuno-backend-by35.onrender.com/api/v1/health`

**"App not installed" when sideloading**
Usually an older copy with the same package name — uninstall it first.

**Windows desktop build fails: `Cannot open include file: 'atlstr.h'`**
Unrelated to Android. `flutter_secure_storage` needs the Visual Studio **C++
ATL** component for the *Windows desktop* target. Either ignore it and run on
the phone, or install it: open **Visual Studio Installer → Modify → Individual
components**, tick **"C++ ATL for latest v143 build tools (x86 & x64)"**,
install, then reopen your terminal.

**Gradle or build errors on first APK build**
The first Android build downloads a lot. If it fails, `flutter clean` and retry;
make sure you have a working JDK (`flutter doctor` reports this).
