#!/bin/bash
# ==============================================================================
# Instalar y Ejecutar App - Solución para ADB de Windows + WSL2
# ==============================================================================

set -e

DEVICE="${1:-192.168.1.50:5555}"
APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
PACKAGE_NAME="com.datainfers.zync"

echo "🚀 Instalando y ejecutando Zync App..."
echo ""

# 1. Compilar APK
echo "[1/5] Compilando APK..."
flutter build apk --debug
echo "✓ APK compilado"
echo ""

# 2. Copiar APK a ubicación accesible desde Windows
echo "[2/5] Copiando APK..."
cp "$APK_PATH" /mnt/c/platform-tools/zync-app.apk
echo "✓ APK copiado"
echo ""

# 3. Conectar dispositivo
echo "[3/5] Conectando dispositivo..."
cd /mnt/c/platform-tools
./adb.exe connect "$DEVICE" > /dev/null 2>&1 || true
echo "✓ Dispositivo conectado"
echo ""

# 4. Desinstalar versión anterior (si existe)
echo "[4/5] Desinstalando versión anterior..."
./adb.exe -s "$DEVICE" uninstall "$PACKAGE_NAME" 2>/dev/null || echo "  (No había versión anterior)"
echo ""

# 5. Instalar nueva versión
echo "[5/5] Instalando app..."
./adb.exe -s "$DEVICE" install C:\\platform-tools\\zync-app.apk
echo ""

echo "✅ App instalada correctamente!"
echo ""
echo "Para ejecutar con hot reload, usa:"
echo "  flutter attach -d $DEVICE"
