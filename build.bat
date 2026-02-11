@echo off
setlocal

REM ensure build directory exists
if not exist build mkdir build

echo Assembling...
C:\masm32\bin\ml.exe /c /coff /Fo"build\main.obj" src\main.asm
if errorlevel 1 goto :fail

echo Linking...
C:\masm32\bin\link.exe /SUBSYSTEM:WINDOWS /OUT:"build\main.exe" "build\main.obj"
if errorlevel 1 goto :fail

echo.
echo Build successful.
echo Running game...
echo.

build\main.exe
goto :eof

:fail
echo.
echo Build failed.
pause