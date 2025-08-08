@echo off
rem -mwindows 
g++ main.cc -I. -O3 glut32.lib -lopengl32 -lglu32 -m32 -o main.exe
if %errorlevel% neq 0 goto :stop
strip main.exe
main.exe -1
goto :end
:stop
pause
:end