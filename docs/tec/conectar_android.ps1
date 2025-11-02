# Script de diagnóstico y conexión Android a WSL2
$distroName = "Ubuntu-24.04"

Write-Host "🔌 Iniciando conexión de dispositivo Android a WSL2..." -ForegroundColor Cyan

Write-Host "`n   1. Buscando dispositivo Android..."
$deviceList = usbipd list
$androidDeviceLine = $deviceList | Select-String -Pattern "Galaxy A14", "Android", "ADB Interface", "Google", "Samsung" 
if (-not $androidDeviceLine) {
    Write-Host "❌ ERROR: No se encontró ningún dispositivo Android conectado." -ForegroundColor Red
    exit
}

$busid = ($androidDeviceLine -split '\s+')[0]
Write-Host "      - Dispositivo encontrado en BUSID: $busid" -ForegroundColor Green

Write-Host "`n   2. Verificando estado de la conexión..."
$deviceStatus = usbipd list | Where-Object { $_ -match $busid }
if ($deviceStatus -match "Attached") {
    Write-Host "      - Desconectando dispositivo anterior..." -ForegroundColor Yellow
    usbipd detach --busid $busid
    Start-Sleep -Seconds 2
}
if ($deviceStatus -match "Shared") {
    Write-Host "      - Desvinculando dispositivo..." -ForegroundColor Yellow
    usbipd unbind --busid $busid
    Start-Sleep -Seconds 2
}

Write-Host "`n   3. Compartiendo dispositivo desde Windows..."
usbipd bind --busid $busid
Start-Sleep -Seconds 2

Write-Host "`n   4. Conectando dispositivo a WSL2..."
usbipd attach --wsl --busid $busid
Start-Sleep -Seconds 3

Write-Host "`n   5. Diagnóstico del dispositivo USB en WSL..."
Write-Host "      - Dispositivos USB detectados:" -ForegroundColor Cyan
wsl -d "$distroName" -e bash -c "lsusb | grep -i 'samsung\|google\|android' || echo '   ❌ No se detectó dispositivo Android'"

Write-Host "`n      - Dispositivos en /dev/bus/usb:" -ForegroundColor Cyan
wsl -d "$distroName" -e bash -c "ls -la /dev/bus/usb/*/* 2>/dev/null | tail -5"

Write-Host "`n   6. Configurando permisos USB en WSL..."
wsl -d "$distroName" -e bash -c @"
# Dar permisos a todos los dispositivos USB
sudo chmod -R 777 /dev/bus/usb/ 2>/dev/null

# Crear regla udev para dispositivos Android (persiste entre reinicios)
echo 'SUBSYSTEM==\"usb\", ATTR{idVendor}==\"04e8\", MODE=\"0666\", GROUP=\"plugdev\"' | sudo tee /etc/udev/rules.d/51-android.rules > /dev/null
echo 'SUBSYSTEM==\"usb\", ATTR{idVendor}==\"18d1\", MODE=\"0666\", GROUP=\"plugdev\"' | sudo tee -a /etc/udev/rules.d/51-android.rules > /dev/null

# Recargar reglas udev
sudo udevadm control --reload-rules 2>/dev/null
sudo udevadm trigger 2>/dev/null
"@

Write-Host "      - Permisos USB configurados" -ForegroundColor Green

Write-Host "`n   7. Reiniciando servidor ADB..."
wsl -d "$distroName" -e bash -c "adb kill-server 2>/dev/null; sleep 2; adb start-server"
Start-Sleep -Seconds 2

Write-Host "`n   8. Verificando conexión ADB..."
$adbOutput = wsl -d "$distroName" -e bash -c "adb devices -l"
Write-Host $adbOutput

# Análisis del resultado
if ($adbOutput -match "unauthorized") {
    Write-Host "`n⚠️  DISPOSITIVO NO AUTORIZADO" -ForegroundColor Yellow
    Write-Host "   Soluciones:" -ForegroundColor Cyan
    Write-Host "   1. Desbloquea tu teléfono Android" -ForegroundColor White
    Write-Host "   2. Debería aparecer un mensaje 'Permitir depuración USB'" -ForegroundColor White
    Write-Host "   3. Marca 'Permitir siempre desde este equipo' y acepta" -ForegroundColor White
    Write-Host "   4. Si no aparece mensaje, ejecuta: adb kill-server && adb start-server" -ForegroundColor White
} elseif ($adbOutput -match "device\s+usb:") {
    Write-Host "`n✅ ¡CONEXIÓN EXITOSA! Dispositivo Android conectado y autorizado." -ForegroundColor Green
} elseif ($adbOutput -match "offline") {
    Write-Host "`n⚠️  Dispositivo OFFLINE - Desconecta y reconecta el cable USB" -ForegroundColor Yellow
} else {
    Write-Host "`n❌ ADB no detecta el dispositivo" -ForegroundColor Red
    Write-Host "`n   Pasos de solución:" -ForegroundColor Cyan
    Write-Host "   1. En tu Android: Configuración > Opciones de desarrollador" -ForegroundColor White
    Write-Host "   2. Activa 'Depuración USB'" -ForegroundColor White
    Write-Host "   3. Cambia 'Configuración USB predeterminada' a 'Transferencia de archivos'" -ForegroundColor White
    Write-Host "   4. Desconecta y reconecta el cable USB" -ForegroundColor White
    Write-Host "   5. Vuelve a ejecutar este script" -ForegroundColor White
}

Write-Host "`n   Para verificar manualmente desde WSL:" -ForegroundColor Gray
Write-Host "   wsl -d $distroName" -ForegroundColor DarkGray
Write-Host "   adb devices" -ForegroundColor DarkGray