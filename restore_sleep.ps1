# restore_sleep.ps1
# Restaura la configuración normal de suspensión de Windows
# Autor: Auto-generado para resolver desconexiones WSL2

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Restaurar Suspensión Normal" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔄 Restaurando configuración normal de energía..." -ForegroundColor Yellow
Write-Host ""

# Suspensión: 30 minutos
powercfg -change -standby-timeout-ac 30

# Monitor: 10 minutos
powercfg -change -monitor-timeout-ac 10

# Disco duro: 20 minutos
powercfg -change -disk-timeout-ac 20

# Hibernar: 2 horas
powercfg -change -hibernate-timeout-ac 120

Write-Host "✅ Configuración restaurada correctamente" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Nueva configuración:" -ForegroundColor Cyan
Write-Host "   Suspensión: 30 minutos"
Write-Host "   Monitor: 10 minutos"
Write-Host "   Disco: 20 minutos"
Write-Host "   Hibernación: 2 horas"
Write-Host ""
Write-Host "💾 Ahorro de energía activado" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
