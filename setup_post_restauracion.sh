#!/bin/bash
# ==============================================================================
# Script de Setup Post-Restauración - Zync App
# ==============================================================================
# Propósito: Configurar automáticamente el proyecto después de clonar desde GitHub
# Uso: ./setup_post_restauracion.sh
# ==============================================================================

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}║        🚀 SETUP POST-RESTAURACIÓN - ZYNC APP 🚀           ║${NC}"
echo -e "${CYAN}║                                                            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Este script configurará automáticamente:${NC}"
echo -e "  • Permisos de ejecución para todos los scripts"
echo -e "  • Configuración de ADB de Windows"
echo -e "  • Dependencias de Flutter"
echo -e "  • Verificación del sistema"
echo ""
read -p "¿Continuar? (s/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    echo -e "${YELLOW}Setup cancelado${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    INICIANDO SETUP                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Paso 1: Dar permisos a todos los scripts
echo -e "${YELLOW}[1/5]${NC} Configurando permisos de scripts..."
chmod +x *.sh 2>/dev/null || true
chmod +x scripts/*.sh 2>/dev/null || true
echo -e "${GREEN}✓${NC} Permisos configurados"
echo ""

# Paso 2: Configurar ADB de Windows
echo -e "${YELLOW}[2/5]${NC} Configurando ADB de Windows..."
if [ -f "configure_adb_windows.sh" ]; then
    ./configure_adb_windows.sh
else
    echo -e "${RED}✗${NC} Script configure_adb_windows.sh no encontrado"
    exit 1
fi
echo ""

# Paso 3: Recargar .bashrc
echo -e "${YELLOW}[3/5]${NC} Recargando configuración de shell..."
source ~/.bashrc
echo -e "${GREEN}✓${NC} Configuración recargada"
echo ""

# Paso 4: Instalar dependencias de Flutter
echo -e "${YELLOW}[4/5]${NC} Instalando dependencias de Flutter..."
if command -v fvm &> /dev/null; then
    echo -e "  ${BLUE}→${NC} Usando FVM..."
    fvm flutter pub get
    echo -e "${GREEN}✓${NC} Dependencias instaladas"
else
    echo -e "${YELLOW}⚠${NC} FVM no encontrado, intentando con flutter..."
    if command -v flutter &> /dev/null; then
        flutter pub get
        echo -e "${GREEN}✓${NC} Dependencias instaladas"
    else
        echo -e "${RED}✗${NC} Flutter no disponible"
        echo -e "  ${YELLOW}→${NC} Instala FVM: dart pub global activate fvm"
        echo -e "  ${YELLOW}→${NC} Luego: fvm install stable && fvm use stable"
    fi
fi
echo ""

# Paso 5: Verificar setup
echo -e "${YELLOW}[5/5]${NC} Verificando configuración..."
echo ""
./verify_setup.sh

# Resumen final
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  SETUP COMPLETADO                          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓${NC} Proyecto configurado correctamente"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}PRÓXIMOS PASOS IMPORTANTES:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}1. Configurar Windsurf:${NC}"
echo -e "   • Cierra Windsurf completamente"
echo -e "   • Abre: File > Open Workspace from File..."
echo -e "   • Selecciona: zync_app.code-workspace"
echo -e "   • Verifica que el footer muestre: ${GREEN}WSL: Ubuntu-24.04${NC}"
echo ""
echo -e "${BLUE}2. Configurar WSL2 (Opcional pero recomendado):${NC}"
echo -e "   • Copia .wslconfig.example a: ${CYAN}C:\\Users\\$(whoami)\\.wslconfig${NC}"
echo -e "   • Edita los valores según tu hardware"
echo -e "   • Ejecuta en PowerShell: ${CYAN}wsl --shutdown${NC}"
echo -e "   • Espera 10 segundos y vuelve a abrir WSL2"
echo ""
echo -e "${BLUE}3. Conectar dispositivo Android:${NC}"
echo -e "   ${YELLOW}Opción A - USB (requiere PowerShell Admin):${NC}"
echo -e "   • Ejecuta: ${CYAN}./connect_android_daily.ps1${NC}"
echo ""
echo -e "   ${YELLOW}Opción B - WiFi (recomendado, más estable):${NC}"
echo -e "   • Habilita ADB WiFi en tu dispositivo"
echo -e "   • Ejecuta: ${CYAN}./fix_adb_connection.sh <IP:PORT>${NC}"
echo -e "   • Ejemplo: ${CYAN}./fix_adb_connection.sh 192.168.1.50:5555${NC}"
echo ""
echo -e "${BLUE}4. Verificar conexión:${NC}"
echo -e "   • Ejecuta: ${CYAN}adb devices -l${NC}"
echo -e "   • Debe mostrar tu dispositivo conectado"
echo ""
echo -e "${BLUE}5. Iniciar desarrollo:${NC}"
echo -e "   • Ejecuta: ${CYAN}./start_day.sh${NC}"
echo -e "   • O directamente: ${CYAN}flutter run${NC}"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}DOCUMENTACIÓN:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  📖 Guía completa: ${CYAN}cat SOLUCION_WSL2_ADB.md${NC}"
echo -e "  📖 Verificar setup: ${CYAN}./verify_setup.sh${NC}"
echo -e "  📖 Troubleshooting: ${CYAN}cat SOLUCION_WSL2_ADB.md${NC} (sección Troubleshooting)"
echo ""
echo -e "${GREEN}¡Listo para desarrollar! 🚀${NC}"
echo ""
