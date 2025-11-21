#!/bin/bash
# ==============================================================================
# Script de Limpieza de Dispositivos Offline - Zync App
# ==============================================================================
# Propósito: Eliminar emuladores y dispositivos offline que bloquean ADB
# Uso: ./clean_offline_devices.sh
# ==============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
ADB_PATH="/mnt/c/platform-tools/adb.exe"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Limpieza de Dispositivos Offline - Zync App           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Cambiar al directorio de platform-tools
cd /mnt/c/platform-tools

# Paso 1: Listar dispositivos actuales
echo -e "${YELLOW}[1/4]${NC} Listando dispositivos conectados..."
DEVICES_OUTPUT=$($ADB_PATH devices -l | tr -d '\r')
echo "$DEVICES_OUTPUT"
echo ""

# Paso 2: Identificar dispositivos offline
echo -e "${YELLOW}[2/4]${NC} Identificando dispositivos offline..."
# Capturar dispositivos que estén explícitamente offline o unauthorized
OFFLINE_DEVICES=$(echo "$DEVICES_OUTPUT" | grep -E "offline|unauthorized" | awk '{print $1}' || true)

if [ -z "$OFFLINE_DEVICES" ]; then
    echo -e "${GREEN}✓${NC} No hay dispositivos offline"
else
    echo -e "${YELLOW}⚠${NC} Dispositivos offline encontrados:"
    echo "$OFFLINE_DEVICES"
fi
echo ""

# Paso 3: Eliminar dispositivos offline
if [ -n "$OFFLINE_DEVICES" ]; then
    echo -e "${YELLOW}[3/4]${NC} Eliminando dispositivos offline..."
    
    while IFS= read -r device; do
        if [ -n "$device" ]; then
            echo -e "  ${YELLOW}→${NC} Desconectando: $device"
            
            # Si es un emulador, intentar matarlo
            if [[ "$device" == emulator-* ]]; then
                $ADB_PATH -s "$device" emu kill 2>/dev/null || true
                sleep 1
            fi
            
            # Desconectar el dispositivo
            $ADB_PATH disconnect "$device" 2>/dev/null || true
            sleep 1
        fi
    done <<< "$OFFLINE_DEVICES"
    
    echo -e "${GREEN}✓${NC} Dispositivos offline eliminados"
else
    echo -e "${YELLOW}[3/4]${NC} No hay dispositivos para eliminar"
fi
echo ""

# Paso 4: Reiniciar servidor ADB limpio
echo -e "${YELLOW}[4/4]${NC} Reiniciando servidor ADB..."
$ADB_PATH kill-server 2>/dev/null || true
sleep 3
$ADB_PATH start-server
sleep 3

# Limpiar cualquier emulador que aparezca después del reinicio
DEVICES_AFTER=$($ADB_PATH devices -l | tr -d '\r')
OFFLINE_AFTER=$(echo "$DEVICES_AFTER" | grep "emulator-" | grep -E "offline|unauthorized" | awk '{print $1}' || true)

if [ -n "$OFFLINE_AFTER" ]; then
    echo -e "${YELLOW}  → Limpiando emuladores que aparecieron después del reinicio...${NC}"
    while IFS= read -r emulator; do
        if [ -n "$emulator" ]; then
            $ADB_PATH -s "$emulator" emu kill 2>/dev/null || true
            $ADB_PATH disconnect "$emulator" 2>/dev/null || true
        fi
    done <<< "$OFFLINE_AFTER"
    sleep 2
fi

echo -e "${GREEN}✓${NC} Servidor ADB reiniciado"
echo ""

# Verificación final
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  ESTADO FINAL DE ADB                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
$ADB_PATH devices -l
echo ""

# Contar dispositivos activos
ACTIVE_DEVICES=$($ADB_PATH devices | grep -c "device$" || true)
if [ "$ACTIVE_DEVICES" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} $ACTIVE_DEVICES dispositivo(s) activo(s)"
else
    echo -e "${YELLOW}⚠${NC} No hay dispositivos activos"
    echo -e "${YELLOW}Próximo paso:${NC} Conecta tu dispositivo con:"
    echo -e "  ${BLUE}./fix_adb_connection.sh <IP:PORT>${NC}"
fi
echo ""
