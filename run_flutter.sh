#!/bin/bash
# ==============================================================================
# Run Flutter - VERSIÓN CON APK PATH BRIDGE WSL→Windows
# ==============================================================================

set -e

DEVICE="192.168.1.50:5555"
PROJECT_DIR="/home/dante/projects/zync_app"
ADB_PATH="/mnt/c/platform-tools"
APK_WSL_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"
APK_WIN_PATH="C:\\platform-tools\\zync-app-temp.apk"
APK_WIN_MOUNT="/mnt/c/platform-tools/zync-app-temp.apk"

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

# Paso 0: Verificar conexión
echo -e "${YELLOW}[1/6]${NC} Limpiando emuladores fantasma..."
# Limpiar emuladores offline
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

# Verificar conexión del dispositivo
echo -e "${YELLOW}[2/6]${NC} Verificando conexión del dispositivo..."
if $ADB_PATH/adb.exe devices | grep -q "$DEVICE.*device"; then
    echo -e "${GREEN}✓${NC} Dispositivo conectado: $DEVICE"
else
    echo -e "${RED}✗${NC} Error: Dispositivo no conectado"
    echo -e "${YELLOW}Ejecuta primero: ./start_dev.sh${NC}"
    exit 1
fi
echo ""

# Paso 1: Compilar APK
echo -e "${YELLOW}[3/6]${NC} Compilando APK..."
flutter build apk --debug
echo -e "${GREEN}✓${NC} APK compilado"
echo ""

# Paso 2: Copiar APK a ubicación accesible por Windows
echo -e "${YELLOW}[4/6]${NC} Copiando APK a ubicación Windows..."
cp "$APK_WSL_PATH" "$APK_WIN_MOUNT"
echo -e "${GREEN}✓${NC} APK copiado a: $APK_WIN_PATH"
echo ""

# Paso 3: Desinstalar versión anterior (si existe)
echo -e "${YELLOW}[5/6]${NC} Limpiando instalación anterior..."
$ADB_PATH/adb.exe -s "$DEVICE" shell pm uninstall com.datainfers.zync 2>/dev/null || echo -e "${YELLOW}  → No había instalación previa${NC}"
echo -e "${GREEN}✓${NC} Listo para instalar"
echo ""

# Paso 4: Instalar APK
echo -e "${YELLOW}[6/6]${NC} Instalando APK en dispositivo..."
$ADB_PATH/adb.exe -s "$DEVICE" install -r "$APK_WIN_PATH"
echo -e "${GREEN}✓${NC} APK instalado"
echo ""

# Paso 5: Iniciar app con flutter run (para hot reload)
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Iniciando Flutter con hot reload${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Flutter run en modo attach (app ya está instalada)
flutter run -d $DEVICE
