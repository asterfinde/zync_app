# Auto-elevar a administrador si no lo está
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$distroName = "Ubuntu-24.04"

Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  📱 Desconexión Android/WSL2" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Se matará ADB al final, después de desconectar el dispositivo

Write-Host "🔍 Buscando dispositivos Android conectados..." -ForegroundColor Yellow
$deviceList = usbipd list
$androidDevices = $deviceList | Select-String -Pattern "Attached|Shared" | Select-String -Pattern "Galaxy|Android|Samsung|Xiaomi|OnePlus"

if (-not $androidDevices) {
    Write-Host "ℹ️  No hay dispositivos Android conectados" -ForegroundColor Gray
    Write-Host ""
    Write-Host "✅ Nada que desconectar" -ForegroundColor Green
    Write-Host ""
    exit 0
}

Write-Host "📱 Dispositivos encontrados:" -ForegroundColor Cyan
$androidDevices | ForEach-Object {
    Write-Host "   $_" -ForegroundColor Gray
}
Write-Host ""

Write-Host "🔌 Desconectando dispositivos..." -ForegroundColor Yellow

$androidDevices | ForEach-Object {
    $busid = ($_ -split '\s+')[0]
    
    if ($_ -match "Attached") {
        try {
            usbipd detach --busid $busid
            Start-Sleep -Seconds 1
            Write-Host "   ✅ BUSID $busid desconectado" -ForegroundColor Green
        } catch {
            Write-Host "   ⚠️  Error al desconectar BUSID $busid" -ForegroundColor Yellow
        }
    }
    
    if ($_ -match "Shared") {
        try {
            usbipd unbind --busid $busid
            Start-Sleep -Seconds 1
            Write-Host "   ✅ BUSID $busid desvinculado" -ForegroundColor Green
        } catch {
            Write-Host "   ⚠️  Error al desvincular BUSID $busid" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "🛑 Deteniendo servidor ADB..." -ForegroundColor Yellow
wsl -d "$distroName" -e bash -c "adb kill-server 2>/dev/null"
Start-Sleep -Seconds 2

# Verificar que ADB ya no detecta dispositivos
$adbCheck = wsl -d "$distroName" -e bash -c "adb devices 2>/dev/null | grep -v 'List of devices'"
if ($adbCheck -match "device") {
    Write-Host "⚠️  Advertencia: ADB aún detecta dispositivos" -ForegroundColor Yellow
    Write-Host "   Matando servidor ADB forzadamente..." -ForegroundColor Gray
    wsl -d "$distroName" -e bash -c "adb kill-server 2>/dev/null; sleep 1"
} else {
    Write-Host "✅ Servidor ADB detenido" -ForegroundColor Green
}

Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ DESCONEXIÓN COMPLETADA" -ForegroundColor Green
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "💾 Puedes desconectar el cable USB con seguridad" -ForegroundColor Cyan
Write-Host ""