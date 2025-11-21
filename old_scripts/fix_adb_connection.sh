#!/bin/bash
# ==============================================================================
# Script de Sanación ADB - Zync App
# ==============================================================================
# Propósito: Resolver automáticamente problemas de conexión ADB WiFi
# Uso: ./fix_adb_connection.sh [IP:PORT]
# Ejemplo: ./fix_adb_connection.sh 192.168.1.50:5555
# ==============================================================================

set -e  # Salir en caso de error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
ADB_PATH="/mnt/c/platform-tools/adb.exe"
ADB_DIR="/mnt/c/platform-tools"
DEFAULT_DEVICE="192.168.1.50:5555"
DEVICE="${1:-$DEFAULT_DEVICE}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Script de Sanación ADB - Zync App                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Paso 1: Matar servidor ADB
echo -e "${YELLOW}[1/5]${NC} Deteniendo servidor ADB..."
cd /mnt/c/platform-tools
$ADB_PATH kill-server 2>/dev/null || true
sleep 3
echo -e "${GREEN}✓${NC} Servidor ADB detenido"

# Paso 2: Iniciar servidor ADB limpio
echo -e "${YELLOW}[2/5]${NC} Iniciando servidor ADB limpio..."
$ADB_PATH start-server
sleep 2
echo -e "${GREEN}✓${NC} Servidor ADB iniciado"

# Paso 3: Conectar al dispositivo
echo -e "${YELLOW}[3/5]${NC} Conectando a dispositivo ${DEVICE}..."
CONNECT_OUTPUT=$($ADB_PATH connect $DEVICE 2>&1)

if [[ $CONNECT_OUTPUT == *"connected"* ]] || [[ $CONNECT_OUTPUT == *"already connected"* ]]; then
    echo -e "${GREEN}✓${NC} Dispositivo conectado: $DEVICE"
else
    echo -e "${RED}✗${NC} Error conectando al dispositivo"
    echo -e "${RED}  Output:${NC} $CONNECT_OUTPUT"
    echo ""
    echo -e "${YELLOW}Sugerencias:${NC}"
    echo -e "  1. Verifica que el dispositivo esté en la misma red WiFi"
    echo -e "  2. Verifica la IP del dispositivo: Configuración → Acerca del teléfono → Estado"
    echo -e "  3. Asegúrate que ADB WiFi esté habilitado en el dispositivo"
    exit 1
fi

# Paso 4: Verificar conexión y eliminar emuladores offline
echo -e "${YELLOW}[4/5]${NC} Verificando dispositivos conectados y eliminando emuladores offline..."
DEVICES_OUTPUT=$($ADB_PATH devices | tr -d '\r')  # Eliminar Windows carriage returns
echo "$DEVICES_OUTPUT"

# Eliminar emuladores offline (emulator-5554, emulator-5556, etc.)
OFFLINE_EMULATORS=$(echo "$DEVICES_OUTPUT" | grep "emulator-" | grep "offline" | awk '{print $1}' || true)

if [ -n "$OFFLINE_EMULATORS" ]; then
    echo -e "${YELLOW}⚠${NC} Emuladores offline detectados. Eliminando..."
    while IFS= read -r emulator; do
        if [ -n "$emulator" ]; then
            echo -e "  ${YELLOW}→${NC} Desconectando $emulator..."
            $ADB_PATH -s "$emulator" emu kill 2>/dev/null || true
            $ADB_PATH disconnect "$emulator" 2>/dev/null || true
        fi
    done <<< "$OFFLINE_EMULATORS"
    
    # Verificar de nuevo después de limpiar
    sleep 2
    DEVICES_OUTPUT=$($ADB_PATH devices | tr -d '\r')
    echo -e "${GREEN}✓${NC} Emuladores offline eliminados"
    echo "$DEVICES_OUTPUT"
fi

# Verificar que solo haya un dispositivo y no esté offline (SIEMPRE actualizar conteo)
DEVICE_COUNT=$(echo "$DEVICES_OUTPUT" | grep -c "device$" || true)
OFFLINE_COUNT=$(echo "$DEVICES_OUTPUT" | grep -c "offline" || true)

# Si no hay dispositivos reales conectados, el contador será 0 o vacío
if [ -z "$DEVICE_COUNT" ] || [ "$DEVICE_COUNT" = "0" ]; then
    DEVICE_COUNT=0
fi
if [ -z "$OFFLINE_COUNT" ] || [ "$OFFLINE_COUNT" = "0" ]; then
    OFFLINE_COUNT=0
fi

if [ $OFFLINE_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC} Todavía hay dispositivos offline. Reintentando limpieza..."
    $ADB_PATH kill-server
    sleep 2
    $ADB_PATH start-server
    sleep 2
    $ADB_PATH connect $DEVICE
    DEVICES_OUTPUT=$($ADB_PATH devices)
    DEVICE_COUNT=$(echo "$DEVICES_OUTPUT" | grep -c "device$" || true)
fi

if [ $DEVICE_COUNT -eq 1 ]; then
    echo -e "${GREEN}✓${NC} Un dispositivo conectado correctamente"
elif [ $DEVICE_COUNT -eq 0 ]; then
    echo -e "${RED}✗${NC} Ningún dispositivo conectado"
    exit 1
else
    echo -e "${YELLOW}⚠${NC} Múltiples dispositivos detectados ($DEVICE_COUNT)"
fi

# Paso 5: Verificar con Flutter (con reintentos)
echo -e "${YELLOW}[5/5]${NC} Verificando visibilidad en Flutter..."
cd /home/dante/projects/zync_app

MAX_FLUTTER_RETRIES=5
FLUTTER_RETRY=0
FLUTTER_DETECTED=false

while [ $FLUTTER_RETRY -lt $MAX_FLUTTER_RETRIES ]; do
    FLUTTER_RETRY=$((FLUTTER_RETRY + 1))
    
    if [ $FLUTTER_RETRY -gt 1 ]; then
        echo -e "${YELLOW}  → Intento $FLUTTER_RETRY/$MAX_FLUTTER_RETRIES...${NC}"
        sleep 3
    fi
    
    FLUTTER_DEVICES=$(flutter devices 2>&1)
    
    if echo "$FLUTTER_DEVICES" | grep -q "$DEVICE"; then
        echo -e "${GREEN}✓${NC} Dispositivo visible en Flutter"
        FLUTTER_DETECTED=true
        break
    elif echo "$FLUTTER_DEVICES" | grep -q "SM A145M"; then
        echo -e "${GREEN}✓${NC} Dispositivo SM A145M visible en Flutter"
        FLUTTER_DETECTED=true
        break
    fi
done

if [ "$FLUTTER_DETECTED" = false ]; then
    echo -e "${YELLOW}⚠${NC} Dispositivo no visible en Flutter después de $MAX_FLUTTER_RETRIES intentos"
    echo ""
    echo -e "${YELLOW}Solución:${NC} Espera 10-15 segundos y ejecuta:"
    echo -e "  ${BLUE}flutter devices${NC}"
    echo ""
    echo "O ejecuta directamente:"
    echo -e "  ${BLUE}flutter run -d ${DEVICE}${NC}"
    echo ""
fi

# Resumen final
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    SANACIÓN COMPLETADA                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓${NC} ADB saneado correctamente"
echo -e "${GREEN}✓${NC} Dispositivo conectado: ${DEVICE}"
echo ""
echo -e "${YELLOW}Próximo paso:${NC}"
echo -e "  ${BLUE}flutter run -d ${DEVICE}${NC}"
echo ""
