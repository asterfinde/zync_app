#!/bin/bash
# ==============================================================================
# Script de Mantenimiento ADB - Zync App
# ==============================================================================
# Propósito: Mantener conexión ADB WiFi estable mediante pings periódicos
# Uso: ./keep_adb_alive.sh [IP:PORT] [INTERVAL_SECONDS]
# Ejemplo: ./keep_adb_alive.sh 192.168.1.50:5555 60
# ==============================================================================

set -e

# Configuración
ADB_PATH="/mnt/c/platform-tools/adb.exe"
DEFAULT_DEVICE="192.168.1.50:5555"
DEFAULT_INTERVAL=60  # segundos

DEVICE="${1:-$DEFAULT_DEVICE}"
INTERVAL="${2:-$DEFAULT_INTERVAL}"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Mantener Conexión ADB Viva - Zync App                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Dispositivo:${NC} $DEVICE"
echo -e "${YELLOW}Intervalo:${NC} $INTERVAL segundos"
echo -e "${YELLOW}Presiona Ctrl+C para detener${NC}"
echo ""

# Contador de ciclos
CYCLE=0
FAILURES=0
MAX_FAILURES=3

while true; do
    CYCLE=$((CYCLE + 1))
    
    # Verificar si el dispositivo está conectado
    cd /mnt/c/platform-tools
    DEVICES_OUTPUT=$(./adb.exe devices 2>&1)
    
    if echo "$DEVICES_OUTPUT" | grep -q "$DEVICE.*device$"; then
        # Dispositivo conectado - hacer ping
        PING_RESULT=$(./adb.exe -s $DEVICE shell echo "ping" 2>&1)
        
        if [ "$PING_RESULT" = "ping" ]; then
            echo -e "${GREEN}✓${NC} [Ciclo $CYCLE] Conexión activa - Ping exitoso"
            FAILURES=0
        else
            echo -e "${YELLOW}⚠${NC} [Ciclo $CYCLE] Ping falló pero dispositivo listado"
            FAILURES=$((FAILURES + 1))
        fi
    else
        echo -e "${RED}✗${NC} [Ciclo $CYCLE] Dispositivo NO conectado"
        FAILURES=$((FAILURES + 1))
    fi
    
    # Si hay demasiados fallos consecutivos, intentar reconectar
    if [ $FAILURES -ge $MAX_FAILURES ]; then
        echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
        echo -e "${RED}¡Demasiados fallos! Intentando reconectar...${NC}"
        echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
        
        # Ejecutar script de sanación
        if [ -f /home/dante/projects/zync_app/fix_adb_connection.sh ]; then
            /home/dante/projects/zync_app/fix_adb_connection.sh $DEVICE
            FAILURES=0
        else
            # Reconexión manual
            ./adb.exe disconnect $DEVICE 2>/dev/null || true
            sleep 2
            ./adb.exe connect $DEVICE
            FAILURES=0
        fi
    fi
    
    # Esperar antes del siguiente ciclo
    sleep $INTERVAL
done
