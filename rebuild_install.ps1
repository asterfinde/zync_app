# ==============================================================================
# REBUILD & INSTALL - Recompila e instala la app después de cambios de código
# ==============================================================================
# Uso: .\rebuild_install.ps1
# Este script NO es para uso diario, solo cuando haces cambios de código
# ==============================================================================

$DEVICE_ID = "192.168.1.50:5555"

function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error { Write-Host $args -ForegroundColor Red }

Write-Info "════════════════════════════════════════════════════════════"
Write-Info "     🔄 Recompilando e Instalando App (Post-Cambios)        "
Write-Info "════════════════════════════════════════════════════════════"
Write-Host ""

# Paso 1: Desinstalar versión anterior
Write-Info "[1/2] 🗑️ Desinstalando versión anterior..."
adb -s $DEVICE_ID shell pm uninstall com.datainfers.zync 2>$null | Out-Null
Start-Sleep -Seconds 1
Write-Success "✓ App desinstalada"
Write-Host ""

# Paso 2: Ejecutar Flutter run (hace TODO: compila, instala, conecta)
Write-Info "[2/4] 🚀 Ejecutando Flutter run (compila + instala + conecta)..."
Write-Warning "⏱️ Esto puede tomar 30-60 segundos en la primera vez..."
Write-Host ""
Write-Info "IMPORTANTE: Presiona 'q' para salir cuando veas 'Flutter run key commands'"
Write-Host ""

flutter run -d $DEVICE_ID
Write-Host ""

Write-Info "════════════════════════════════════════════════════════════"
Write-Success "✅ App recompilada e instalada correctamente"
Write-Info "════════════════════════════════════════════════════════════"
Write-Host ""
Write-Warning "💡 NOTA: Para ver logs en tiempo real, ejecuta:"
Write-Host "   flutter attach -d $DEVICE_ID" -ForegroundColor White
Write-Host ""
