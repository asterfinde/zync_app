#!/bin/bash
# ==============================================================================
# Run Flutter - SOLUCIÓN FINAL (Push Manual + Flutter Attach)
# ==============================================================================

set -e

DEVICE="192.168.1.50:5555"
PROJECT_DIR="/home/dante/projects/zync_app"
ADB_PATH="/mnt/c/platform-tools"
APK_WSL_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"
PACKAGE_NAME="com.datainfers.zync"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}              🚀 Ejecutando Flutter App                     ${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

cd $PROJECT_DIR

# Paso 1: Limpiar emuladores fantasma
echo -e "${YELLOW}[1/7]${NC} Limpiando emuladores fantasma..."
OFFLINE_EMULATORS=$($ADB_PATH/adb.exe devices | grep "emulator-" | grep -E "offline|unauthorized" | awk '{print $1}' || true)
if [ -n "$OFFLINE_EMULATORS" ]; then
    while IFS= read -r emulator; do
        if [ -n "$emulator" ]; then
            $ADB_PATH/adb.exe -s "$emulator" emu kill 2>/dev/null || true
            $ADB_PATH/adb.exe disconnect "$emulator" 2>/dev/null || true
        fi
    done <<< "$OFFLINE_EMULATORS"
    echo -e "${GREEN}✓${NC} Emuladores offline eliminados"
else
    echo -e "${GREEN}✓${NC} No hay emuladores offline"
fi
echo ""

# Paso 2: Verificar conexión (reconectar si es necesario)
echo -e "${YELLOW}[2/7]${NC} Verificando conexión del dispositivo..."
CONNECTION_ATTEMPTS=0
MAX_ATTEMPTS=3

while [ $CONNECTION_ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    if $ADB_PATH/adb.exe devices | grep -q "$DEVICE.*device"; then
        echo -e "${GREEN}✓${NC} Dispositivo conectado: $DEVICE"
        break
    else
        CONNECTION_ATTEMPTS=$((CONNECTION_ATTEMPTS + 1))
        echo -e "${YELLOW}  → Intento $CONNECTION_ATTEMPTS/$MAX_ATTEMPTS: Conectando dispositivo...${NC}"
        $ADB_PATH/adb.exe disconnect "$DEVICE" 2>/dev/null || true
        sleep 2
        $ADB_PATH/adb.exe connect $DEVICE
        sleep 3
    fi
done

if ! $ADB_PATH/adb.exe devices | grep -q "$DEVICE.*device"; then
    echo -e "${RED}✗${NC} Error: No se pudo conectar el dispositivo después de $MAX_ATTEMPTS intentos"
    exit 1
fi
echo ""

# Paso 3: Compilar APK
echo -e "${YELLOW}[3/7]${NC} Compilando APK..."
flutter build apk --debug
echo -e "${GREEN}✓${NC} APK compilado"
echo ""

# Paso 3.5: Reconectar dispositivo (puede haberse desconectado durante la compilación)
echo -e "${YELLOW}[3.5/7]${NC} Verificando conexión post-compilación..."
if ! $ADB_PATH/adb.exe devices | grep -q "$DEVICE.*device"; then
    echo -e "${YELLOW}  → Dispositivo desconectado, reconectando...${NC}"
    $ADB_PATH/adb.exe disconnect "$DEVICE" 2>/dev/null || true
    sleep 2
    $ADB_PATH/adb.exe connect $DEVICE
    sleep 3
    
    if $ADB_PATH/adb.exe devices | grep -q "$DEVICE.*device"; then
        echo -e "${GREEN}✓${NC} Dispositivo reconectado"
    else
        echo -e "${RED}✗${NC} Error: No se pudo reconectar el dispositivo"
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} Dispositivo aún conectado"
fi
echo ""

# Paso 4: Push APK al dispositivo
echo -e "${YELLOW}[4/8]${NC} Copiando APK al dispositivo..."
$ADB_PATH/adb.exe -s "$DEVICE" push "$APK_WSL_PATH" /data/local/tmp/app.apk 2>&1 | grep -v "^$" | tail -1
echo -e "${GREEN}✓${NC} APK copiado"
echo ""

# Paso 5: Desinstalar versión anterior
echo -e "${YELLOW}[5/8]${NC} Desinstalando versión anterior..."
$ADB_PATH/adb.exe -s "$DEVICE" shell pm uninstall "$PACKAGE_NAME" 2>/dev/null && echo -e "${GREEN}✓${NC} Versión anterior desinstalada" || echo -e "${YELLOW}  → No había instalación previa${NC}"
echo ""

# Paso 6: Instalar APK
echo -e "${YELLOW}[6/8]${NC} Instalando APK..."
INSTALL_OUTPUT=$($ADB_PATH/adb.exe -s "$DEVICE" shell pm install /data/local/tmp/app.apk 2>&1)
if echo "$INSTALL_OUTPUT" | grep -q "Success"; then
    echo -e "${GREEN}✓${NC} APK instalado correctamente"
elif [ -z "$INSTALL_OUTPUT" ]; then
    # Si no hay output, verificar si se instaló
    if $ADB_PATH/adb.exe -s "$DEVICE" shell pm list packages | grep -q "$PACKAGE_NAME"; then
        echo -e "${GREEN}✓${NC} APK instalado correctamente"
    else
        echo -e "${RED}✗${NC} Error: Instalación falló"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} Error al instalar:"
    echo "$INSTALL_OUTPUT"
    exit 1
fi
echo ""

# Paso 7: Iniciar app
echo -e "${YELLOW}[7/8]${NC} Iniciando aplicación..."
$ADB_PATH/adb.exe -s "$DEVICE" shell am start -n "$PACKAGE_NAME/.MainActivity" 2>&1 | grep -v "^$" | head -3
echo -e "${GREEN}✓${NC} Aplicación iniciada"
echo ""

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ App instalada y ejecutándose${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Nota:${NC} Para usar hot reload, ejecuta en otra terminal:"
echo -e "  ${GREEN}flutter attach -d $DEVICE${NC}"
echo ""
