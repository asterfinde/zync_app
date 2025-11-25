# Script para prevenir y resolver problemas de ADB en Windows
# Ejecutar como: .\scripts\fix_adb_windows.ps1

Write-Host "🔧 Limpiando procesos ADB conflictivos..." -ForegroundColor Cyan

# 1. Matar todos los procesos ADB
Get-Process -Name "adb" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1

# 2. Verificar si hay múltiples instancias de ADB en el sistema
$adbPaths = @(
    "C:\Android\platform-tools\adb.exe",
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe"
)

Write-Host "📍 Buscando instalaciones de ADB..." -ForegroundColor Yellow
$foundPaths = @()
foreach ($path in $adbPaths) {
    if (Test-Path $path) {
        $foundPaths += $path
        Write-Host "  ✓ Encontrado: $path" -ForegroundColor Green
    }
}

if ($foundPaths.Count -gt 1) {
    Write-Host "⚠️  ADVERTENCIA: Múltiples instalaciones de ADB detectadas!" -ForegroundColor Red
    Write-Host "   Esto puede causar conflictos. Recomendación: usar solo una." -ForegroundColor Yellow
}

# 3. Limpiar servidor ADB
Write-Host "`n🔄 Reiniciando servidor ADB..." -ForegroundColor Cyan
& "C:\Android\platform-tools\adb.exe" kill-server
Start-Sleep -Seconds 2
& "C:\Android\platform-tools\adb.exe" start-server
Start-Sleep -Seconds 2

# 4. Verificar dispositivos
Write-Host "`n📱 Dispositivos conectados:" -ForegroundColor Cyan
& "C:\Android\platform-tools\adb.exe" devices

# 5. Verificar firewall (puede bloquear ADB)
Write-Host "`n🔥 Verificando reglas de firewall..." -ForegroundColor Cyan
$firewallRule = Get-NetFirewallApplicationFilter | Where-Object { $_.Program -like "*adb.exe" }
if (-not $firewallRule) {
    Write-Host "⚠️  No hay regla de firewall para ADB" -ForegroundColor Yellow
    Write-Host "   Ejecuta como Admin para crear regla automática" -ForegroundColor Gray
}

Write-Host "`n✅ Proceso completado" -ForegroundColor Green
Write-Host "💡 Si persisten problemas, ejecuta este script como Administrador" -ForegroundColor Cyan
