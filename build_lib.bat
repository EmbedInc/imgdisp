@echo off
rem
rem   BUILD_LIB
rem
rem   Build the IMGDISP library.
rem
setlocal
call build_pasinit

call src_pas %srcdir% %libname%_xform

call src_lib %srcdir% %libname% private
