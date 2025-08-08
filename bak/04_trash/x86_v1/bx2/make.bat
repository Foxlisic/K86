@echo off

REM Only windows, only hardcore
REM g++ main.cc -Ilib -mwindows -O3 glut32.lib -lopengl32 -lglu32 -m32 -o main.exe

REM Console Edition Lite
fasm bios/top.asm bios/top.bin
g++ main.cc -Ilib -O3 lib/glut32.lib -lopengl32 -lglu32 -m32 -o main.exe

if %errorlevel% neq 0 goto :stop
strip main.exe
rem objdump -M intel -S main.exe > main.lst
main.exe
goto :end
:stop
pause
:end