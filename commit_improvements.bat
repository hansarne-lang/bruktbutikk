@echo off
echo =============================================
echo Bruktbutikk -- commit forbedringer
echo =============================================

set GIT="C:\Program Files\Git\cmd\git.exe"

%GIT% add scripts/SoundManager.gd
%GIT% add scripts/cleanup/RoomBackground.gd
%GIT% add scripts/cleanup/FurnitureSprite.gd
%GIT% add scripts/cleanup/Cleanup.gd
%GIT% add scripts/shop/Shop.gd
%GIT% add scripts/home/Home.gd
%GIT% add project.godot

%GIT% status

%GIT% commit -m "3 forbedringer: 3-roms dodsbo, prisantydning, lydeffekter + mobelvisuals"

echo.
echo Kjor dette for aa pushe:
echo   git push origin main
echo.
pause
