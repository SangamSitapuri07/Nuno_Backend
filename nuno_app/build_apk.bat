@echo off
REM Builds a release APK and drops it on your Desktop, ready to send to the
REM phone over WhatsApp / Drive / cable. No ADB, no USB debugging.

setlocal
cd /d "%~dp0"

echo ============================================
echo   Nuno - building an installable APK
echo ============================================
echo.

echo [1/3] Patching the Android manifest...
if exist fix_android.ps1 (
  powershell -ExecutionPolicy Bypass -File "%~dp0fix_android.ps1"
)
echo.

echo [2/3] Building release APK (this takes a few minutes)...
call flutter build apk --release
if errorlevel 1 (
  echo.
  echo BUILD FAILED. Try:  flutter clean  then run this again.
  pause
  exit /b 1
)
echo.

echo [3/3] Copying to your Desktop...
set "SRC=build\app\outputs\flutter-apk\app-release.apk"
set "DST=%USERPROFILE%\Desktop\nuno.apk"
copy /Y "%SRC%" "%DST%" >nul
if errorlevel 1 (
  echo Could not copy. The APK is still here:
  echo    %CD%\%SRC%
) else (
  echo Done:  %DST%
)

echo.
echo ============================================
echo   Next steps
echo ============================================
echo.
echo   1. Send nuno.apk to your phone:
echo        - WhatsApp to yourself, or
echo        - Upload to Google Drive, or
echo        - Copy over USB (charging mode is fine)
echo.
echo   2. On the phone, tap the file
echo   3. Allow "Install from unknown sources" if asked
echo   4. Install
echo.
echo   No USB debugging needed. To see a change, run this
echo   again and reinstall over the top.
echo.
pause
endlocal
