# ==============================================================================
# Flutter Run con ADB Watchdog Integrado
# Opción 3: Wrapper script que ejecuta watchdog + flutter run en paralelo
# ==============================================================================

$ErrorActionPreference = "Stop"

# Configuración
$DEVICE = "192.168.1.50:5555"
$ADB_PATH = "C:\platform-tools\adb.exe"
$CHECK_INTERVAL = 5  # Segundos entre verificaciones del watchdog

# Colores
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error-Custom { Write-Host $args -ForegroundColor Red }

# Variable global para job del watchdog
$global:WatchdogJob = $null

# Función de limpieza al salir
function Cleanup {
    Write-Info "`n[CLEANUP] Deteniendo watchdog..."
    if ($global:WatchdogJob) {
        Stop-Job -Job $global:WatchdogJob -ErrorAction SilentlyContinue
        Remove-Job -Job $global:WatchdogJob -Force -ErrorAction SilentlyContinue
        Write-Success "✓ Watchdog detenido"
    }
}

# Registrar cleanup para Ctrl+C y salida normal
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Cleanup }
trap { Cleanup; throw $_ }

Write-Info "════════════════════════════════════════════════════════════"
Write-Info "     🚀 Flutter Run con ADB Watchdog (Opción 3)            "
Write-Info "════════════════════════════════════════════════════════════"
Write-Host ""

# ==============================================================================
# PASO 1: Reconexión Inicial (Síncrona)
# ==============================================================================
Write-Info "[1/4] Estableciendo conexión inicial..."

# Limpiar emuladores offline
$devices = & $ADB_PATH devices 2>$null
$offlineEmulators = $devices | Select-String "emulator-.*offline"
if ($offlineEmulators) {
    Write-Warning "  → Limpiando emuladores offline..."
    foreach ($line in $offlineEmulators) {
        $emulator = ($line -split '\s+')[0]
        & $ADB_PATH -s $emulator emu kill 2>$null
        & $ADB_PATH disconnect $emulator 2>$null
    }
}

# Verificar si ya está conectado
$connected = & $ADB_PATH devices 2>$null | Select-String "$DEVICE\s+device"

if (-not $connected) {
    Write-Warning "  → Conectando dispositivo..."
    
    # Reiniciar servidor ADB
    & $ADB_PATH kill-server 2>$null | Out-Null
    Start-Sleep -Seconds 2
    & $ADB_PATH start-server 2>$null | Out-Null
    Start-Sleep -Seconds 2
    
    # Conectar dispositivo
    & $ADB_PATH disconnect $DEVICE 2>$null | Out-Null
    Start-Sleep -Seconds 1
    & $ADB_PATH connect $DEVICE 2>$null | Out-Null
    Start-Sleep -Seconds 3
    
    # Verificar conexión
    $connected = & $ADB_PATH devices 2>$null | Select-String "$DEVICE\s+device"
}

if ($connected) {
    Write-Success "✓ Dispositivo conectado: $DEVICE"
} else {
    Write-Error-Custom "✗ No se pudo conectar al dispositivo"
    Write-Info "  Verifica que:"
    Write-Info "    1. El dispositivo esté encendido"
    Write-Info "    2. WiFi ADB esté habilitado (Herramientas Dev Inalámbricas)"
    Write-Info "    3. La IP sea correcta: $DEVICE"
    exit 1
}
Write-Host ""

# ==============================================================================
# PASO 2: Iniciar ADB Watchdog en Background
# ==============================================================================
Write-Info "[2/4] Iniciando ADB Watchdog en background..."

$watchdogScript = {
    param($Device, $AdbPath, $Interval)
    
    function Test-AdbConnection {
        param($Device, $AdbPath)
        try {
            $devices = & $AdbPath devices 2>$null
            return $devices -match "$Device\s+device"
        } catch {
            return $false
        }
    }
    
    function Repair-AdbConnection {
        param($Device, $AdbPath)
        Write-Host "[WATCHDOG] 🔧 Reparando conexión ADB..." -ForegroundColor Yellow
        
        # Reiniciar servidor ADB
        & $AdbPath kill-server 2>$null | Out-Null
        Start-Sleep -Seconds 2
        & $AdbPath start-server 2>$null | Out-Null
        Start-Sleep -Seconds 2
        
        # Reconectar dispositivo
        & $AdbPath disconnect $Device 2>$null | Out-Null
        Start-Sleep -Seconds 1
        & $AdbPath connect $Device 2>$null | Out-Null
        Start-Sleep -Seconds 3
        
        if (Test-AdbConnection -Device $Device -AdbPath $AdbPath) {
            Write-Host "[WATCHDOG] ✅ Conexión restaurada" -ForegroundColor Green
            return $true
        } else {
            Write-Host "[WATCHDOG] ❌ No se pudo restaurar conexión" -ForegroundColor Red
            return $false
        }
    }
    
    # Loop principal del watchdog
    while ($true) {
        if (-not (Test-AdbConnection -Device $Device -AdbPath $AdbPath)) {
            Repair-AdbConnection -Device $Device -AdbPath $AdbPath
        }
        Start-Sleep -Seconds $Interval
    }
}

# Iniciar watchdog como background job
$global:WatchdogJob = Start-Job -ScriptBlock $watchdogScript -ArgumentList $DEVICE, $ADB_PATH, $CHECK_INTERVAL
Write-Success "✓ Watchdog iniciado (Job ID: $($global:WatchdogJob.Id))"
Write-Info "  → Monitoreando conexión cada $CHECK_INTERVAL segundos"
Write-Host ""

# ==============================================================================
# PASO 3: Verificar Dispositivos Disponibles
# ==============================================================================
Write-Info "[3/4] Verificando dispositivos Flutter..."

$flutterDevices = flutter devices 2>$null
if ($flutterDevices -match $DEVICE -or $flutterDevices -match "Galaxy") {
    Write-Success "✓ Flutter detecta el dispositivo"
} else {
    Write-Warning "⚠ Flutter no detecta el dispositivo claramente, continuando..."
}
Write-Host ""

# ==============================================================================
# PASO 4: Ejecutar Flutter Run
# ==============================================================================
Write-Info "[4/4] Iniciando Flutter Run..."
Write-Info "════════════════════════════════════════════════════════════"
Write-Host ""
Write-Info "💡 COMANDOS DISPONIBLES:"
Write-Info "   r  → Hot reload"
Write-Info "   R  → Hot restart"
Write-Info "   q  → Salir"
Write-Host ""
Write-Info "🛡️  ADB Watchdog: ACTIVO (auto-reconexión cada ${CHECK_INTERVAL}s)"
Write-Info "════════════════════════════════════════════════════════════"
Write-Host ""

try {
    # Ejecutar flutter run (bloqueante hasta que termina)
    flutter run -d $DEVICE
} catch {
    Write-Error-Custom "`n✗ Error en flutter run: $_"
} finally {
    # Siempre ejecutar cleanup al salir
    Cleanup
}

Write-Host ""
Write-Info "════════════════════════════════════════════════════════════"
Write-Success "✅ Sesión de desarrollo finalizada"
Write-Info "════════════════════════════════════════════════════════════"
