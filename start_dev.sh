#!/bin/bash
# ==============================================================================
# Start Dev - Inicio de Jornada con Watchdog Integrado
# ==============================================================================
# Uso: ./start_dev.sh
# ==============================================================================

set -e

# Configuración
DEVICE="192.168.1.50:5555"
PROJECT_DIR="/home/dante/projects/zync_app"
ADB_PATH="/mnt/c/platform-tools/adb.exe"
WATCHDOG_PID_FILE="$PROJECT_DIR/.watchdog.pid"
CHECK_INTERVAL=30
MAX_FAILURES=3
RECONNECT_COOLDOWN=10

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Log
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/watchdog.log"

# ==============================================================================
# FUNCIONES DEL WATCHDOG
# ==============================================================================

log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

clean_offline_emulators() {
    cd /mnt/c/platform-tools
    local devices_output=$($ADB_PATH devices | tr -d '\r')
    local offline_emulators=$(echo "$devices_output" | grep "emulator-" | grep -E "offline|unauthorized" | awk '{print $1}' || true)
    
    if [ -n "$offline_emulators" ]; then
        while IFS= read -r emulator; do
            if [ -n "$emulator" ] && [[ "$emulator" == emulator-* ]]; then
                $ADB_PATH -s "$emulator" emu kill 2>/dev/null || true
                $ADB_PATH disconnect "$emulator" 2>/dev/null || true
            fi
        done <<< "$offline_emulators"
        return 0
    fi
    return 1
}

check_connection() {
    cd /mnt/c/platform-tools
    
    local devices_output=$($ADB_PATH devices 2>&1 | tr -d '\r')
    local offline_emulators=$(echo "$devices_output" | grep "emulator-" | grep -E "offline|unauthorized" | awk '{print $1}' || true)
    
    if [ -n "$offline_emulators" ]; then
        while IFS= read -r emulator; do
            if [ -n "$emulator" ] && [[ "$emulator" == emulator-* ]]; then
                $ADB_PATH -s "$emulator" emu kill 2>/dev/null || true
                $ADB_PATH disconnect "$emulator" 2>/dev/null || true
            fi
        done <<< "$offline_emulators"
        sleep 1
        devices_output=$($ADB_PATH devices 2>&1 | tr -d '\r')
    fi
    
    if echo "$devices_output" | grep -q "$DEVICE.*device$"; then
        local ping_result=$($ADB_PATH -s "$DEVICE" shell echo "ping" 2>&1 || echo "error")
        if [ "$ping_result" = "ping" ]; then
            return 0
        fi
    fi
    return 1
}

reconnect_device() {
    log_message "WARN" "Iniciando reconexión"
    cd /mnt/c/platform-tools
    
    clean_offline_emulators
    sleep 2
    
    $ADB_PATH disconnect "$DEVICE" 2>/dev/null || true
    sleep 2
    
    $ADB_PATH kill-server 2>/dev/null || true
    sleep 3
    $ADB_PATH start-server
    sleep 2
    
    $ADB_PATH connect "$DEVICE" 2>&1
    sleep 3
    
    if check_connection; then
        log_message "INFO" "Reconexión exitosa"
        return 0
    else
        log_message "ERROR" "Reconexión falló"
        return 1
    fi
}

watchdog_loop() {
    local CYCLE=0
    local CONSECUTIVE_FAILURES=0
    local TOTAL_RECONNECTS=0
    
    log_message "INFO" "Watchdog iniciado - Dispositivo: $DEVICE"
    
    while true; do
        CYCLE=$((CYCLE + 1))
        
        if check_connection; then
            if [ $CONSECUTIVE_FAILURES -gt 0 ]; then
                log_message "INFO" "Conexión restaurada"
                CONSECUTIVE_FAILURES=0
            fi
        else
            CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
            log_message "WARN" "Conexión perdida - Fallo $CONSECUTIVE_FAILURES/$MAX_FAILURES"
            
            if [ $CONSECUTIVE_FAILURES -ge $MAX_FAILURES ]; then
                if reconnect_device; then
                    CONSECUTIVE_FAILURES=0
                    TOTAL_RECONNECTS=$((TOTAL_RECONNECTS + 1))
                    sleep $RECONNECT_COOLDOWN
                else
                    sleep $RECONNECT_COOLDOWN
                fi
            fi
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# ==============================================================================
# INICIO DE JORNADA
# ==============================================================================

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}           🚀 Iniciando Jornada de Desarrollo               ${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Paso 1: Limpiar SOLO emuladores offline (no dispositivos reales)
echo -e "${YELLOW}[1/4]${NC} Limpiando emuladores offline..."
cd /mnt/c/platform-tools

DEVICES_OUTPUT=$($ADB_PATH devices -l 2>&1 | tr -d '\r')
# Solo buscar emuladores offline, no dispositivos reales
OFFLINE_EMULATORS=$(echo "$DEVICES_OUTPUT" | grep "emulator-" | grep -E "offline|unauthorized" | awk '{print $1}' || true)

if [ -n "$OFFLINE_EMULATORS" ]; then
    while IFS= read -r emulator; do
        if [ -n "$emulator" ] && [[ "$emulator" == emulator-* ]]; then
            $ADB_PATH -s "$emulator" emu kill 2>/dev/null || true
            $ADB_PATH disconnect "$emulator" 2>/dev/null || true
        fi
    done <<< "$OFFLINE_EMULATORS"
    echo -e "${GREEN}✓${NC} Emuladores offline eliminados"
else
    echo -e "${GREEN}✓${NC} No hay emuladores offline"
fi
echo ""

# Paso 2: Reiniciar servidor ADB y conectar dispositivo
echo -e "${YELLOW}[2/4]${NC} Conectando dispositivo..."
$ADB_PATH kill-server 2>/dev/null || true
sleep 2
$ADB_PATH start-server
sleep 2
$ADB_PATH connect $DEVICE
sleep 2

DEVICES_OUTPUT=$($ADB_PATH devices | tr -d '\r')
if echo "$DEVICES_OUTPUT" | grep -q "$DEVICE.*device$"; then
    echo -e "${GREEN}✓${NC} Dispositivo conectado: $DEVICE"
else
    echo -e "${RED}✗${NC} Error: No se pudo conectar el dispositivo"
    exit 1
fi
echo ""

# Paso 3: Esperar a que Flutter detecte el dispositivo
echo -e "${YELLOW}[3/4]${NC} Esperando detección de Flutter..."
cd $PROJECT_DIR
sleep 5

FLUTTER_DEVICES=$(flutter devices 2>&1)
if echo "$FLUTTER_DEVICES" | grep -q "$DEVICE"; then
    echo -e "${GREEN}✓${NC} Flutter detectó el dispositivo"
else
    echo -e "${YELLOW}⚠${NC} Flutter aún no detecta el dispositivo (continuando...)"
fi
echo ""

# Paso 4: Iniciar watchdog en background
echo -e "${YELLOW}[4/4]${NC} Iniciando watchdog de conexión..."

# Matar watchdog anterior si existe
if [ -f "$WATCHDOG_PID_FILE" ]; then
    OLD_PID=$(cat "$WATCHDOG_PID_FILE")
    if ps -p $OLD_PID > /dev/null 2>&1; then
        kill $OLD_PID 2>/dev/null || true
        echo -e "${YELLOW}  → Watchdog anterior detenido${NC}"
    fi
    rm -f "$WATCHDOG_PID_FILE"
fi

# Crear script temporal del watchdog
WATCHDOG_SCRIPT="$PROJECT_DIR/.watchdog_temp.sh"
cat > "$WATCHDOG_SCRIPT" << 'WATCHDOG_EOF'
#!/bin/bash
DEVICE="192.168.1.50:5555"
PROJECT_DIR="/home/dante/projects/zync_app"
ADB_PATH="/mnt/c/platform-tools/adb.exe"
CHECK_INTERVAL=30
MAX_FAILURES=3
RECONNECT_COOLDOWN=10
LOG_FILE="$PROJECT_DIR/logs/watchdog.log"

log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

clean_offline_emulators() {
    cd /mnt/c/platform-tools
    local devices_output=$($ADB_PATH devices | tr -d '\r')
    local offline_emulators=$(echo "$devices_output" | grep "emulator-" | grep -E "offline|unauthorized" | awk '{print $1}' || true)
    
    if [ -n "$offline_emulators" ]; then
        while IFS= read -r emulator; do
            if [ -n "$emulator" ] && [[ "$emulator" == emulator-* ]]; then
                $ADB_PATH -s "$emulator" emu kill 2>/dev/null || true
                $ADB_PATH disconnect "$emulator" 2>/dev/null || true
            fi
        done <<< "$offline_emulators"
        return 0
    fi
    return 1
}

check_connection() {
    cd /mnt/c/platform-tools
    
    local devices_output=$($ADB_PATH devices 2>&1 | tr -d '\r')
    local offline_emulators=$(echo "$devices_output" | grep "emulator-" | grep -E "offline|unauthorized" | awk '{print $1}' || true)
    
    if [ -n "$offline_emulators" ]; then
        while IFS= read -r emulator; do
            if [ -n "$emulator" ] && [[ "$emulator" == emulator-* ]]; then
                $ADB_PATH -s "$emulator" emu kill 2>/dev/null || true
                $ADB_PATH disconnect "$emulator" 2>/dev/null || true
            fi
        done <<< "$offline_emulators"
        sleep 1
        devices_output=$($ADB_PATH devices 2>&1 | tr -d '\r')
    fi
    
    if echo "$devices_output" | grep -q "$DEVICE.*device$"; then
        local ping_result=$($ADB_PATH -s "$DEVICE" shell echo "ping" 2>&1 || echo "error")
        if [ "$ping_result" = "ping" ]; then
            return 0
        fi
    fi
    return 1
}

reconnect_device() {
    log_message "WARN" "Iniciando reconexión"
    cd /mnt/c/platform-tools
    
    clean_offline_emulators
    sleep 2
    
    $ADB_PATH disconnect "$DEVICE" 2>/dev/null || true
    sleep 2
    
    $ADB_PATH kill-server 2>/dev/null || true
    sleep 3
    $ADB_PATH start-server
    sleep 2
    
    $ADB_PATH connect "$DEVICE" 2>&1
    sleep 3
    
    if check_connection; then
        log_message "INFO" "Reconexión exitosa"
        return 0
    else
        log_message "ERROR" "Reconexión falló"
        return 1
    fi
}

# Loop principal
CYCLE=0
CONSECUTIVE_FAILURES=0
TOTAL_RECONNECTS=0

log_message "INFO" "Watchdog iniciado - Dispositivo: $DEVICE"

while true; do
    CYCLE=$((CYCLE + 1))
    
    if check_connection; then
        if [ $CONSECUTIVE_FAILURES -gt 0 ]; then
            log_message "INFO" "Conexión restaurada"
            CONSECUTIVE_FAILURES=0
        fi
    else
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        log_message "WARN" "Conexión perdida - Fallo $CONSECUTIVE_FAILURES/$MAX_FAILURES"
        
        if [ $CONSECUTIVE_FAILURES -ge $MAX_FAILURES ]; then
            if reconnect_device; then
                CONSECUTIVE_FAILURES=0
                TOTAL_RECONNECTS=$((TOTAL_RECONNECTS + 1))
                sleep $RECONNECT_COOLDOWN
            else
                sleep $RECONNECT_COOLDOWN
            fi
        fi
    fi
    
    sleep $CHECK_INTERVAL
done
WATCHDOG_EOF

chmod +x "$WATCHDOG_SCRIPT"

# Iniciar watchdog en background
"$WATCHDOG_SCRIPT" &
WATCHDOG_PID=$!
echo $WATCHDOG_PID > "$WATCHDOG_PID_FILE"
echo -e "${GREEN}✓${NC} Watchdog iniciado (PID: $WATCHDOG_PID)"
echo ""

# Finalizar
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✅ Sistema listo para desarrollo${NC}"
echo ""
echo -e "${YELLOW}Watchdog corriendo en background (PID: $WATCHDOG_PID)${NC}"
echo -e "${YELLOW}Logs del watchdog: $LOG_FILE${NC}"
echo ""
echo -e "${BLUE}Próximos pasos:${NC}"
echo -e "  1. Desarrolla y haz commits"
echo -e "  2. Cuando estés listo para probar:"
echo -e "     ${GREEN}./run_flutter.sh${NC}"
echo ""
