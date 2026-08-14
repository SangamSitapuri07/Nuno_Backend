# Patches the generated Android manifest for Nuno.
#
#   powershell -ExecutionPolicy Bypass -File .\fix_android.ps1
#
# Adds:
#   * android.permission.INTERNET  — Flutter only adds this to the debug and
#     profile manifests, so a RELEASE apk otherwise has no network access.
#   * android:usesCleartextTraffic — only needed if you later point the app at
#     a local http:// backend; harmless with the hosted https:// one.

$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

$manifest = 'android\app\src\main\AndroidManifest.xml'

if (-not (Test-Path $manifest)) {
    Write-Host "ERROR: $manifest not found." -ForegroundColor Red
    Write-Host "Run 'flutter create .' (or setup.bat) first." -ForegroundColor Yellow
    exit 1
}

$xml = Get-Content $manifest -Raw
$changed = $false

# ── INTERNET permission ──────────────────────────────────────
if ($xml -notmatch 'android\.permission\.INTERNET') {
    $xml = $xml -replace '(<manifest\b[^>]*>)',
        "`$1`n    <uses-permission android:name=`"android.permission.INTERNET`"/>"
    Write-Host "  + INTERNET permission" -ForegroundColor Green
    $changed = $true
} else {
    Write-Host "  = INTERNET permission already present" -ForegroundColor DarkGray
}

# ── Cleartext HTTP (local dev only) ──────────────────────────
if ($xml -notmatch 'usesCleartextTraffic') {
    $xml = $xml -replace '(<application\b)',
        "`$1`n        android:usesCleartextTraffic=`"true`""
    Write-Host "  + usesCleartextTraffic" -ForegroundColor Green
    $changed = $true
} else {
    Write-Host "  = usesCleartextTraffic already present" -ForegroundColor DarkGray
}

if ($changed) {
    Set-Content -Path $manifest -Value $xml -NoNewline -Encoding UTF8
    Write-Host "`nPatched $manifest" -ForegroundColor Cyan
} else {
    Write-Host "`nNothing to change." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  flutter build apk --release"
Write-Host "  -> build\app\outputs\flutter-apk\app-release.apk"

# ── Launcher icons ───────────────────────────────────────────
# Flutter's template ships a generic icon; copy ours over every density.
$densities = @('mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi')
$copied = 0
foreach ($d in $densities) {
    $srcIcon = "assets\launcher\ic_launcher_$d.png"
    $dstDir  = "android\app\src\main\res\mipmap-$d"
    if ((Test-Path $srcIcon) -and (Test-Path $dstDir)) {
        Copy-Item $srcIcon "$dstDir\ic_launcher.png" -Force
        $copied++
    }
}
if ($copied -gt 0) { Write-Host "  + launcher icon ($copied densities)" -ForegroundColor Green }
