# ==============================================================================
# STOP DEV - Cierre de Jornada (Windows Native)
# ==============================================================================
# Uso: .\stop_dev.ps1
# Ejecuta ANTES de desconectar el cable USB del Android
# ==============================================================================

$ADB_PATH = "C:\Android\platform-tools"

function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }

Write-Info "════════════════════════════════════════════════════════════"
Write-Info "           🌙 Cerrando Jornada de Desarrollo                "
Write-Info "════════════════════════════════════════════════════════════"
Write-Host ""

# Paso 1: Detener procesos de Flutter
Write-Info "[1/3] 🛑 Deteniendo procesos de Flutter..."
$flutterProcesses = Get-Process | Where-Object { 
    $_.ProcessName -match "flutter|dart|gradle" 
}
if ($flutterProcesses) {
    $flutterProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Success "✓ Procesos de Flutter/Dart/Gradle detenidos"
} else {
    Write-Success "✓ No hay procesos de desarrollo corriendo"
}
Write-Host ""

# Paso 2: Limpiar servidor ADB (libera recursos)
Write-Info "[2/3] 🔧 Limpiando servidor ADB..."
& "$ADB_PATH\adb.exe" kill-server 2>$null | Out-Null
Start-Sleep -Seconds 1
Write-Success "✓ Servidor ADB detenido (liberando puerto 5037)"
Write-Host ""

# Paso 3: Verificar limpieza
Write-Info "[3/3] ✅ Verificando limpieza..."
$adbProcesses = Get-Process -Name "adb" -ErrorAction SilentlyContinue
if ($adbProcesses) {
    $adbProcesses | Stop-Process -Force
    Write-Warning "⚠ Procesos ADB zombies eliminados"
} else {
    Write-Success "✓ No hay procesos ADB residuales"
}
Write-Host ""

Write-Info "════════════════════════════════════════════════════════════"
Write-Success "✅ Jornada cerrada - Puedes desconectar el USB"
Write-Info "════════════════════════════════════════════════════════════"
Write-Host ""
Write-Host "💡 Ahora puedes:" -ForegroundColor Yellow
Write-Host "   1. Desconectar el cable USB del Android" -ForegroundColor White
Write-Host "   2. Cerrar VS Code" -ForegroundColor White
Write-Host "   3. Apagar la PC con seguridad" -ForegroundColor White
Write-Host ""
Write-Host "Hasta la próxima sesión! 👋" -ForegroundColor Cyan
Write-Host ""
