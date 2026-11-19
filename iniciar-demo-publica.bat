@echo off
REM ============================================================
REM  iniciar-demo-publica.bat - HuellApp abierta a internet para la clase
REM  Doble clic: enciende la API (y el sitio web) y un tunel gratuito
REM  de Cloudflare que da una direccion https://....trycloudflare.com
REM  que funciona desde cualquier celular. Abre la pagina con el QR.
REM  Para apagar todo: cierra las ventanas "API" y "Tunel".
REM  Guia completa: docs\DEMO-PRESENTACION.md
REM ============================================================
chcp 65001 > nul
cd /d "%~dp0"
title HuellApp - demo publica

where php > nul 2>&1 || (echo [Error] No se encontro PHP. Revisa que la carpeta de PHP este en el PATH. & pause & exit /b 1)

REM 1. Buscar cloudflared (en el PATH o en C:\oracle\cloudflared)
set "CLOUDFLARED="
for /f "delims=" %%i in ('where cloudflared 2^>nul') do if not defined CLOUDFLARED set "CLOUDFLARED=%%i"
if not defined CLOUDFLARED if exist "C:\oracle\cloudflared\cloudflared.exe" set "CLOUDFLARED=C:\oracle\cloudflared\cloudflared.exe"
if not defined CLOUDFLARED (
  echo [Error] No se encontro cloudflared.
  echo   1. Descarga cloudflared-windows-amd64.exe desde
  echo      https://github.com/cloudflare/cloudflared/releases/latest
  echo   2. Crea la carpeta C:\oracle\cloudflared y guardalo ahi con el nombre cloudflared.exe
  echo   3. Vuelve a abrir este archivo.
  pause & exit /b 1
)

REM 2. API + sitio web en su propia ventana (puerto 3000)
echo Encendiendo la API y el sitio web...
start "HuellApp - API (no cerrar)" cmd /k "cd /d "%~dp0api" && php artisan serve"

echo Esperando a que responda el sitio web...
set /a intentos=0
:esperar
timeout /t 1 /nobreak > nul
set /a intentos+=1
curl -s -o nul -w "%%{http_code}" "http://127.0.0.1:3000/" 2>nul | findstr "200" > nul && goto api_lista
if %intentos% GEQ 30 (echo [Error] La API no encendio. Revisa la ventana "API": ahi aparece el error. & pause & exit /b 1)
goto esperar

:api_lista
REM 3. Tunel de Cloudflare en su propia ventana. La direccion se lee de su bitacora.
set "BITACORA=%TEMP%\huellapp-tunel.log"
if exist "%BITACORA%" del /q "%BITACORA%"
echo Abriendo el tunel publico (tarda unos segundos)...
start "HuellApp - Tunel (no cerrar)" cmd /k ""%CLOUDFLARED%" tunnel --no-autoupdate --url http://127.0.0.1:3000 --logfile "%BITACORA%""

set "URL="
set /a intentos=0
:buscar_url
timeout /t 2 /nobreak > nul
set /a intentos+=1
for /f "delims=" %%u in ('powershell -NoProfile -Command "if (Test-Path $env:BITACORA) { $m = Select-String -Path $env:BITACORA -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' | Select-Object -First 1; if ($m) { $m.Matches[0].Value } }"') do set "URL=%%u"
if defined URL goto tunel_listo
if %intentos% GEQ 30 (echo [Error] El tunel no dio direccion. Revisa la ventana "Tunel" y tu conexion a internet. & pause & exit /b 1)
goto buscar_url

:tunel_listo
REM Cloudflare tarda unos segundos en publicar la direccion nueva
timeout /t 5 /nobreak > nul
start "" "%URL%/pages/qr.html"
echo.
echo   ============================================================
echo    Direccion publica:  %URL%
echo    Pagina del QR:      %URL%/pages/qr.html
echo   ============================================================
echo.
echo   Proyecta la pagina del QR para que tus companeros la escaneen.
echo   Si el QR abre "no se encuentra", espera 30 segundos y recarga.
echo   La direccion cambia cada vez que abres este archivo.
echo   Para apagar todo, cierra las ventanas "API" y "Tunel".
echo.
pause
