@echo off

REM Only windows, only hardcore
REM g++ main.cc -Ilib -mwindows -O3 glut32.lib -lopengl32 -lglu32 -m32 -o main.exe

REM Console Edition Lite
g++ main.cc -Ilib -O3 lib/glut32.lib -lopengl32 -lglu32 -m32 -o main.exe

if %errorlevel% neq 0 goto :stop
strip main.exe
main.exe
goto :end
:stop
pause
:end