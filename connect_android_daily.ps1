# Este script debe ejecutarse con permisos de administrador
# Verificar que tiene permisos admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ ERROR: Este script requiere permisos de administrador" -ForegroundColor Red
    Write-Host "   Ejecútalo desde un PowerShell con permisos elevados" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Presiona Enter para cerrar..."
    Read-Host
    exit 1
}

$distroName = "Ubuntu-24.04"
$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  📱 Conexión Android/WSL2" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔍 Buscando dispositivo Android..." -ForegroundColor Yellow
$deviceList = usbipd list
$androidDeviceLine = $deviceList | Select-String -Pattern "Galaxy|Android|ADB|Samsung|Xiaomi|OnePlus|Motorola|Huawei"

if (-not $androidDeviceLine) {
    Write-Host "❌ Dispositivo Android no encontrado" -ForegroundColor Red
    Write-Host "" 
    Write-Host "Verificar:" -ForegroundColor Yellow
    Write-Host "  • Cable USB conectado" -ForegroundColor White
    Write-Host "  • Dispositivo desbloqueado" -ForegroundColor White
    Write-Host "  • Depuración USB activada" -ForegroundColor White
    Write-Host ""
    exit 1
}

$busid = ($androidDeviceLine -split '\s+')[0]
Write-Host "✅ Dispositivo encontrado: $busid" -ForegroundColor Green
Write-Host ""

Write-Host "🧹 Limpiando conexiones previas..." -ForegroundColor Yellow
$deviceStatus = usbipd list | Where-Object { $_ -match $busid }

if ($deviceStatus -match "Attached") {
    usbipd detach --busid $busid 2>$null
    Start-Sleep -Seconds 2
}

if ($deviceStatus -match "Shared") {
    usbipd unbind --busid $busid 2>$null
    Start-Sleep -Seconds 2
}

Write-Host "✅ Limpieza completada" -ForegroundColor Green
Write-Host ""

Write-Host "🔗 Conectando a WSL2..." -ForegroundColor Yellow
try {
    usbipd bind --busid $busid
    Start-Sleep -Seconds 2
    # Sintaxis moderna de usbipd-win
    usbipd attach --wsl --busid $busid
    Start-Sleep -Seconds 3
    
    # Verificar que realmente quedó attached
    $attachStatus = usbipd list | Where-Object { $_ -match $busid }
    if ($attachStatus -match "Attached") {
        Write-Host "✅ Dispositivo conectado a WSL2" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Primer intento no completó, reintentando..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        usbipd attach --wsl --busid $busid
        Start-Sleep -Seconds 3
        
        $attachStatus = usbipd list | Where-Object { $_ -match $busid }
        if ($attachStatus -match "Attached") {
            Write-Host "✅ Dispositivo conectado a WSL2 (segundo intento)" -ForegroundColor Green
        } else {
            Write-Host "❌ Error: Dispositivo no quedó attached después de reintentos" -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Host "❌ Error al conectar: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

Write-Host "🔐 Configurando permisos USB..." -ForegroundColor Yellow
wsl -d "$distroName" -e bash -c "sudo chmod -R 777 /dev/bus/usb/ 2>/dev/null"
Write-Host "✅ Permisos configurados" -ForegroundColor Green
Write-Host ""

Write-Host "🔄 Reiniciando servidor ADB..." -ForegroundColor Yellow
wsl -d "$distroName" -e bash -c "adb kill-server 2>/dev/null; sleep 2; adb start-server 2>/dev/null"
Start-Sleep -Seconds 2
Write-Host "✅ Servidor ADB reiniciado" -ForegroundColor Green
Write-Host ""

Write-Host "✔️  Verificando conexión con ADB..." -ForegroundColor Yellow
Write-Host "   (Esto puede tomar hasta 15 segundos)" -ForegroundColor Gray

# Reintentar hasta 3 veces con delays progresivos
$maxRetries = 3
$deviceDetected = $false

for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
    if ($attempt -gt 1) {
        Write-Host "   Intento $attempt/$maxRetries..." -ForegroundColor Yellow
    }
    
    Start-Sleep -Seconds 5
    $adbOutput = wsl -d "$distroName" -e bash -c "adb devices -l 2>/dev/null"
    
    if ($adbOutput -match "unauthorized") {
        Write-Host "⚠️  DISPOSITIVO NO AUTORIZADO" -ForegroundColor Yellow
        Write-Host "   Desbloquea el dispositivo y acepta depuración USB" -ForegroundColor White
        Write-Host ""
        exit 1
    } elseif ($adbOutput -match "device\s+usb:") {
        $deviceDetected = $true
        break
    }
    
    # Si no se detectó y quedan intentos, esperar más
    if ($attempt -lt $maxRetries) {
        Write-Host "   ⏳ Esperando a que ADB detecte el dispositivo..." -ForegroundColor Gray
    }
}

if ($deviceDetected) {
    Write-Host ""
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "✅ CONEXIÓN EXITOSA" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ ADB no detectó el dispositivo después de $maxRetries intentos" -ForegroundColor Red
    Write-Host ""
    Write-Host "Posibles causas:" -ForegroundColor Yellow
    Write-Host "   • Cable USB defectuoso o de solo carga" -ForegroundColor White
    Write-Host "   • Depuración USB no autorizada en el dispositivo" -ForegroundColor White
    Write-Host "   • Modo USB incorrecto (debe ser MTP/Transferencia de archivos)" -ForegroundColor White
    Write-Host "   • Puerto USB de la PC con problemas" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 Alternativa: Usa WiFi ADB (más estable)" -ForegroundColor Cyan
    Write-Host "   Ver: docs/dev/wifi-adb-connection-guide.md" -ForegroundColor Gray
    Write-Host ""
    exit 1
}