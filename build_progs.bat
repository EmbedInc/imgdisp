@echo off
rem
rem   BUILD_PROGS
rem
rem   Build the executable programs from this source directory.
rem
setlocal
call build_pasinit

set prog=image_disp
call src_pas %srcdir% %prog%
call src_link %prog% %prog% idisp.lib
call src_exeput %prog%
