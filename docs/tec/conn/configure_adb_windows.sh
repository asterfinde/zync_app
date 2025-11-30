#!/bin/bash
# ==============================================================================
# Script de Configuración ADB - Usar ADB de Windows desde WSL2
# ==============================================================================
# Propósito: Configurar el entorno para usar el ADB de Windows (más estable)
# Uso: ./configure_adb_windows.sh
# ==============================================================================

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Configuración ADB Windows para WSL2 - Zync App        ║${NC}"
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

echo -e "${GREEN}✓${NC} ADB de Windows encontrado: $ADB_WINDOWS"
echo ""

# Crear alias en .bashrc si no existe
BASHRC="$HOME/.bashrc"
ALIAS_LINE="alias adb='/mnt/c/platform-tools/adb.exe'"
EXPORT_LINE="export ANDROID_HOME=/mnt/c/platform-tools"

if ! grep -q "$ALIAS_LINE" "$BASHRC"; then
    echo -e "${YELLOW}[1/3]${NC} Agregando alias de ADB a .bashrc..."
    echo "" >> "$BASHRC"
    echo "# ADB de Windows (más estable que el de WSL2)" >> "$BASHRC"
    echo "$ALIAS_LINE" >> "$BASHRC"
    echo "$EXPORT_LINE" >> "$BASHRC"
    echo -e "${GREEN}✓${NC} Alias agregado"
else
    echo -e "${GREEN}✓${NC} Alias ya existe en .bashrc"
fi
echo ""

# Desinstalar ADB de WSL2 si existe
echo -e "${YELLOW}[2/3]${NC} Verificando ADB de WSL2..."
if command -v adb &> /dev/null && [ "$(which adb)" != "$ADB_WINDOWS" ]; then
    echo -e "${YELLOW}⚠${NC} ADB de WSL2 detectado, removiendo..."
    sudo apt-get remove -y android-tools-adb 2>/dev/null || true
    echo -e "${GREEN}✓${NC} ADB de WSL2 removido"
else
    echo -e "${GREEN}✓${NC} No hay conflictos con ADB de WSL2"
fi
echo ""

# Crear función helper para Flutter
echo -e "${YELLOW}[3/3]${NC} Configurando función helper para Flutter..."
FLUTTER_HELPER="
# Helper para Flutter con ADB de Windows
flutter_run() {
    local device_id=\$1
    if [ -z \"\$device_id\" ]; then
        echo -e \"${RED}Error:${NC} Especifica el device ID\"
        echo \"Uso: flutter_run <device-id>\"
        echo \"\"
        echo \"Dispositivos disponibles:\"
        /mnt/c/platform-tools/adb.exe devices -l
        return 1
    fi
    flutter run -d \"\$device_id\"
}
"

if ! grep -q "flutter_run()" "$BASHRC"; then
    echo "$FLUTTER_HELPER" >> "$BASHRC"
    echo -e "${GREEN}✓${NC} Función helper agregada"
else
    echo -e "${GREEN}✓${NC} Función helper ya existe"
fi
echo ""

# Resumen
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 CONFIGURACIÓN COMPLETADA                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓${NC} ADB configurado para usar la versión de Windows"
echo -e "${GREEN}✓${NC} Alias creados en .bashrc"
echo -e "${GREEN}✓${NC} Función helper para Flutter disponible"
echo ""
echo -e "${YELLOW}IMPORTANTE:${NC} Ejecuta uno de estos para aplicar cambios:"
echo -e "  ${BLUE}source ~/.bashrc${NC}  (en la sesión actual)"
echo -e "  ${BLUE}bash${NC}              (abrir nueva sesión)"
echo ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo "  1. Conecta tu dispositivo Android vía USB"
echo "  2. Ejecuta en PowerShell (como Admin):"
echo -e "     ${BLUE}./connect_android_daily.ps1${NC}"
echo "  3. Verifica la conexión:"
echo -e "     ${BLUE}adb devices -l${NC}"
echo "  4. Ejecuta tu app:"
echo -e "     ${BLUE}flutter_run <device-id>${NC}"
echo ""
