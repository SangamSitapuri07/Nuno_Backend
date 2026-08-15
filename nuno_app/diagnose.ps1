# Nuno — connection diagnostics.
#
#   cd nuno_app
#   powershell -ExecutionPolicy Bypass -File .\diagnose.ps1
#
# Checks, in order, every layer between the phone and the backend, and prints
# the one thing that is actually wrong instead of a wall of logs.

$ErrorActionPreference = 'Continue'
Set-Location -Path $PSScriptRoot

$base = 'https://nuno-backend-by35.onrender.com'
$fail = 0

function Ok   ($m) { Write-Host "  PASS  $m" -ForegroundColor Green }
function Bad  ($m) { Write-Host "  FAIL  $m" -ForegroundColor Red; $script:fail++ }
function Note ($m) { Write-Host "        $m" -ForegroundColor DarkGray }

Write-Host ""
Write-Host "Nuno connection diagnostics" -ForegroundColor Cyan
Write-Host "===========================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Backend reachable from THIS PC ────────────────────────
Write-Host "[1] Backend health" -ForegroundColor White
try {
    $r = Invoke-WebRequest -Uri "$base/api/v1/health" -TimeoutSec 90 -UseBasicParsing
    if ($r.StatusCode -eq 200) {
        Ok "$base is up"
        Note $r.Content
    } else {
        Bad "health returned HTTP $($r.StatusCode)"
    }
} catch {
    Bad "cannot reach $base from this PC"
    Note $_.Exception.Message
    Note "If this fails, the phone cannot connect either."
}
Write-Host ""

# ── 2. Socket.IO handshake ───────────────────────────────────
Write-Host "[2] Socket.IO handshake" -ForegroundColor White
try {
    $r = Invoke-WebRequest -Uri "$base/socket.io/?EIO=4&transport=polling" -TimeoutSec 90 -UseBasicParsing
    if ($r.Content -match '"sid"') {
        Ok "Socket.IO is accepting connections"
    } else {
        Bad "unexpected handshake body"
        Note $r.Content
    }
} catch {
    Bad "Socket.IO endpoint refused the connection"
    Note $_.Exception.Message
}
Write-Host ""

# ── 3. INTERNET permission ───────────────────────────────────
# The most common cause of a permanent "Connecting to the server..." on a
# real device: without this the socket can never open, and Android gives no
# visible error.
Write-Host "[3] Android INTERNET permission" -ForegroundColor White
$manifest = 'android\app\src\main\AndroidManifest.xml'
if (-not (Test-Path $manifest)) {
    Bad "$manifest is missing — run: flutter create ."
} else {
    $xml = Get-Content $manifest -Raw
    if ($xml -match 'android\.permission\.INTERNET') {
        Ok "INTERNET permission is declared"
    } else {
        Bad "INTERNET permission is MISSING — this alone breaks all networking"
        Note "Fix: git checkout nuno/arena/019fff1a-nuno-backend -- nuno_app/android"
    }
    if ($xml -match 'usesCleartextTraffic') {
        Ok "cleartext traffic allowed (needed only for a local http backend)"
    } else {
        Note "cleartext not enabled — fine for the hosted https backend"
    }
}
Write-Host ""

# ── 4. Device connected ──────────────────────────────────────
Write-Host "[4] Connected devices" -ForegroundColor White
$devices = & flutter devices 2>&1 | Out-String
if ($devices -match 'No devices') {
    Bad "no device detected"
    Note "Enable USB debugging and reconnect the cable."
} else {
    Ok "device present"
    Note (($devices -split "`n" | Where-Object { $_ -match 'android|V2403' }) -join "`n        ")
}
Write-Host ""

# ── Verdict ──────────────────────────────────────────────────
Write-Host "===========================" -ForegroundColor Cyan
if ($fail -eq 0) {
    Write-Host "All checks passed." -ForegroundColor Green
    Write-Host ""
    Write-Host "Run the app and read the diagnostics box under the spinner:" -ForegroundColor White
    Write-Host "    flutter run" -ForegroundColor Yellow
} else {
    Write-Host "$fail check(s) failed — fix those first." -ForegroundColor Red
}
Write-Host ""
