@echo off
rem Runs the integration test suite with the demo fixtures enabled (Windows cmd).
rem cmd.exe equivalent of scripts/integration_test.sh. Requires a connected
rem device or running emulator. Extra arguments are passed straight through:
rem   scripts\integration_test.bat -d emulator-5554
rem   scripts\integration_test.bat integration_test\settings_test.dart
setlocal
cd /d "%~dp0.."
call flutter test integration_test --dart-define=OMODSCAN_DEMO_DATA=true %*
exit /b %ERRORLEVEL%
