@echo off
setlocal

set "VERSION=v1.0.0"
for %%I in ("%~dp0.") do set "PROJ_NAME=%%~nxI"
set "OUT_ZIP=%~dp0%PROJ_NAME%-%VERSION%.zip"

if exist "%OUT_ZIP%" del /f /q "%OUT_ZIP%"
git -C "%~dp0." archive --format=zip --prefix="%PROJ_NAME%/" HEAD -o "%OUT_ZIP%" -- . ":(exclude).gitignore" ":(exclude)%~nx0"

if exist "%OUT_ZIP%" (
    echo Created: %OUT_ZIP%
) else (
    echo Failed to build release zip.
)
pause
