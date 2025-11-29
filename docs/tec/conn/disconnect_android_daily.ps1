# Script de limpieza y desconexión para Flutter en Windows
$ErrorActionPreference = "SilentlyContinue" # No detenerse si no encuentra procesos para matar

Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  🌙 Fin del Día - Desconexión Android" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 1. Detener la comunicación con el dispositivo
Write-Host "🛑 Deteniendo servidor ADB..." -ForegroundColor Yellow
adb kill-server
if (-not (Get-Process adb -ErrorAction SilentlyContinue)) {
    Write-Host "✅ Servidor ADB detenido correctamente." -ForegroundColor Green
} else {
    Write-Host "⚠️  No se pudo detener ADB suavemente, forzando cierre..." -ForegroundColor Red
    Stop-Process -Name "adb" -Force
}
Write-Host ""

# 2. Limpieza de memoria (Flutter/Gradle suelen dejar procesos abiertos)
Write-Host "🧹 Limpiando procesos de desarrollo en memoria..." -ForegroundColor Yellow

# Matar procesos de Dart (Flutter)
$dartProcs = Get-Process dart -ErrorAction SilentlyContinue
if ($dartProcs) {
    $count = $dartProcs.Count
    Stop-Process -Name "dart" -Force
    Write-Host "   🗑️  Se cerraron $count procesos de Dart (Flutter)." -ForegroundColor Gray
} else {
    Write-Host "   ✓ No había procesos de Dart activos." -ForegroundColor Gray
}

# Matar procesos de Java (Gradle Daemon)
# OJO: Esto cerrará cualquier otra app Java, pero es estándar cerrar el daemon de Gradle al final del día.
$javaProcs = Get-Process java -ErrorAction SilentlyContinue
if ($javaProcs) {
    # Filtramos para intentar no matar cosas que no sean de desarrollo si es posible, 
    # pero usualmente en dev machine Java = Gradle/Android Studio.
    $count = $javaProcs.Count
    Write-Host "   ❓ Se detectaron $count procesos Java (posiblemente Gradle Daemons)." -ForegroundColor Yellow
    Write-Host "      ¿Deseas cerrarlos para liberar RAM? (S/N) " -NoNewline -ForegroundColor White
    $response = Read-Host
    if ($response -match "^[sS]") {
        Stop-Process -Name "java" -Force
        Write-Host "   🗑️  Procesos Java cerrados." -ForegroundColor Green
    } else {
        Write-Host "   ⏩ Omitiendo limpieza de Java." -ForegroundColor Gray
    }
} else {
    Write-Host "   ✓ No había procesos de Java/Gradle activos." -ForegroundColor Gray
}

Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ SISTEMA DESCONECTADO Y LIMPIO" -ForegroundColor Green
Write-Host "   Puedes desconectar el cable USB de forma segura." -ForegroundColor White
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Start-Sleep -Seconds 2