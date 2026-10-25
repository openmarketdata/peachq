@echo off

for %%i in (p001 p002 p003 p004 p005 p006 p007 p008) do (
    echo %%i =========================
    ..\q.exe %%i.q < NUL
    echo.
)

exit /b 0
