@echo off
REM Nuno app - one-time setup (Windows)
REM
REM   setup.bat
REM
REM Generates the native platform folders and installs packages.

setlocal
cd /d "%~dp0"

echo === Nuno app setup ===
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo ERROR: 'flutter' was not found on your PATH.
  echo Install Flutter 3.27 or newer: https://docs.flutter.dev/get-started/install
  exit /b 1
)

echo --- Flutter version ---
call flutter --version
echo.

if not exist android if not exist windows (
  echo --- Generating platform folders ---
  call flutter create --project-name nuno_app --org com.nuno .
) else (
  echo --- Platform folders already exist, skipping generate ---
)
echo.

echo --- Fetching packages ---
call flutter pub get
echo.

echo --- Analyzing ---
call flutter analyze

echo.
echo === Setup complete ===
echo --- Patching Android manifest ---
if exist android\app\src\main\AndroidManifest.xml (
  powershell -ExecutionPolicy Bypass -File "%~dp0fix_android.ps1"
)
echo.

echo The app defaults to the hosted backend, so just run:
echo   flutter run
echo.
echo In VS Code, press F5 and choose "Nuno (hosted backend - default)".
echo.
echo To use a LOCAL backend over plain http, first add this attribute to the
echo ^<application^> tag in android\app\src\main\AndroidManifest.xml:
echo   android:usesCleartextTraffic="true"
echo then run:
echo   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
echo.
echo NOTES
echo   * The app is LANDSCAPE-only - use a landscape emulator/device.
echo   * The hosted backend sleeps when idle; first launch may take a minute.

endlocal
