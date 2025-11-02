# prevent_sleep.ps1
# Evita que Windows entre en suspensión durante desarrollo
# Autor: Auto-generado para resolver desconexiones WSL2

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Prevención de Suspensión WSL2" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Guardar configuración actual
$currentStandby = powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | Select-String "Current AC Power Setting Index" | ForEach-Object { $_ -replace '.*: 0x', '' }
$currentMonitor = powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE | Select-String "Current AC Power Setting Index" | ForEach-Object { $_ -replace '.*: 0x', '' }

Write-Host "📊 Configuración actual:" -ForegroundColor Yellow
Write-Host "   Suspensión: $([convert]::ToInt32($currentStandby, 16) / 60) minutos"
Write-Host "   Monitor: $([convert]::ToInt32($currentMonitor, 16) / 60) minutos"
Write-Host ""

# Aplicar nueva configuración (4 horas de trabajo)
Write-Host "🔒 Aplicando configuración de desarrollo..." -ForegroundColor Green

# Suspensión: 4 horas (240 minutos)
powercfg -change -standby-timeout-ac 240

# Monitor: 30 minutos (suficiente para pausas)
powercfg -change -monitor-timeout-ac 30

# Disco duro: nunca apagar
powercfg -change -disk-timeout-ac 0

# Hibernar: nunca
powercfg -change -hibernate-timeout-ac 0

Write-Host "✅ Configuración aplicada correctamente" -ForegroundColor Green
Write-Host ""
Write-Host "📅 Suspensión deshabilitada hasta las $((Get-Date).AddHours(4).ToString('HH:mm'))" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  IMPORTANTE:" -ForegroundColor Yellow
Write-Host "   - El monitor se apagará después de 30 minutos de inactividad"
Write-Host "   - El sistema NO entrará en suspensión durante 4 horas"
Write-Host "   - Al terminar, ejecuta 'restore_sleep.ps1' para restaurar" -ForegroundColor Yellow
Write-Host ""
Write-Host "💡 Tip: Minimiza el consumo de recursos:" -ForegroundColor Cyan
Write-Host "   - Cierra Chrome/Edge con muchas pestañas"
Write-Host "   - Evita tener múltiples IDEs abiertos"
Write-Host "   - Monitorea uso de memoria con Task Manager"
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
