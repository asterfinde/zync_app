# ==============================================================================
# 🔥 FIX USBIPD FIREWALL - Resolver warning TCP port 3240
# ==============================================================================
# IMPORTANTE: Ejecutar este script como ADMINISTRADOR en PowerShell
# Uso: .\fix_usbipd_firewall.ps1
# ==============================================================================

#Requires -RunAsAdministrator

Write-Host "🔥 Iniciando script de corrección de firewall para usbipd..." -ForegroundColor Cyan
Write-Host ""

# ==============================================================================
# PASO 1: Verificar servicio usbipd
# ==============================================================================
Write-Host "📋 PASO 1: Verificando servicio usbipd..." -ForegroundColor Yellow
$usbipdService = Get-Service -Name usbipd -ErrorAction SilentlyContinue

if ($usbipdService) {
    Write-Host "   ✅ Servicio usbipd encontrado: $($usbipdService.Status)" -ForegroundColor Green
    if ($usbipdService.Status -ne 'Running') {
        Write-Host "   ⚠️  Servicio no está corriendo. Iniciando..." -ForegroundColor Yellow
        Start-Service usbipd
        Write-Host "   ✅ Servicio iniciado" -ForegroundColor Green
    }
} else {
    Write-Host "   ❌ Servicio usbipd no encontrado. Instalar usbipd-win primero." -ForegroundColor Red
    exit 1
}

# ==============================================================================
# PASO 2: Verificar proceso escuchando en puerto 3240
# ==============================================================================
Write-Host ""
Write-Host "📋 PASO 2: Verificando listener en puerto 3240..." -ForegroundColor Yellow
$listener = netstat -ano | Select-String ":3240.*LISTENING"

if ($listener) {
    Write-Host "   ✅ Puerto 3240 está siendo usado:" -ForegroundColor Green
    $listener | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
    
    # Extraer PID
    $pidMatch = $listener[0] -match '\s+(\d+)\s*$'
    if ($pidMatch) {
        $pid = $matches[1]
        Write-Host "   📌 PID del proceso: $pid" -ForegroundColor Cyan
        
        # Obtener info del proceso
        $process = Get-CimInstance Win32_Process -Filter "ProcessId=$pid" -ErrorAction SilentlyContinue
        if ($process) {
            Write-Host "   📂 Ejecutable: $($process.ExecutablePath)" -ForegroundColor Cyan
            $usbipdExePath = $process.ExecutablePath
        }
    }
} else {
    Write-Host "   ⚠️  No se detectó listener en puerto 3240" -ForegroundColor Yellow
}

# ==============================================================================
# PASO 3: Verificar reglas de firewall existentes
# ==============================================================================
Write-Host ""
Write-Host "📋 PASO 3: Verificando reglas de firewall existentes..." -ForegroundColor Yellow

$existingRules = Get-NetFirewallRule -DisplayName "*usbipd*" -ErrorAction SilentlyContinue

if ($existingRules) {
    Write-Host "   📝 Reglas existentes encontradas:" -ForegroundColor Cyan
    $existingRules | ForEach-Object {
        Write-Host "      - $($_.DisplayName) [Enabled: $($_.Enabled), Action: $($_.Action)]" -ForegroundColor Gray
    }
} else {
    Write-Host "   ℹ️  No se encontraron reglas existentes para usbipd" -ForegroundColor Gray
}

# ==============================================================================
# PASO 4: Crear regla de firewall para TCP 3240
# ==============================================================================
Write-Host ""
Write-Host "📋 PASO 4: Creando regla de firewall para TCP 3240..." -ForegroundColor Yellow

# Verificar si ya existe la regla específica
$targetRule = Get-NetFirewallRule -DisplayName "Allow usbipd TCP 3240 (WSL2)" -ErrorAction SilentlyContinue

if ($targetRule) {
    Write-Host "   ℹ️  La regla ya existe. Eliminando para recrear..." -ForegroundColor Yellow
    Remove-NetFirewallRule -DisplayName "Allow usbipd TCP 3240 (WSL2)" -ErrorAction SilentlyContinue
}

# Crear regla principal: Puerto TCP 3240 para perfiles Private y Domain
try {
    New-NetFirewallRule -DisplayName "Allow usbipd TCP 3240 (WSL2)" `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort 3240 `
        -Profile Private,Domain `
        -Description "Allow usbipd attach communication for WSL2 devices" `
        -ErrorAction Stop | Out-Null
    
    Write-Host "   ✅ Regla de firewall creada exitosamente" -ForegroundColor Green
    Write-Host "      - Puerto: TCP 3240" -ForegroundColor Gray
    Write-Host "      - Perfiles: Private, Domain" -ForegroundColor Gray
    Write-Host "      - Dirección: Inbound" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ Error al crear regla: $_" -ForegroundColor Red
    exit 1
}

# ==============================================================================
# PASO 5: (Opcional) Crear regla adicional por programa
# ==============================================================================
if ($usbipdExePath -and (Test-Path $usbipdExePath)) {
    Write-Host ""
    Write-Host "📋 PASO 5: Creando regla adicional por programa..." -ForegroundColor Yellow
    
    $programRule = Get-NetFirewallRule -DisplayName "Allow usbipd program (WSL2)" -ErrorAction SilentlyContinue
    if ($programRule) {
        Write-Host "   ℹ️  Regla por programa ya existe. Eliminando para recrear..." -ForegroundColor Yellow
        Remove-NetFirewallRule -DisplayName "Allow usbipd program (WSL2)" -ErrorAction SilentlyContinue
    }
    
    try {
        New-NetFirewallRule -DisplayName "Allow usbipd program (WSL2)" `
            -Direction Inbound `
            -Action Allow `
            -Program $usbipdExePath `
            -Profile Private,Domain `
            -Description "Allow usbipd executable to accept incoming connections for WSL2" `
            -ErrorAction Stop | Out-Null
        
        Write-Host "   ✅ Regla por programa creada exitosamente" -ForegroundColor Green
        Write-Host "      - Programa: $usbipdExePath" -ForegroundColor Gray
    } catch {
        Write-Host "   ⚠️  No se pudo crear regla por programa: $_" -ForegroundColor Yellow
    }
}

# ==============================================================================
# PASO 6: (Opcional avanzado) Crear regla limitada a subred WSL NAT
# ==============================================================================
Write-Host ""
Write-Host "📋 PASO 6: Creando regla limitada a subred WSL NAT (172.25.0.0/16)..." -ForegroundColor Yellow

$natRule = Get-NetFirewallRule -DisplayName "Allow usbipd TCP 3240 from WSL NAT" -ErrorAction SilentlyContinue
if ($natRule) {
    Write-Host "   ℹ️  Regla NAT ya existe. Eliminando para recrear..." -ForegroundColor Yellow
    Remove-NetFirewallRule -DisplayName "Allow usbipd TCP 3240 from WSL NAT" -ErrorAction SilentlyContinue
}

try {
    New-NetFirewallRule -DisplayName "Allow usbipd TCP 3240 from WSL NAT" `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort 3240 `
        -RemoteAddress 172.25.0.0/16 `
        -Profile Private,Domain `
        -Description "Allow usbipd TCP 3240 only from WSL NAT subnet (more secure)" `
        -ErrorAction Stop | Out-Null
    
    Write-Host "   ✅ Regla NAT creada exitosamente (más segura)" -ForegroundColor Green
    Write-Host "      - RemoteAddress: 172.25.0.0/16" -ForegroundColor Gray
} catch {
    Write-Host "   ⚠️  No se pudo crear regla NAT: $_" -ForegroundColor Yellow
}

# ==============================================================================
# PASO 7: Verificar reglas creadas
# ==============================================================================
Write-Host ""
Write-Host "📋 PASO 7: Verificando reglas creadas..." -ForegroundColor Yellow

$createdRules = Get-NetFirewallRule -DisplayName "Allow usbipd*" -ErrorAction SilentlyContinue
if ($createdRules) {
    Write-Host "   ✅ Reglas de firewall activas:" -ForegroundColor Green
    $createdRules | ForEach-Object {
        $ruleDetails = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $_.Name -ErrorAction SilentlyContinue
        $profile = $_.Profile -join ", "
        Write-Host "      - $($_.DisplayName)" -ForegroundColor Cyan
        Write-Host "        Enabled: $($_.Enabled) | Action: $($_.Action) | Profile: $profile" -ForegroundColor Gray
        if ($ruleDetails) {
            Write-Host "        Port: $($ruleDetails.LocalPort) | Protocol: $($ruleDetails.Protocol)" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "   ⚠️  No se encontraron reglas creadas" -ForegroundColor Yellow
}

# ==============================================================================
# PASO 8: Reiniciar servicio usbipd
# ==============================================================================
Write-Host ""
Write-Host "📋 PASO 8: Reiniciando servicio usbipd..." -ForegroundColor Yellow

try {
    Restart-Service usbipd -Force -ErrorAction Stop
    Start-Sleep -Seconds 2
    $serviceStatus = (Get-Service usbipd).Status
    Write-Host "   ✅ Servicio reiniciado. Estado: $serviceStatus" -ForegroundColor Green
} catch {
    Write-Host "   ⚠️  Error al reiniciar servicio: $_" -ForegroundColor Yellow
}

# ==============================================================================
# PASO 9: Mostrar próximos pasos
# ==============================================================================
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ CONFIGURACIÓN COMPLETADA" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "📝 PRÓXIMOS PASOS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1️⃣  Ejecuta tu script de conexión nuevamente:" -ForegroundColor White
Write-Host "    .\conectar_android.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "2️⃣  Si aún aparece el warning, verifica antivirus/firewall de terceros:" -ForegroundColor White
Write-Host "    - Windows Defender" -ForegroundColor Gray
Write-Host "    - Bitdefender, ESET, McAfee, Norton, etc." -ForegroundColor Gray
Write-Host ""
Write-Host "3️⃣  Dentro de WSL, verifica el dispositivo conectado:" -ForegroundColor White
Write-Host "    sudo apt update && sudo apt install -y usbutils android-tools-adb" -ForegroundColor Gray
Write-Host "    lsusb" -ForegroundColor Gray
Write-Host "    adb devices" -ForegroundColor Gray
Write-Host ""
Write-Host "4️⃣  Para debugging avanzado, usa:" -ForegroundColor White
Write-Host "    usbipd wsl attach --busid 1-2 --log-level debug" -ForegroundColor Gray
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 TIPS DE SEGURIDAD:" -ForegroundColor Yellow
Write-Host "   - Las reglas creadas solo aplican a perfiles Private y Domain" -ForegroundColor Gray
Write-Host "   - No se abrió el puerto para redes públicas (más seguro)" -ForegroundColor Gray
Write-Host "   - La regla NAT limita conexiones solo desde WSL (172.25.0.0/16)" -ForegroundColor Gray
Write-Host ""
Write-Host "🗑️  Para eliminar las reglas creadas, ejecuta:" -ForegroundColor Yellow
Write-Host "   Remove-NetFirewallRule -DisplayName 'Allow usbipd*'" -ForegroundColor Gray
Write-Host ""
Write-Host "✅ Script completado exitosamente" -ForegroundColor Green
Write-Host ""
