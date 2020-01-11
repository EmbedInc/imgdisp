@echo off
rem
rem   BUILD_PROGS
rem
rem   Build the executable programs from this source directory.
rem
setlocal
call build_pasinit

call src_pas %srcdir% image_disp
call src_link image_disp image_disp idisp.lib
call src_exeput image_disp
