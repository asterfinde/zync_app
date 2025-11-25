#!/bin/bash

# prevent_sleep_from_wsl.sh
# Ejecuta prevent_sleep.ps1 en Windows desde WSL2
# Autor: Auto-generado para facilitar ejecución

PROJECT_DIR="/home/datainfers/projects/zync_app"
SCRIPT_WIN_PATH="$(wslpath -w "$PROJECT_DIR/prevent_sleep.ps1")"

echo "============================================"
echo "  Ejecutando prevent_sleep.ps1 en Windows"
echo "============================================"
echo ""
echo "Ruta del script: $SCRIPT_WIN_PATH"
echo ""
echo "⚠️  IMPORTANTE: Se requieren permisos de Administrador"
echo "   Si aparece UAC (Control de Cuentas), acepta el permiso"
echo ""
echo "Ejecutando..."
echo ""

# Ejecutar PowerShell como administrador con el script
powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_WIN_PATH"

echo ""
echo "============================================"
echo "✅ Script ejecutado"
echo "============================================"
