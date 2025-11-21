#!/bin/bash

# restore_sleep_from_wsl.sh
# Ejecuta restore_sleep.ps1 en Windows desde WSL2
# Autor: Auto-generado para facilitar ejecución

PROJECT_DIR="/home/datainfers/projects/zync_app"
SCRIPT_WIN_PATH="$(wslpath -w "$PROJECT_DIR/restore_sleep.ps1")"

echo "============================================"
echo "  Restaurando suspensión normal en Windows"
echo "============================================"
echo ""
echo "Ejecutando..."
echo ""

# Ejecutar PowerShell con el script
powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_WIN_PATH"

echo ""
echo "============================================"
echo "✅ Configuración restaurada"
echo "============================================"
