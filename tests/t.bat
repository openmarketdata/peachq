@echo off
rem Usage: t.bat [stdin]
rem   (no arg)  run each test as a file argument   (file mode)
rem   stdin     feed each test on stdin            (REPL mode)
rem REPL-mode bugs (e.g. top-level :return, RETURN leaking from a called
rem function) don't show in file mode, so the suite can be run both ways.
rem In REPL mode q writes "q)" prompt lines on stdout; findstr drops them
rem before stdout is compared to r%1.
setlocal enabledelayedexpansion
set mode=%~1
set ec=0
if not exist ndiff.exe (
    echo ERROR: ndiff.exe not built
    exit /b 1
)
for /f "usebackq tokens=*" %%t in ("tests") do (
    set line=%%t
    if not "!line!"=="" if not "!line:~0,1!"=="#" call :run !line!
)
goto end

:run
if "%1"=="" exit /b
if "%mode%"=="stdin" (..\q.exe < t%1.q 2>e%1 | findstr /v /r "^q)" > %1) else (..\q.exe t%1.q < NUL > %1 2>e%1)
set grc=!errorlevel!
.\ndiff.exe r%1 %1 > d%1 2>&1
set drc=!errorlevel!
set fail=0
if not "!grc!"=="0" set fail=1
if not "!drc!"=="0" set fail=1
if "!fail!"=="0" (
    echo t%1: pass
    del %1 d%1 e%1
) else (
    set /a ec+=1
    echo t%1: fail *****
)
exit /b

:end
echo failed: %ec%
exit /b %ec%
