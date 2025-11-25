# ==============================================================================
# Run Flutter App - Windows Native Version
# ==============================================================================

$ErrorActionPreference = "Stop"

$DEVICE = "192.168.1.50:5555"
$PROJECT_DIR = "C:\Users\dante\projects\zync_app"
$ADB_PATH = "C:\platform-tools"
$PACKAGE_NAME = "com.datainfers.zync"

# Colores
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error-Custom { Write-Host $args -ForegroundColor Red }

Write-Info "════════════════════════════════════════════════════════════"
Write-Info "              🚀 Ejecutando Flutter App                     "
Write-Info "════════════════════════════════════════════════════════════"
Write-Host ""

Set-Location $PROJECT_DIR

# Paso 1: Limpiar emuladores offline
Write-Info "[1/6] Limpiando emuladores fantasma..."
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

# Paso 2: Verificar/conectar dispositivo
Write-Info "[2/6] Verificando conexión del dispositivo..."
$connected = & "$ADB_PATH\adb.exe" devices | Select-String "$DEVICE\s+device"
if (-not $connected) {
    Write-Warning "  → Conectando dispositivo..."
    & "$ADB_PATH\adb.exe" disconnect $DEVICE 2>$null
    Start-Sleep -Seconds 1
    & "$ADB_PATH\adb.exe" connect $DEVICE
    Start-Sleep -Seconds 3
}

$connected = & "$ADB_PATH\adb.exe" devices | Select-String "$DEVICE\s+device"
if ($connected) {
    Write-Success "✓ Dispositivo conectado: $DEVICE"
} else {
    Write-Error-Custom "✗ Error: Dispositivo no conectado"
    exit 1
}
Write-Host ""

# Paso 3: Compilar APK
Write-Info "[3/6] Compilando APK..."
flutter build apk --debug --quiet
Write-Success "✓ APK compilado"
Write-Host ""

# Paso 4: Reconectar post-compilación
Write-Info "[4/6] Verificando conexión post-compilación..."
$connected = & "$ADB_PATH\adb.exe" devices | Select-String "$DEVICE\s+device"
if (-not $connected) {
    Write-Warning "  → Reconectando dispositivo..."
    & "$ADB_PATH\adb.exe" connect $DEVICE
    Start-Sleep -Seconds 3
}
Write-Success "✓ Dispositivo conectado"
Write-Host ""

# Paso 5: Instalar APK
Write-Info "[5/6] Instalando APK en dispositivo..."
$apkPath = "$PROJECT_DIR\build\app\outputs\flutter-apk\app-debug.apk"
$output = & "$ADB_PATH\adb.exe" -s $DEVICE install -r $apkPath 2>&1

if ($output -match "Success") {
    Write-Success "✓ APK instalado correctamente"
} else {
    # Verificar si se instaló de todas formas
    $installed = & "$ADB_PATH\adb.exe" -s $DEVICE shell pm list packages | Select-String $PACKAGE_NAME
    if ($installed) {
        Write-Success "✓ APK instalado correctamente"
    } else {
        Write-Error-Custom "✗ Error al instalar APK"
        Write-Host $output
        exit 1
    }
}
Write-Host ""

# Paso 6: Iniciar app
Write-Info "[6/6] Iniciando aplicación..."
& "$ADB_PATH\adb.exe" -s $DEVICE shell am start -n "$PACKAGE_NAME/.MainActivity" | Out-Null
Write-Success "✓ Aplicación iniciada"
Write-Host ""

Write-Info "════════════════════════════════════════════════════════════"
Write-Success "✅ App ejecutándose en el dispositivo"
Write-Info "════════════════════════════════════════════════════════════"
Write-Host ""
Write-Info "💡 Tip: Para hot reload, ejecuta:"
Write-Success "   flutter attach -d $DEVICE"
Write-Host ""
