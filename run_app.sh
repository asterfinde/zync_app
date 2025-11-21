#!/bin/bash
# ==============================================================================
# Run App - SOLUCIÓN PRAGMÁTICA (Instalación manual vía Windows ADB)
# ==============================================================================

set -e

DEVICE="192.168.1.50:5555"
PROJECT_DIR="/home/dante/projects/zync_app"
ADB_PATH="/mnt/c/platform-tools"
APK_WSL_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"
APK_WIN_MOUNT="/mnt/c/platform-tools/zync-app.apk"
APK_WIN_PATH="C:\\platform-tools\\zync-app.apk"
PACKAGE_NAME="com.datainfers.zync"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}              🚀 Instalando y Ejecutando App                ${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

cd $PROJECT_DIR

# Paso 1: Compilar APK
echo -e "${YELLOW}[1/5]${NC} Compilando APK..."
flutter build apk --debug --quiet
echo -e "${GREEN}✓${NC} APK compilado"
echo ""

# Paso 2: Reconectar dispositivo (post-compilación)
echo -e "${YELLOW}[2/5]${NC} Conectando dispositivo..."
$ADB_PATH/adb.exe disconnect "$DEVICE" 2>/dev/null || true
sleep 1
$ADB_PATH/adb.exe connect $DEVICE > /dev/null 2>&1
sleep 3

if ! $ADB_PATH/adb.exe devices | grep -q "$DEVICE.*device"; then
    echo -e "${RED}✗${NC} Error: Dispositivo no conectado"
    echo -e "${YELLOW}Verifica que el dispositivo esté conectado a WiFi (192.168.1.50)${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Dispositivo conectado"
echo ""

# Paso 3: Copiar APK a ubicación Windows
echo -e "${YELLOW}[3/5]${NC} Preparando APK..."
cp "$APK_WSL_PATH" "$APK_WIN_MOUNT"
echo -e "${GREEN}✓${NC} APK listo"
echo ""

# Paso 4: Instalar APK (usando CMD de Windows para mayor estabilidad)
echo -e "${YELLOW}[4/5]${NC} Instalando en dispositivo..."

# Usar cmd.exe de Windows para ejecutar ADB (más estable que desde WSL)
cmd.exe /c "cd C:\\platform-tools && adb.exe -s 192.168.1.50:5555 install -r zync-app.apk" 2>&1 | grep -E "(Success|Performing|failed|error)" || true

# Verificar que se instaló
sleep 2
if $ADB_PATH/adb.exe -s "$DEVICE" shell pm list packages 2>/dev/null | grep -q "$PACKAGE_NAME"; then
    echo -e "${GREEN}✓${NC} APK instalado correctamente"
else
    echo -e "${RED}✗${NC} Error: La app no se instaló"
    exit 1
fi
echo ""

# Paso 5: Iniciar app
echo -e "${YELLOW}[5/5]${NC} Iniciando aplicación..."
$ADB_PATH/adb.exe -s "$DEVICE" shell am start -n "$PACKAGE_NAME/.MainActivity" > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Aplicación iniciada"
echo ""

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ App ejecutándose en el dispositivo${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}💡 Tip: Para hot reload, ejecuta:${NC}"
echo -e "   ${GREEN}flutter attach -d $DEVICE${NC}"
echo ""
