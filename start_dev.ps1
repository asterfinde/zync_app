# ==============================================================================
# START DEV - Inicio de Jornada (Windows Native)
# ==============================================================================

$ErrorActionPreference = "Stop"

$DEVICE = "192.168.1.50:5555"
$ADB_PATH = "C:\Android\platform-tools"  # 🔧 CORREGIDO: Ruta correcta

function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }

Write-Info "════════════════════════════════════════════════════════════"
Write-Info "           🚀 Iniciando Jornada de Desarrollo               "
Write-Info "════════════════════════════════════════════════════════════"
Write-Host ""

# Paso 0: PREVENCIÓN - Limpiar procesos ADB conflictivos
Write-Info "[0/4] 🔧 Limpiando procesos ADB conflictivos..."
Get-Process -Name "adb" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
Write-Success "✓ Procesos ADB limpiados"
Write-Host ""

# Paso 1: Limpiar emuladores offline
Write-Info "[1/4] Limpiando emuladores offline..."
$devices = & "$ADB_PATH\adb.exe" devices
$offlineEmulators = $devices | Select-String "emulator-.*offline"
if ($offlineEmulators) {
    foreach ($line in $offlineEmulators) {
        $emulator = ($line -split '\s+')[0]
        & "$ADB_PATH\adb.exe" -s $emulator emu kill 2>$null
        & "$ADB_PATH\adb.exe" disconnect $emulator 2>$null
    }
    Write-Success "✓ Emuladores offline eliminados"
} else {
    Write-Success "✓ No hay emuladores offline"
}
Write-Host ""

# Paso 2: Conectar dispositivo
Write-Info "[2/4] Conectando dispositivo Android..."
& "$ADB_PATH\adb.exe" kill-server 2>$null
Start-Sleep -Seconds 2
& "$ADB_PATH\adb.exe" start-server | Out-Null
Start-Sleep -Seconds 2
& "$ADB_PATH\adb.exe" connect $DEVICE | Out-Null
Start-Sleep -Seconds 2

$connected = & "$ADB_PATH\adb.exe" devices | Select-String "$DEVICE\s+device"
if ($connected) {
    Write-Success "✓ Dispositivo conectado: $DEVICE"
} else {
    Write-Warning "⚠ No se pudo conectar por WiFi"
    Write-Info "  Buscando dispositivo USB..."
    $usbDevice = & "$ADB_PATH\adb.exe" devices | Select-String "R58W315389R"
    if ($usbDevice) {
        Write-Success "✓ Dispositivo USB detectado: R58W315389R"
        Write-Info "  Puedes usar: flutter run -d R58W315389R"
    } else {
        Write-Warning "⚠ Conecta el dispositivo por USB o verifica WiFi"
    }
}
Write-Host ""

# Paso 3: Verificar Flutter
Write-Info "[3/4] Verificando Flutter..."
$flutterDevices = flutter devices 2>&1
if ($flutterDevices -match "SM A145M") {
    Write-Success "✓ Flutter detectó el dispositivo"
} else {
    Write-Warning "⚠ Flutter aún no detecta dispositivos"
    Write-Info "  Esto puede ser normal, espera 5 segundos..."
}
Write-Host ""

# Paso 4: PREVENCIÓN - Verificar puerto ADB
Write-Info "[4/4] Verificando puerto ADB (5037)..."
$port5037 = netstat -ano | Select-String ":5037.*LISTENING"
if ($port5037) {
    Write-Success "✓ Puerto 5037 en uso por ADB (correcto)"
} else {
    Write-Warning "⚠ Puerto 5037 no está escuchando"
    Write-Info "  Reiniciando servidor ADB..."
    & "$ADB_PATH\adb.exe" start-server | Out-Null
    Start-Sleep -Seconds 2
}
Write-Host ""

Write-Info "════════════════════════════════════════════════════════════"
Write-Success "✅ Sistema listo para desarrollo"
Write-Info "════════════════════════════════════════════════════════════"
Write-Host ""
Write-Info "Próximos pasos:"
Write-Host "  1. Desarrolla y haz commits"
Write-Host "  2. Cuando estés listo para probar:"
Write-Success "     .\run_app.ps1"
Write-Host "  3. O ejecuta directamente:"
Write-Success "     flutter run"
Write-Host ""
