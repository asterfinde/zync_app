#!/bin/bash
# ==============================================================================
# Script de Verificación Post-Restauración - Zync App
# ==============================================================================
# Propósito: Verificar que todo esté configurado correctamente después de
#            restaurar el proyecto desde GitHub
# Uso: ./verify_setup.sh
# ==============================================================================

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Verificación Post-Restauración - Zync App           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Contador de problemas
ISSUES=0

# 1. Verificar Workspace File
echo -e "${YELLOW}[1/8]${NC} Verificando archivo de workspace..."
if [ -f "zync_app.code-workspace" ]; then
    echo -e "${GREEN}✓${NC} Workspace file existe"
else
    echo -e "${RED}✗${NC} Workspace file NO encontrado"
    echo -e "  ${YELLOW}→${NC} Ejecuta: Abre el proyecto con 'File > Open Workspace from File'"
    ISSUES=$((ISSUES + 1))
fi
echo ""

# 2. Verificar ADB de Windows
echo -e "${YELLOW}[2/8]${NC} Verificando ADB de Windows..."
ADB_WINDOWS="/mnt/c/platform-tools/adb.exe"
if [ -f "$ADB_WINDOWS" ]; then
    echo -e "${GREEN}✓${NC} ADB de Windows encontrado"
    ADB_VERSION=$($ADB_WINDOWS version 2>&1 | head -n1 || echo "Error")
    echo -e "  ${BLUE}→${NC} Versión: $ADB_VERSION"
else
    echo -e "${RED}✗${NC} ADB de Windows NO encontrado"
    echo -e "  ${YELLOW}→${NC} Descarga desde: https://developer.android.com/tools/releases/platform-tools"
    echo -e "  ${YELLOW}→${NC} Extrae en: C:\\platform-tools\\"
    ISSUES=$((ISSUES + 1))
fi
echo ""

# 3. Verificar configuración de ADB en .bashrc
echo -e "${YELLOW}[3/8]${NC} Verificando configuración de ADB en .bashrc..."
if grep -q "alias adb='/mnt/c/platform-tools/adb.exe'" "$HOME/.bashrc"; then
    echo -e "${GREEN}✓${NC} Alias de ADB configurado"
else
    echo -e "${YELLOW}⚠${NC} Alias de ADB NO configurado"
    echo -e "  ${YELLOW}→${NC} Ejecuta: ./configure_adb_windows.sh"
    ISSUES=$((ISSUES + 1))
fi
echo ""

# 4. Verificar Flutter/FVM
echo -e "${YELLOW}[4/8]${NC} Verificando Flutter/FVM..."
if command -v fvm &> /dev/null; then
    echo -e "${GREEN}✓${NC} FVM instalado"
    FVM_VERSION=$(fvm --version 2>&1 || echo "Error")
    echo -e "  ${BLUE}→${NC} Versión: $FVM_VERSION"
    
    # Verificar Flutter
    if fvm flutter --version &> /dev/null; then
        echo -e "${GREEN}✓${NC} Flutter disponible vía FVM"
        FLUTTER_VERSION=$(fvm flutter --version 2>&1 | head -n1 || echo "Error")
        echo -e "  ${BLUE}→${NC} $FLUTTER_VERSION"
    else
        echo -e "${YELLOW}⚠${NC} Flutter NO disponible"
        echo -e "  ${YELLOW}→${NC} Ejecuta: fvm install stable && fvm use stable"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo -e "${RED}✗${NC} FVM NO instalado"
    echo -e "  ${YELLOW}→${NC} Ejecuta: dart pub global activate fvm"
    ISSUES=$((ISSUES + 1))
fi
echo ""

# 5. Verificar dependencias del proyecto
echo -e "${YELLOW}[5/8]${NC} Verificando dependencias del proyecto..."
if [ -f "pubspec.yaml" ]; then
    echo -e "${GREEN}✓${NC} pubspec.yaml existe"
    
    if [ -f "pubspec.lock" ]; then
        echo -e "${GREEN}✓${NC} Dependencias instaladas"
    else
        echo -e "${YELLOW}⚠${NC} Dependencias NO instaladas"
        echo -e "  ${YELLOW}→${NC} Ejecuta: flutter pub get"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo -e "${RED}✗${NC} pubspec.yaml NO encontrado"
    ISSUES=$((ISSUES + 1))
fi
echo ""

# 6. Verificar scripts tienen permisos de ejecución
echo -e "${YELLOW}[6/8]${NC} Verificando permisos de scripts..."
SCRIPTS_OK=0
SCRIPTS_TOTAL=0

for script in *.sh; do
    if [ -f "$script" ]; then
        SCRIPTS_TOTAL=$((SCRIPTS_TOTAL + 1))
        if [ -x "$script" ]; then
            SCRIPTS_OK=$((SCRIPTS_OK + 1))
        fi
    fi
done

if [ $SCRIPTS_OK -eq $SCRIPTS_TOTAL ]; then
    echo -e "${GREEN}✓${NC} Todos los scripts tienen permisos ($SCRIPTS_OK/$SCRIPTS_TOTAL)"
else
    echo -e "${YELLOW}⚠${NC} Algunos scripts sin permisos ($SCRIPTS_OK/$SCRIPTS_TOTAL)"
    echo -e "  ${YELLOW}→${NC} Ejecuta: chmod +x *.sh"
    ISSUES=$((ISSUES + 1))
fi
echo ""

# 7. Verificar .wslconfig
echo -e "${YELLOW}[7/8]${NC} Verificando configuración de WSL2..."
WSLCONFIG="/mnt/c/Users/$(whoami)/.wslconfig"
if [ -f "$WSLCONFIG" ]; then
    echo -e "${GREEN}✓${NC} .wslconfig existe en Windows"
else
    echo -e "${YELLOW}⚠${NC} .wslconfig NO encontrado"
    echo -e "  ${YELLOW}→${NC} Copia .wslconfig.example a: C:\\Users\\$(whoami)\\.wslconfig"
    echo -e "  ${YELLOW}→${NC} Luego ejecuta: wsl --shutdown"
    ISSUES=$((ISSUES + 1))
fi
echo ""

# 8. Verificar conexión ADB (si está configurado)
echo -e "${YELLOW}[8/8]${NC} Verificando conexión ADB..."
if [ -f "$ADB_WINDOWS" ]; then
    DEVICES=$($ADB_WINDOWS devices 2>&1 | grep -v "List of devices" | grep -v "^$" | wc -l)
    
    if [ $DEVICES -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Dispositivo(s) conectado(s): $DEVICES"
        $ADB_WINDOWS devices -l
    else
        echo -e "${YELLOW}⚠${NC} Ningún dispositivo conectado"
        echo -e "  ${YELLOW}→${NC} Para USB: Ejecuta connect_android_daily.ps1 (PowerShell Admin)"
        echo -e "  ${YELLOW}→${NC} Para WiFi: Ejecuta ./fix_adb_connection.sh <IP:PORT>"
    fi
else
    echo -e "${YELLOW}⚠${NC} No se puede verificar (ADB no disponible)"
fi
echo ""

# Resumen final
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
if [ $ISSUES -eq 0 ]; then
    echo -e "${BLUE}║${GREEN}                  ✓ TODO CONFIGURADO                       ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}✓${NC} Sistema listo para desarrollo"
    echo ""
    echo -e "${YELLOW}Próximos pasos:${NC}"
    echo -e "  1. ${BLUE}Abre el workspace:${NC} File > Open Workspace from File > zync_app.code-workspace"
    echo -e "  2. ${BLUE}Conecta dispositivo:${NC} ./connect_android_daily.ps1 (PowerShell Admin)"
    echo -e "  3. ${BLUE}Inicia desarrollo:${NC} ./start_day.sh"
else
    echo -e "${BLUE}║${YELLOW}              ⚠ $ISSUES PROBLEMA(S) ENCONTRADO(S)                ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Revisa los mensajes arriba para solucionar los problemas${NC}"
    echo ""
    echo -e "${YELLOW}Guía completa:${NC} cat SOLUCION_WSL2_ADB.md"
fi
echo ""
