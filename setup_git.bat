@echo off
echo ============================================
echo  Bruktbutikk – Git oppsett
echo ============================================
echo.

cd /d "%~dp0"

echo Sjekker om git er installert...
git --version >nul 2>&1
if errorlevel 1 (
    echo FEIL: Git er ikke installert!
    echo Last ned fra: https://git-scm.com/download/win
    pause
    exit /b 1
)

echo Git funnet. Initialiserer repo...
git init
git add .
git commit -m "Første commit – Bruktbutikk v0.1"
git branch -M main

echo.
echo ============================================
echo  Neste steg – gjør dette manuelt:
echo ============================================
echo.
echo 1. Gå til github.com/new
echo 2. Lag repo ved navn: bruktbutikk (Public)
echo 3. Klikk "Create repository" uten README/gitignore
echo 4. Kopier og kjør denne kommandoen:
echo.
echo    git remote add origin https://github.com/hansarne-lang/bruktbutikk.git
echo    git push -u origin main
echo.
echo (Du vil bli bedt om GitHub-brukernavn og passord/token)
echo.
pause
