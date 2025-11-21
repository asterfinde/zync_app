#!/bin/bash
# ==============================================================================
# Stop Dev - Cierre de Jornada de Desarrollo
# ==============================================================================
# Uso: ./stop_dev.sh
# ==============================================================================

PROJECT_DIR="/home/dante/projects/zync_app"
DEVICE="192.168.1.50:5555"
ADB_PATH="/mnt/c/platform-tools/adb.exe"
WATCHDOG_PID_FILE="$PROJECT_DIR/.watchdog.pid"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           🌙 Cerrando Jornada de Desarrollo                ${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Paso 1: Detener watchdog
echo -e "${YELLOW}[1/4]${NC} Deteniendo watchdog..."
if [ -f "$WATCHDOG_PID_FILE" ]; then
    WATCHDOG_PID=$(cat "$WATCHDOG_PID_FILE")
    if ps -p $WATCHDOG_PID > /dev/null 2>&1; then
        kill $WATCHDOG_PID 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Watchdog detenido (PID: $WATCHDOG_PID)"
    else
        echo -e "${YELLOW}⚠${NC} Watchdog no estaba corriendo"
    fi
    rm -f "$WATCHDOG_PID_FILE"
else
    echo -e "${YELLOW}⚠${NC} No se encontró archivo PID del watchdog"
fi
echo ""

# Paso 2: Detener procesos de Flutter
echo -e "${YELLOW}[2/4]${NC} Deteniendo procesos de Flutter..."
FLUTTER_PIDS=$(pgrep -f "flutter.*$DEVICE" || true)
if [ -n "$FLUTTER_PIDS" ]; then
    echo "$FLUTTER_PIDS" | while read pid; do
        kill $pid 2>/dev/null || true
    done
    echo -e "${GREEN}✓${NC} Procesos de Flutter detenidos"
else
    echo -e "${YELLOW}⚠${NC} No hay procesos de Flutter corriendo"
fi
echo ""

# Paso 3: Desconectar dispositivo
echo -e "${YELLOW}[3/4]${NC} Desconectando dispositivo..."
cd /mnt/c/platform-tools
$ADB_PATH disconnect $DEVICE 2>/dev/null || true
echo -e "${GREEN}✓${NC} Dispositivo desconectado"
echo ""

# Paso 4: Limpiar archivos temporales
echo -e "${YELLOW}[4/4]${NC} Limpiando archivos temporales..."
rm -f /mnt/c/platform-tools/zync-app.apk 2>/dev/null || true
rm -f /mnt/c/platform-tools/temp-app.apk 2>/dev/null || true
echo -e "${GREEN}✓${NC} Archivos temporales eliminados"
echo ""

# Resumen
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Jornada cerrada correctamente${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Hasta la próxima sesión! 👋"
echo ""
