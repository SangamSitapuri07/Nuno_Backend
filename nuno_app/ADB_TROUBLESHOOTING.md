# When ADB will not cooperate

Two known-good ways to get the app onto a Vivo phone. **Option A needs no
ADB at all** — start there if USB debugging keeps failing.

---

## Option A — Build an APK and sideload it (most reliable)

```bat
build_apk.bat
```

That produces `nuno.apk` on your Desktop. Send it to the phone however you
like — WhatsApp to yourself, Google Drive, or plain USB file transfer — then
tap it on the phone and install.

**No USB debugging, no ADB, no wireless pairing.**

Trade-off: no hot reload. To see a change, run `build_apk.bat` again and
install over the top. A rebuild is ~2 minutes.

> Charging-only USB cables still work for file transfer if you switch the USB
> mode to **File transfer (MTP)** from the notification shade.

---

## Option B — Fix USB debugging

`INSTALL_FAILED_USER_RESTRICTED` on Vivo, Oppo, Realme and Xiaomi almost always
means one specific toggle is off.

### 1. The Vivo-specific toggle

**Settings → Additional settings → Developer options**, then enable **both**:

- **USB debugging**
- **Install via USB** ← this is the one that blocks installs

Vivo often refuses to let you enable *Install via USB* unless the phone is
online and signed into a vivo account. If the switch flips back off by itself,
connect to Wi-Fi, sign in, and try again.

### 2. Watch the phone while installing

Vivo shows a confirmation dialog on the phone during install. If you miss it,
the install fails with exactly the error you saw. Keep the screen unlocked and
watch for it.

### 3. Clear a stale install

```bat
adb uninstall com.nuno.nuno_app
flutter run
```

### 4. Reset the authorisation

Developer options → **Revoke USB debugging authorizations**, unplug, replug,
then tap **Allow** on the phone.

### 5. Suspect the cable

Many cables are charge-only and carry no data. If the device keeps
disappearing and reappearing, that is the classic symptom — try a different
cable, ideally the one that came with the phone, and a different USB port
(prefer a port directly on the machine, not a hub).

---

## Option C — Wireless debugging

Needs Android 11+. Phone and PC must be on the **same network** — and this is
where most attempts fail.

### The usual culprits

**"Same Wi-Fi" is not always the same network.** These all break it:

- The PC is on Ethernet while the phone is on Wi-Fi
- The router has **AP isolation** / **client isolation** enabled (common on
  guest networks) which blocks device-to-device traffic
- You are on a **guest** SSID, or on 5 GHz while the PC is on 2.4 GHz with
  band separation
- A VPN is active on either device
- Windows treats the network as **Public**, so the firewall blocks it

**Check they can actually see each other.** Find the phone's IP under
*Wireless debugging*, then from the PC:

```powershell
ping 192.168.1.42
```

No reply means it is a network problem, not an ADB problem. Nothing you do in
ADB will help until ping works.

### Fixes

- Set the Windows network to **Private**:
  Settings → Network & Internet → Wi-Fi → your network → **Private**
- Turn off any VPN on both devices
- Use your **phone's hotspot** and connect the laptop to it. This sidesteps
  router isolation entirely and is the fastest fix when a router is the
  problem.

### The two ports are different

```powershell
adb pair 192.168.1.42:37105     # port from the PAIRING dialog
adb connect 192.168.1.42:41235  # port from the MAIN wireless debugging screen
```

The pairing port is temporary and changes each time you open that dialog. The
connect port is on the main screen. Using the wrong one is the single most
common mistake.

### After pairing succeeds but the device shows "offline"

You paired but never connected. Run the `adb connect` line with the port from
the **main** screen.

```powershell
adb devices     # want "device", not "offline" or "unauthorized"
```

If it stays offline, toggle *Wireless debugging* off and on — that issues a new
port, so re-read it before reconnecting.

---

## Recommendation

Use **Option A** for now. It always works, and the two-minute rebuild is a
better trade than losing time to ADB. Once the UI settles down, it is worth
getting Option B or C working for hot reload.
