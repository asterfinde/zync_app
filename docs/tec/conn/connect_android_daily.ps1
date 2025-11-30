# Script de diagnóstico y conexión para Flutter Nativo en Windows
$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  📱 Conexión Android (Windows Nativo)" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar si ADB está en el PATH de Windows
Write-Host "🔍 Verificando entorno ADB..." -ForegroundColor Yellow
if (Get-Command adb -ErrorAction SilentlyContinue) {
    $adbPath = (Get-Command adb).Source
    Write-Host "✅ ADB encontrado en: $adbPath" -ForegroundColor Green
} else {
    Write-Host "❌ ADB no detectado en el PATH" -ForegroundColor Red
    Write-Host "   Asegúrate de agregar 'platform-tools' a tus Variables de Entorno." -ForegroundColor Yellow
    Write-Host "   Ruta común: C:\Users\TU_USUARIO\AppData\Local\Android\Sdk\platform-tools" -ForegroundColor Gray
    exit 1
}
Write-Host ""

# 2. Asegurarse de que el dispositivo NO esté secuestrado por usbipd (si lo usaste antes)
if (Get-Command usbipd -ErrorAction SilentlyContinue) {
    Write-Host "🧹 Verificando conflictos con usbipd..." -ForegroundColor Yellow
    # Intentamos liberar todos los dispositivos por si acaso quedó alguno atado a WSL
    usbipd unbind --all 2>$null
    Write-Host "ℹ️  Se ejecutó limpieza de usbipd para asegurar que Windows tenga el control." -ForegroundColor Gray
    Write-Host ""
}

# 3. Reiniciar servidor ADB en Windows
Write-Host "🔄 Reiniciando servidor ADB (Windows)..." -ForegroundColor Yellow
adb kill-server
Start-Sleep -Seconds 2
adb start-server
Write-Host "✅ Servidor reiniciado" -ForegroundColor Green
Write-Host ""

# 4. Buscar dispositivos
Write-Host "✔️  Buscando dispositivos..." -ForegroundColor Yellow
$adbOutput = adb devices -l

if ($adbOutput -match "unauthorized") {
    Write-Host "⚠️  DISPOSITIVO NO AUTORIZADO" -ForegroundColor Red
    Write-Host "   Mira la pantalla de tu celular y acepta la huella digital RSA." -ForegroundColor White
} elseif ($adbOutput -match "device\s+product:") {
    Write-Host "✅ DISPOSITIVO CONECTADO Y LISTO" -ForegroundColor Green
    $adbOutput | Select-String "product:" | ForEach-Object { Write-Host "   📱 $_" -ForegroundColor Cyan }
    
    Write-Host ""
    Write-Host "🦋 Verificando visibilidad en Flutter..." -ForegroundColor Magenta
    flutter devices
} else {
    Write-Host "❌ No se encontraron dispositivos" -ForegroundColor Red
    Write-Host "   1. Desconecta y reconecta el cable USB." -ForegroundColor Yellow
    Write-Host "   2. Asegúrate que esté en modo 'Transferencia de Archivos' (MTP)." -ForegroundColor Yellow
    Write-Host "   3. Verifica que tengas el Driver USB de tu fabricante instalado." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Presiona Enter para salir..."
Read-Host