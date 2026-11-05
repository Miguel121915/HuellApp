@echo off
REM ============================================================
REM  iniciar-demo.bat - Enciende HuellApp para presentar
REM  Doble clic: arranca la API (y el sitio web), sirve la app
REM  ya compilada y abre las dos pestanas en el navegador.
REM  Para apagar todo: cierra las dos ventanas negras.
REM ============================================================
chcp 65001 > nul
cd /d "%~dp0"
title HuellApp - demo

where php > nul 2>&1 || (echo [Error] No se encontro PHP. Revisa que C:\xampp\php este en el PATH. & pause & exit /b 1)

REM 1. La app compilada. Si no existe, se compila una vez (tarda unos minutos).
if not exist "build\web\index.html" (
  echo La app aun no esta compilada. Compilando por unica vez, espera unos minutos...
  call compilar-app.bat sinpausa || (pause & exit /b 1)
)

REM 2. API + sitio web en su propia ventana (puerto 3000)
echo Encendiendo la API y el sitio web...
start "HuellApp - API y sitio web (no cerrar)" cmd /k "cd /d "%~dp0api" && php artisan serve"

REM 3. App movil compilada en su propia ventana (puerto 8080)
start "HuellApp - App movil (no cerrar)" cmd /k "php -S 127.0.0.1:8080 -t "%~dp0build\web""

REM 4. Esperar a que la conexion con Oracle este lista (hasta 2 minutos)
echo Conectando con Oracle, espera...
set /a intentos=0
:esperar
timeout /t 2 /nobreak > nul
set /a intentos+=1
curl -s -o nul -w "%%{http_code}" "http://127.0.0.1:3000/api/salud?db=1" 2>nul | findstr "200" > nul && goto listo
if %intentos% GEQ 60 goto tarde
goto esperar

:tarde
echo [Aviso] Oracle tarda en responder. Revisa la ventana "API y sitio web". Se abriran las pestanas de todos modos.

:listo
echo Listo. Abriendo el sitio web y la app...
start "" "http://127.0.0.1:3000"
start "" "http://127.0.0.1:8080"
echo.
echo   Sitio web:  http://127.0.0.1:3000
echo   App movil:  http://127.0.0.1:8080
echo.
echo Para apagar todo, cierra las ventanas "API y sitio web" y "App movil".
timeout /t 8 > nul
