# clean_dart_processes.ps1
# Script para limpiar procesos de Dart/Flutter huérfanos y cache corrupto
# Usar cuando VSCode/Flutter se comporta lento o hay errores de conexión

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Limpieza de Procesos Dart/Flutter" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Listar procesos actuales
Write-Host "[1/4] Procesos Dart/Flutter actuales:" -ForegroundColor Yellow
$dartProcesses = Get-Process | Where-Object {$_.ProcessName -match "dart|flutter"}
if ($dartProcesses) {
    $dartProcesses | Select-Object ProcessName, Id, CPU | Format-Table -AutoSize
    Write-Host "  Total: $($dartProcesses.Count) procesos" -ForegroundColor Gray
} else {
    Write-Host "  No hay procesos Dart/Flutter corriendo" -ForegroundColor Green
}
Write-Host ""

# 2. Detener procesos
if ($dartProcesses) {
    Write-Host "[2/4] Deteniendo procesos..." -ForegroundColor Yellow
    Stop-Process -Name dart,dartaotruntime,dartvm,flutter -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Write-Host "  ✓ Procesos detenidos" -ForegroundColor Green
} else {
    Write-Host "[2/4] No hay procesos que detener" -ForegroundColor Gray
}
Write-Host ""

# 3. Limpiar cache de Flutter
Write-Host "[3/4] Limpiando cache de Flutter..." -ForegroundColor Yellow
try {
    flutter clean | Out-Null
    Write-Host "  ✓ Cache limpiado (.dart_tool, build)" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Error al ejecutar flutter clean: $_" -ForegroundColor Red
}
Write-Host ""

# 4. Restaurar dependencias
Write-Host "[4/4] Restaurando dependencias..." -ForegroundColor Yellow
try {
    flutter pub get | Out-Null
    Write-Host "  ✓ Dependencias restauradas" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Error al ejecutar flutter pub get: $_" -ForegroundColor Red
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Limpieza completada" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Acciones recomendadas:" -ForegroundColor Yellow
Write-Host "  1. Recarga VSCode: Ctrl+Shift+P → 'Reload Window'" -ForegroundColor Gray
Write-Host "  2. Si persisten errores, reinicia VSCode completamente" -ForegroundColor Gray
Write-Host ""
