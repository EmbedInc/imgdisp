@echo off
rem
rem   DBG [arg ... arg]
rem
rem   Build the program in debug mode, then debug it.  The optional arguments
rem   are passed to the program when run in the debugger.
rem
setlocal
set prog=image_disp
set debug_vs=true
set debugging=true
call build
if errorlevel 1 goto :eof
copyt /img/5008.jpg /img/t.jpg
copya /img/5008.displ /img/t.displ
call extpath_var msvc/debugger.exe tnam
"%tnam%" /DebugExe %prog%.exe /img/t.jpg -dev debug %1 %2 %3 %4 %5 %6 %7 %8 %9
