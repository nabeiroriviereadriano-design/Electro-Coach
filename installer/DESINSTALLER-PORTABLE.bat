@echo off
chcp 65001 >nul
rem Désinstalleur de la version portable de BTS Électro Coach.
echo Désinstallation de BTS Électro Coach (version portable)
echo.
choice /M "Supprimer aussi ta progression enregistrée sur ce PC"
if errorlevel 2 goto files
if exist "%APPDATA%\ElectroCoach" rmdir /s /q "%APPDATA%\ElectroCoach"
echo Progression supprimée.
:files
echo Suppression des fichiers du programme...
set "DIR=%~dp0"
start "" /b cmd /c "timeout /t 2 >nul & rmdir /s /q "%DIR%""
echo Terminé.
