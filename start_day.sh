#!/bin/bash

PROJECT_DIR="/home/datainfers/projects/zync_app"
cd "$PROJECT_DIR" || exit 1

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                    ║${NC}"
echo -e "${CYAN}║     🌅 INICIO DEL DÍA - Desarrollo Zync App        ║${NC}"
echo -e "${CYAN}║                                                    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# FASE 1: Conexión Android
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📱 FASE 1: Conexión Android/WSL2${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}⚠️  Se abrirá una ventana de PowerShell para conectar Android${NC}"
echo -e "${YELLOW}   Acepta el UAC (Control de Cuentas) si aparece${NC}"
echo ""

# Copiar script a Windows TEMP para evitar error de rutas UNC
WIN_TEMP=$(cmd.exe /c "echo %TEMP%" 2>/dev/null | tr -d '\r')
WIN_TEMP_UNIX=$(wslpath "$WIN_TEMP" 2>/dev/null)
TEMP_SCRIPT="$WIN_TEMP_UNIX/connect_android_daily.ps1"
WRAPPER_SCRIPT="$WIN_TEMP_UNIX/run_elevated_connect.ps1"

cp "$PROJECT_DIR/connect_android_daily.ps1" "$TEMP_SCRIPT"

# Crear wrapper que ejecuta con elevación y espera
cat > "$WRAPPER_SCRIPT" << 'EOFWRAPPER'
$scriptPath = "$env:TEMP\connect_android_daily.ps1"
Write-Host "Solicitando permisos de administrador..." -ForegroundColor Yellow
Write-Host ""
$process = Start-Process powershell.exe "-ExecutionPolicy Bypass -NoProfile -Command `"cd '$env:TEMP'; & '$scriptPath'; Write-Host ''; Write-Host 'Presiona Enter para cerrar esta ventana...'; Read-Host`"" -Verb RunAs -PassThru
if ($process) {
    Write-Host "✅ Ventana de conexión abierta con permisos admin" -ForegroundColor Green
    Write-Host "   Espera a que termine y presiona Enter en esa ventana" -ForegroundColor Gray
}
exit 0
EOFWRAPPER

# Ejecutar wrapper
echo -e "${CYAN}Conectando dispositivo Android...${NC}"
echo -e "${YELLOW}⚠️  Se abrirá una ventana de PowerShell con UAC${NC}"
echo -e "${YELLOW}   1. Acepta el UAC (Control de Cuentas)${NC}"
echo -e "${YELLOW}   2. Espera a que la conexión termine${NC}"
echo -e "${YELLOW}   3. Presiona Enter EN LA VENTANA DE POWERSHELL${NC}"
echo ""
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "$(wslpath -w "$WRAPPER_SCRIPT")"

# Esperar y verificar resultado
echo ""
echo -e "${CYAN}Esperando a que cierres la ventana de PowerShell...${NC}"
sleep 2

echo -e "${CYAN}Verificando conexión...${NC}"
sleep 2

# Verificar si ADB realmente detectó el dispositivo
ADB_CHECK=$(adb devices 2>/dev/null | grep -v "List of devices" | grep "device")
if [ -n "$ADB_CHECK" ]; then
    ANDROID_STATUS=0
else
    ANDROID_STATUS=1
fi

echo ""
echo -e "${CYAN}Presiona ENTER para continuar...${NC}"
read

# Limpiar
rm -f "$TEMP_SCRIPT" "$WRAPPER_SCRIPT" 2>/dev/null

echo ""
if [ $ANDROID_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Dispositivo Android conectado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️  Continuando sin dispositivo Android...${NC}"
    echo -e "${YELLOW}   Verifica que el cable USB esté conectado${NC}"
fi
echo ""
echo -e "${YELLOW}Presiona ENTER para continuar...${NC}"
read

# FASE 2: Prevención de Suspensión
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}💤 FASE 2: Prevención de Suspensión${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}🔒 Configurando Windows para evitar suspensión...${NC}"
echo ""

./prevent_sleep_from_wsl.sh

echo ""
echo -e "${GREEN}✅ Suspensión deshabilitada por 4 horas${NC}"
echo ""

# FASE 3: Sesión de Desarrollo
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🚀 FASE 3: Sesión de Desarrollo WSL2${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}🔧 Iniciando watchdog y auto-backup...${NC}"
echo ""

./start_dev_session.sh

echo ""

# RESUMEN FINAL
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                    ║${NC}"
echo -e "${CYAN}║          ✅ SISTEMA LISTO PARA DESARROLLO          ║${NC}"
echo -e "${CYAN}║                                                    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}📊 Estado del Sistema:${NC}"
echo ""
if [ $ANDROID_STATUS -eq 0 ]; then
    echo -e "   ${GREEN}✅${NC} Dispositivo Android: ${GREEN}CONECTADO${NC}"
else
    echo -e "   ${YELLOW}⚠️${NC}  Dispositivo Android: ${YELLOW}NO CONECTADO${NC}"
fi
echo -e "   ${GREEN}✅${NC} Suspensión: ${GREEN}DESHABILITADA (4h)${NC}"
echo -e "   ${GREEN}✅${NC} Watchdog WSL2: ${GREEN}ACTIVO${NC}"
echo -e "   ${GREEN}✅${NC} Auto-backup: ${GREEN}ACTIVO${NC}"
echo ""

echo -e "${CYAN}📝 Comandos Útiles:${NC}"
echo ""
echo -e "   ${YELLOW}Verificar Android:${NC}"
echo -e "   ${CYAN}adb devices${NC}"
echo -e "   ${CYAN}lsusb | grep -i samsung${NC}"
echo ""
echo -e "   ${YELLOW}Ejecutar app:${NC}"
echo -e "   ${CYAN}flutter run${NC}"
echo ""

echo -e "${YELLOW}🎯 Para terminar el día:${NC}"
echo -e "   ${CYAN}./end_day.sh${NC}"
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ¡Feliz desarrollo! 💻 🚀 ☕️                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""