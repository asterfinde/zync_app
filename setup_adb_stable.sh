#!/bin/bash
# ==============================================================================
# Setup ADB Estable - Configuración Completa Post-Reinstalación WSL2
# ==============================================================================
# Propósito: Configurar ADB de Windows para máxima estabilidad
# Uso: ./setup_adb_stable.sh
# ==============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Setup ADB Estable - Post-Reinstalación WSL2             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar que existe el ADB de Windows
ADB_WINDOWS="/mnt/c/platform-tools/adb.exe"
if [ ! -f "$ADB_WINDOWS" ]; then
    echo -e "${RED}✗${NC} ADB de Windows no encontrado en: $ADB_WINDOWS"
    echo ""
    echo -e "${YELLOW}Solución:${NC}"
    echo "  1. Descarga Android Platform Tools desde:"
    echo "     https://developer.android.com/tools/releases/platform-tools"
    echo "  2. Extrae en: C:\\platform-tools\\"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} ADB de Windows encontrado"
echo ""

# Paso 1: Remover ADB de WSL2 si existe
echo -e "${YELLOW}[1/6]${NC} Verificando y removiendo ADB de WSL2..."
if command -v adb &> /dev/null && [ "$(which adb 2>/dev/null)" != "$ADB_WINDOWS" ]; then
    echo -e "${YELLOW}  → Removiendo ADB de WSL2...${NC}"
    sudo apt-get remove -y android-tools-adb android-tools-fastboot 2>/dev/null || true
    sudo apt-get autoremove -y 2>/dev/null || true
    echo -e "${GREEN}✓${NC} ADB de WSL2 removido"
else
    echo -e "${GREEN}✓${NC} No hay conflictos con ADB de WSL2"
fi
echo ""

# Paso 2: Configurar alias en .bashrc
echo -e "${YELLOW}[2/6]${NC} Configurando alias en .bashrc..."
BASHRC="$HOME/.bashrc"

# Remover configuraciones antiguas si existen
sed -i '/# ADB de Windows/d' "$BASHRC" 2>/dev/null || true
sed -i '/alias adb=/d' "$BASHRC" 2>/dev/null || true
sed -i '/export ANDROID_HOME=/d' "$BASHRC" 2>/dev/null || true
sed -i '/export ADB_SERVER_SOCKET=/d' "$BASHRC" 2>/dev/null || true

# Agregar nueva configuración
cat >> "$BASHRC" << 'EOF'

# ============================================================================
# ADB de Windows - Configuración Estable
# ============================================================================
alias adb='/mnt/c/platform-tools/adb.exe'
export ANDROID_HOME=/mnt/c/platform-tools
export ADB_SERVER_SOCKET=tcp:127.0.0.1:5037

# Helper para Flutter
flutter_run() {
    local device_id=$1
    if [ -z "$device_id" ]; then
        echo "Error: Especifica el device ID"
        echo "Uso: flutter_run <device-id>"
        echo ""
        echo "Dispositivos disponibles:"
        /mnt/c/platform-tools/adb.exe devices -l
        return 1
    fi
    flutter run -d "$device_id"
}

# Helper para limpiar ADB
adb_clean() {
    echo "Limpiando conexiones ADB..."
    /mnt/c/platform-tools/adb.exe kill-server
    sleep 2
    /mnt/c/platform-tools/adb.exe start-server
    echo "✓ ADB limpio"
}
EOF

echo -e "${GREEN}✓${NC} Alias y helpers configurados"
echo ""

# Paso 3: Dar permisos a scripts
echo -e "${YELLOW}[3/6]${NC} Configurando permisos de scripts..."
chmod +x /home/dante/projects/zync_app/*.sh 2>/dev/null || true
echo -e "${GREEN}✓${NC} Permisos configurados"
echo ""

# Paso 4: Crear directorio de logs
echo -e "${YELLOW}[4/6]${NC} Creando directorio de logs..."
mkdir -p /home/dante/projects/zync_app/logs
echo -e "${GREEN}✓${NC} Directorio de logs creado"
echo ""

# Paso 5: Configurar Flutter para usar ADB de Windows
echo -e "${YELLOW}[5/7]${NC} Configurando Flutter para usar ADB de Windows..."

# Crear estructura mínima de Android SDK
ANDROID_SDK_MINIMAL="$HOME/.android-sdk-minimal"
mkdir -p "$ANDROID_SDK_MINIMAL/platform-tools"
mkdir -p "$ANDROID_SDK_MINIMAL/licenses"

# Crear enlace simbólico al ADB de Windows
ln -sf /mnt/c/platform-tools/adb.exe "$ANDROID_SDK_MINIMAL/platform-tools/adb"

# Crear archivos de licencias aceptadas
echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > "$ANDROID_SDK_MINIMAL/licenses/android-sdk-license"
echo "84831b9409646a918e30573bab4c9c91346d8abd" > "$ANDROID_SDK_MINIMAL/licenses/android-sdk-preview-license"
echo "601085b94cd77f0b54ff86406957099ebe79c4d6" > "$ANDROID_SDK_MINIMAL/licenses/android-googletv-license"
echo "33b6a2b64607f11b759f320ef9dff4ae5c47d97a" > "$ANDROID_SDK_MINIMAL/licenses/google-gdk-license"
echo "d975f751698a77b662f1254ddbeed3901e976f5a" > "$ANDROID_SDK_MINIMAL/licenses/intel-android-extra-license"

# Configurar Flutter
flutter config --android-sdk "$ANDROID_SDK_MINIMAL" &>/dev/null

echo -e "${GREEN}✓${NC} Flutter configurado con licencias aceptadas"
echo ""

# Paso 6: Aplicar configuración
echo -e "${YELLOW}[6/7]${NC} Aplicando configuración..."
source "$BASHRC"
echo -e "${GREEN}✓${NC} Configuración aplicada"
echo ""

# Paso 7: Verificar instalación
echo -e "${YELLOW}[7/7]${NC} Verificando instalación..."

# Verificar alias
if alias adb &>/dev/null; then
    echo -e "${GREEN}✓${NC} Alias 'adb' configurado correctamente"
else
    echo -e "${RED}✗${NC} Alias 'adb' no configurado"
fi

# Verificar función helper
if declare -f flutter_run &>/dev/null; then
    echo -e "${GREEN}✓${NC} Función 'flutter_run' disponible"
else
    echo -e "${RED}✗${NC} Función 'flutter_run' no disponible"
fi

# Verificar ADB
cd /mnt/c/platform-tools
ADB_VERSION=$($ADB_WINDOWS version 2>&1 | head -n1)
echo -e "${GREEN}✓${NC} ADB: $ADB_VERSION"
echo ""

# Resumen final
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              CONFIGURACIÓN COMPLETADA                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓${NC} ADB de Windows configurado"
echo -e "${GREEN}✓${NC} Alias y helpers disponibles"
echo -e "${GREEN}✓${NC} Scripts con permisos correctos"
echo -e "${GREEN}✓${NC} Directorio de logs creado"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                  PRÓXIMOS PASOS                            ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}1. Reinicia tu terminal o ejecuta:${NC}"
echo -e "   ${BLUE}source ~/.bashrc${NC}"
echo ""
echo -e "${YELLOW}2. Limpia emuladores offline:${NC}"
echo -e "   ${BLUE}./clean_offline_devices.sh${NC}"
echo ""
echo -e "${YELLOW}3. Conecta tu dispositivo:${NC}"
echo -e "   ${BLUE}./fix_adb_connection.sh <IP:PORT>${NC}"
echo -e "   Ejemplo: ${BLUE}./fix_adb_connection.sh 192.168.1.50:5555${NC}"
echo ""
echo -e "${YELLOW}4. Inicia el watchdog (mantiene conexión estable):${NC}"
echo -e "   ${BLUE}./adb_connection_watchdog.sh <IP:PORT>${NC}"
echo ""
echo -e "${YELLOW}5. Verifica Flutter:${NC}"
echo -e "   ${BLUE}flutter doctor${NC}"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""
