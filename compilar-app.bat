@echo off
REM ============================================================
REM  compilar-app.bat - Compila la app movil para el navegador
REM  Correlo cuando haya cambios en la app (despues de git pull).
REM  El resultado queda en build\web y lo sirve iniciar-demo.bat.
REM ============================================================
chcp 65001 > nul
cd /d "%~dp0"
where flutter > nul 2>&1 || (echo [Error] No se encontro Flutter en el PATH. & if not "%1"=="sinpausa" pause & exit /b 1)
echo Compilando la app (tarda unos minutos)...
call flutter pub get || goto fallo
call flutter build web --release || goto fallo
echo.
echo [OK] App compilada en build\web. Ya puedes usar iniciar-demo.bat
if not "%1"=="sinpausa" pause
exit /b 0

:fallo
echo [Error] No se pudo compilar la app. Revisa los mensajes de arriba.
if not "%1"=="sinpausa" pause
exit /b 1
