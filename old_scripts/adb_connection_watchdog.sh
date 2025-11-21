#!/bin/bash
# ==============================================================================
# Watchdog de Conexión ADB - Zync App
# ==============================================================================
# Propósito: Monitorear y mantener conexión ADB estable con Windows
# Uso: ./adb_connection_watchdog.sh [IP:PORT] [CHECK_INTERVAL]
# Ejemplo: ./adb_connection_watchdog.sh 192.168.1.50:5555 30
# ==============================================================================

set -e

# Configuración
ADB_PATH="/mnt/c/platform-tools/adb.exe"
DEFAULT_DEVICE="192.168.1.50:5555"
DEFAULT_INTERVAL=30  # segundos
MAX_FAILURES=3
RECONNECT_COOLDOWN=10  # segundos entre intentos de reconexión

DEVICE="${1:-$DEFAULT_DEVICE}"
CHECK_INTERVAL="${2:-$DEFAULT_INTERVAL}"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables de estado
CYCLE=0
CONSECUTIVE_FAILURES=0
TOTAL_RECONNECTS=0
START_TIME=$(date +%s)

# Log file
LOG_DIR="/home/dante/projects/zync_app/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/adb_watchdog_$(date +%Y%m%d_%H%M%S).log"

# Función de logging
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Banner inicial
clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Watchdog de Conexión ADB - Zync App                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Dispositivo:${NC}      $DEVICE"
echo -e "${CYAN}Intervalo:${NC}        $CHECK_INTERVAL segundos"
echo -e "${CYAN}Log:${NC}              $LOG_FILE"
echo -e "${CYAN}Inicio:${NC}           $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo -e "${YELLOW}Presiona Ctrl+C para detener${NC}"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

log_message "INFO" "Watchdog iniciado - Dispositivo: $DEVICE, Intervalo: ${CHECK_INTERVAL}s"

# Función para limpiar emuladores offline
clean_offline_emulators() {
    log_message "INFO" "Limpiando emuladores offline..."
    
    cd /mnt/c/platform-tools
    local devices_output=$($ADB_PATH devices | tr -d '\r')
    local offline_emulators=$(echo "$devices_output" | grep "emulator-" | grep -E "offline|unauthorized" | awk '{print $1}' || true)
    
    if [ -n "$offline_emulators" ]; then
        echo -e "${YELLOW}  → Eliminando emuladores offline...${NC}"
        while IFS= read -r emulator; do
            if [ -n "$emulator" ]; then
                $ADB_PATH -s "$emulator" emu kill 2>/dev/null || true
                $ADB_PATH disconnect "$emulator" 2>/dev/null || true
            fi
        done <<< "$offline_emulators"
        log_message "INFO" "Emuladores offline eliminados"
        return 0
    fi
    return 1
}

# Función para verificar conexión
check_connection() {
    cd /mnt/c/platform-tools
    
    # Primero limpiar emuladores offline que puedan interferir
    local devices_output=$($ADB_PATH devices 2>&1 | tr -d '\r')
    local offline_emulators=$(echo "$devices_output" | grep "emulator-" | grep -E "offline|unauthorized" | awk '{print $1}' || true)
    
    if [ -n "$offline_emulators" ]; then
        # Limpiar silenciosamente
        while IFS= read -r emulator; do
            if [ -n "$emulator" ]; then
                $ADB_PATH -s "$emulator" emu kill 2>/dev/null || true
                $ADB_PATH disconnect "$emulator" 2>/dev/null || true
            fi
        done <<< "$offline_emulators"
        sleep 1
        # Actualizar lista de dispositivos
        devices_output=$($ADB_PATH devices 2>&1 | tr -d '\r')
    fi
    
    # Verificar si el dispositivo está listado
    if echo "$devices_output" | grep -q "$DEVICE.*device$"; then
        # Dispositivo listado, verificar con ping
        local ping_result=$($ADB_PATH -s "$DEVICE" shell echo "ping" 2>&1 || echo "error")
        
        if [ "$ping_result" = "ping" ]; then
            return 0  # Conexión OK
        else
            return 1  # Ping falló
        fi
    else
        return 1  # Dispositivo no listado
    fi
}

# Función para reconectar
reconnect_device() {
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              RECONECTANDO DISPOSITIVO                      ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_message "WARN" "Iniciando reconexión - Intento $((TOTAL_RECONNECTS + 1))"
    
    cd /mnt/c/platform-tools
    
    # Paso 1: Limpiar emuladores offline
    echo -e "${YELLOW}[1/5]${NC} Limpiando emuladores offline..."
    clean_offline_emulators
    sleep 2
    
    # Paso 2: Desconectar dispositivo
    echo -e "${YELLOW}[2/5]${NC} Desconectando dispositivo..."
    $ADB_PATH disconnect "$DEVICE" 2>/dev/null || true
    sleep 2
    
    # Paso 3: Reiniciar servidor ADB
    echo -e "${YELLOW}[3/5]${NC} Reiniciando servidor ADB..."
    $ADB_PATH kill-server 2>/dev/null || true
    sleep 3
    $ADB_PATH start-server
    sleep 2
    
    # Paso 4: Reconectar dispositivo
    echo -e "${YELLOW}[4/5]${NC} Conectando a $DEVICE..."
    local connect_output=$($ADB_PATH connect "$DEVICE" 2>&1)
    sleep 3
    
    # Paso 5: Verificar conexión
    echo -e "${YELLOW}[5/5]${NC} Verificando conexión..."
    if check_connection; then
        echo -e "${GREEN}✓${NC} Reconexión exitosa"
        log_message "INFO" "Reconexión exitosa"
        CONSECUTIVE_FAILURES=0
        TOTAL_RECONNECTS=$((TOTAL_RECONNECTS + 1))
        echo ""
        return 0
    else
        echo -e "${RED}✗${NC} Reconexión falló"
        log_message "ERROR" "Reconexión falló"
        echo ""
        return 1
    fi
}

# Función para mostrar estadísticas
show_stats() {
    local current_time=$(date +%s)
    local uptime=$((current_time - START_TIME))
    local hours=$((uptime / 3600))
    local minutes=$(((uptime % 3600) / 60))
    local seconds=$((uptime % 60))
    
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Estadísticas:${NC}"
    echo -e "  Ciclos:           $CYCLE"
    echo -e "  Reconexiones:     $TOTAL_RECONNECTS"
    echo -e "  Tiempo activo:    ${hours}h ${minutes}m ${seconds}s"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Trap para Ctrl+C
trap 'echo ""; echo -e "${YELLOW}Deteniendo watchdog...${NC}"; log_message "INFO" "Watchdog detenido por usuario"; show_stats; exit 0' INT

# Loop principal de monitoreo
while true; do
    CYCLE=$((CYCLE + 1))
    
    # Cada 20 ciclos, mostrar estadísticas
    if [ $((CYCLE % 20)) -eq 0 ]; then
        show_stats
    fi
    
    # Verificar conexión
    if check_connection; then
        # Conexión OK
        if [ $CONSECUTIVE_FAILURES -gt 0 ]; then
            echo -e "${GREEN}✓${NC} [Ciclo $CYCLE] Conexión restaurada"
            log_message "INFO" "Conexión restaurada después de $CONSECUTIVE_FAILURES fallos"
            CONSECUTIVE_FAILURES=0
        else
            echo -e "${GREEN}✓${NC} [Ciclo $CYCLE] Conexión estable - $(date '+%H:%M:%S')"
        fi
    else
        # Conexión perdida
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        echo -e "${RED}✗${NC} [Ciclo $CYCLE] Conexión perdida (Fallo $CONSECUTIVE_FAILURES/$MAX_FAILURES)"
        log_message "WARN" "Conexión perdida - Fallo consecutivo $CONSECUTIVE_FAILURES"
        
        # Si alcanzamos el máximo de fallos, intentar reconectar
        if [ $CONSECUTIVE_FAILURES -ge $MAX_FAILURES ]; then
            if reconnect_device; then
                # Reconexión exitosa
                sleep $RECONNECT_COOLDOWN
            else
                # Reconexión falló, esperar más tiempo
                echo -e "${YELLOW}⚠${NC} Esperando ${RECONNECT_COOLDOWN}s antes de reintentar..."
                sleep $RECONNECT_COOLDOWN
            fi
        fi
    fi
    
    # Esperar antes del siguiente ciclo
    sleep $CHECK_INTERVAL
done
