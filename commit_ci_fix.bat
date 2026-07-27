@echo off
echo =============================================
echo Bruktbutikk -- fiks CI eksport-krasj
echo =============================================

set GIT="C:\Program Files\Git\cmd\git.exe"

%GIT% add .github/workflows/ci.yml

%GIT% status

%GIT% commit -m "Fix: ignorer Godot headless exit-kode ved eksport, sjekk om index.html finnes"

echo.
echo Kjor dette for aa pushe:
echo   git push origin main
echo.
pause
