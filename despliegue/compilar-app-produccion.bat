@echo off
REM ============================================================
REM  compilar-app-produccion.bat - Compila la app para el servidor publicado (HU-25)
REM  Uso:  compilar-app-produccion.bat https://huellapp.ejemplo.com
REM  Resultado en build\web: se copia a /opt/huellapp/build/web en la maquina virtual
REM  y queda en  https://huellapp.ejemplo.com/app/
REM ============================================================
chcp 65001 > nul
cd /d "%~dp0.."
if "%~1"=="" (
  echo Uso: compilar-app-produccion.bat https://TU_DOMINIO
  echo      ^(o http://IP_PUBLICA si aun no hay dominio^)
  exit /b 1
)
set "SERVIDOR=%~1"
if "%SERVIDOR:~-1%"=="/" set "SERVIDOR=%SERVIDOR:~0,-1%"
where flutter > nul 2>&1 || (echo [Error] No se encontro Flutter en el PATH. & exit /b 1)
echo Compilando la app para %SERVIDOR%/app/ ...
call flutter pub get || exit /b 1
call flutter build web --release --base-href /app/ --dart-define=API_URL=%SERVIDOR%/api || exit /b 1
echo.
echo [OK] Copia la carpeta build\web a la maquina virtual, por ejemplo:
echo      scp -r build\web\* ubuntu@IP:/opt/huellapp/build/web/
