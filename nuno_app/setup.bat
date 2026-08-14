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
echo.
echo IMPORTANT: for Android, add this attribute to the ^<application^> tag in
echo   android\app\src\main\AndroidManifest.xml
echo so the app can reach a local HTTP backend:
echo.
echo   android:usesCleartextTraffic="true"
echo.
echo Then run:
echo   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
echo.
echo NOTE: the app is LANDSCAPE-only - use a landscape emulator/device.

endlocal
