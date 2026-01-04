@echo off
REM MyAI Project - Complete Verification Script (Windows)
REM Run this to verify everything is working

setlocal enabledelayedexpansion

cls
echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║        MyAI Project - Integration Verification             ║
echo ║                  2026-01-03                                 ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

set PASSED=0
set FAILED=0

REM ========================================================================
REM SYSTEM CHECKS
REM ========================================================================

echo.
echo === SYSTEM REQUIREMENTS ===
echo.

REM Check Node.js
where node >nul 2>nul
if %ERRORLEVEL% equ 0 (
    for /f "tokens=*" %%i in ('node -v') do set NODE_VERSION=%%i
    echo [OK] Node.js installed: !NODE_VERSION!
    set /a PASSED+=1
) else (
    echo [FAIL] Node.js NOT found. Please install from nodejs.org
    set /a FAILED+=1
)

REM Check npm
where npm >nul 2>nul
if %ERRORLEVEL% equ 0 (
    for /f "tokens=*" %%i in ('npm -v') do set NPM_VERSION=%%i
    echo [OK] npm installed: !NPM_VERSION!
    set /a PASSED+=1
) else (
    echo [FAIL] npm NOT found
    set /a FAILED+=1
)

REM Check Flutter
where flutter >nul 2>nul
if %ERRORLEVEL% equ 0 (
    for /f "tokens=*" %%i in ('flutter --version') do set FLUTTER_VERSION=%%i
    echo [OK] Flutter installed
    set /a PASSED+=1
) else (
    echo [FAIL] Flutter NOT found. Please install from flutter.dev
    set /a FAILED+=1
)

REM ========================================================================
REM BACKEND CHECKS
REM ========================================================================

echo.
echo === BACKEND CHECKS ===
echo.

if exist backend (
    echo [OK] backend\ folder exists
    set /a PASSED+=1
) else (
    echo [FAIL] backend\ folder NOT found
    set /a FAILED+=1
)

if exist backend\server.js (
    echo [OK] backend\server.js exists
    set /a PASSED+=1
) else (
    echo [FAIL] backend\server.js NOT found
    set /a FAILED+=1
)

if exist backend\.env (
    echo [OK] backend\.env file exists
    set /a PASSED+=1
    
    REM Check for required env vars (simple check)
    findstr /M "GROQ_API_KEY" backend\.env >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo   [OK] GROQ_API_KEY is set
    ) else (
        echo   [WARN] GROQ_API_KEY not found in .env
    )
    
    findstr /M "tavily=" backend\.env >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo   [OK] tavily key is set
    ) else (
        echo   [WARN] tavily key not found in .env
    )
    
    findstr /M "geminiapikey" backend\.env >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo   [OK] geminiapikey is set
    ) else (
        echo   [WARN] geminiapikey not found in .env
    )
) else (
    echo [FAIL] backend\.env file NOT found - create it with:
    echo    PORT=3000
    echo    GROQ_API_KEY=^<your-key^>
    echo    tavily=^<your-key^>
    echo    geminiapikey=^<your-key^>
    set /a FAILED+=1
)

if exist backend\package.json (
    echo [OK] backend\package.json exists
    set /a PASSED+=1
) else (
    echo [FAIL] backend\package.json NOT found
    set /a FAILED+=1
)

if exist backend\node_modules (
    echo [OK] backend\node_modules installed
    set /a PASSED+=1
) else (
    echo [WARN] backend\node_modules not found
    echo    Run: cd backend ^&^& npm install
    set /a FAILED+=1
)

REM ========================================================================
REM FRONTEND CHECKS
REM ========================================================================

echo.
echo === FRONTEND CHECKS ===
echo.

if exist pubspec.yaml (
    echo [OK] pubspec.yaml exists
    set /a PASSED+=1
    
    findstr /M "http:" pubspec.yaml >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo   [OK] http dependency present
    ) else (
        echo   [FAIL] http dependency missing
    )
    
    findstr /M "firebase_core:" pubspec.yaml >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo   [OK] firebase_core dependency present
    ) else (
        echo   [FAIL] firebase_core dependency missing
    )
    
    findstr /M "image_picker:" pubspec.yaml >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        echo   [OK] image_picker dependency present
    ) else (
        echo   [FAIL] image_picker dependency missing
    )
) else (
    echo [FAIL] pubspec.yaml NOT found
    set /a FAILED+=1
)

if exist lib\main.dart (
    echo [OK] lib\main.dart exists
    set /a PASSED+=1
) else (
    echo [FAIL] lib\main.dart NOT found
    set /a FAILED+=1
)

REM Check services
echo.
echo Checking service files:
echo.

if exist lib\services\api_service.dart (
    echo   [OK] lib\services\api_service.dart
    set /a PASSED+=1
) else (
    echo   [FAIL] lib\services\api_service.dart NOT found
    set /a FAILED+=1
)

if exist lib\services\gemini_services.dart (
    echo   [OK] lib\services\gemini_services.dart
    set /a PASSED+=1
) else (
    echo   [FAIL] lib\services\gemini_services.dart NOT found
    set /a FAILED+=1
)

if exist lib\services\web_search_service.dart (
    echo   [OK] lib\services\web_search_service.dart
    set /a PASSED+=1
) else (
    echo   [FAIL] lib\services\web_search_service.dart NOT found
    set /a FAILED+=1
)

REM Check screens
echo.
echo Checking screen files:
echo.

if exist lib\screens\online_ai_screen.dart (
    echo   [OK] lib\screens\online_ai_screen.dart
    set /a PASSED+=1
) else (
    echo   [FAIL] lib\screens\online_ai_screen.dart NOT found
    set /a FAILED+=1
)

if exist lib\screens\ai_screen.dart (
    echo   [OK] lib\screens\ai_screen.dart
    set /a PASSED+=1
) else (
    echo   [FAIL] lib\screens\ai_screen.dart NOT found
    set /a FAILED+=1
)

if exist lib\screens\study_plan_screen.dart (
    echo   [OK] lib\screens\study_plan_screen.dart
    set /a PASSED+=1
) else (
    echo   [FAIL] lib\screens\study_plan_screen.dart NOT found
    set /a FAILED+=1
)

REM ========================================================================
REM SUMMARY
REM ========================================================================

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║                       TEST SUMMARY                         ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo Passed: !PASSED!
echo Failed: !FAILED!
echo.

if !FAILED! equ 0 (
    echo ════════════════════════════════════════════════════════════
    echo [SUCCESS] ALL CHECKS PASSED - Ready to run!
    echo ════════════════════════════════════════════════════════════
    echo.
    echo Next steps:
    echo 1. Make sure backend is running: cd backend ^&^& node server.js
    echo 2. In another terminal, run: flutter run
    echo 3. Test chat, search, and image features in the app
    echo.
    exit /b 0
) else (
    echo ════════════════════════════════════════════════════════════
    echo [ERROR] SOME CHECKS FAILED - Please fix above issues
    echo ════════════════════════════════════════════════════════════
    echo.
    echo Troubleshooting:
    echo - Install missing dependencies
    echo - Set environment variables in backend\.env
    echo - Run: npm install (in backend folder)
    echo - Run: flutter pub get
    echo.
    exit /b 1
)

endlocal
