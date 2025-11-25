#!/bin/bash
# ==============================================================================
# Flutter Run Android - Wrapper para usar ADB de Windows
# ==============================================================================
# Propósito: Ejecutar Flutter con el servidor ADB de Windows
# Uso: ./flutter_run_android.sh [argumentos de flutter]
# ==============================================================================

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

DEVICE="${1:-192.168.1.50:5555}"

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}        Flutter Run Android - Usando ADB de Windows         ${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Verificar que ADB de Windows esté corriendo
echo -e "${YELLOW}[1/4]${NC} Verificando servidor ADB de Windows..."
ADB_PATH="/mnt/c/platform-tools/adb.exe"

if ! $ADB_PATH devices &>/dev/null; then
    echo -e "${RED}✗${NC} Servidor ADB no responde"
    echo -e "${YELLOW}Iniciando servidor...${NC}"
    cd /mnt/c/platform-tools
    $ADB_PATH start-server
    sleep 2
fi

echo -e "${GREEN}✓${NC} Servidor ADB activo"
echo ""

# Verificar dispositivo conectado
echo -e "${YELLOW}[2/4]${NC} Verificando dispositivo $DEVICE..."
DEVICES_OUTPUT=$($ADB_PATH devices | tr -d '\r')

if echo "$DEVICES_OUTPUT" | grep -q "$DEVICE.*device$"; then
    echo -e "${GREEN}✓${NC} Dispositivo conectado"
else
    echo -e "${RED}✗${NC} Dispositivo no encontrado"
    echo ""
    echo "Dispositivos disponibles:"
    $ADB_PATH devices -l
    echo ""
    echo -e "${YELLOW}Solución:${NC} Ejecuta primero:"
    echo -e "  ${BLUE}./fix_adb_connection.sh $DEVICE${NC}"
    exit 1
fi
echo ""

# Configurar variables de entorno para Flutter
echo -e "${YELLOW}[3/4]${NC} Configurando Flutter para usar ADB de Windows..."
export ANDROID_HOME=/mnt/c/platform-tools
export ANDROID_SDK_ROOT=/mnt/c/platform-tools
export ADB_SERVER_SOCKET=tcp:127.0.0.1:5037

# Crear enlace simbólico temporal si no existe
FLUTTER_ADB_LINK="/tmp/flutter_adb"
if [ ! -L "$FLUTTER_ADB_LINK" ]; then
    ln -sf /mnt/c/platform-tools/adb.exe "$FLUTTER_ADB_LINK"
fi

echo -e "${GREEN}✓${NC} Variables configuradas"
echo ""

# Ejecutar Flutter
echo -e "${YELLOW}[4/4]${NC} Ejecutando Flutter..."
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Usar FLUTTER_ADB para forzar el uso del ADB correcto
export FLUTTER_ADB=/mnt/c/platform-tools/adb.exe

flutter run -d "$DEVICE" "${@:2}"
