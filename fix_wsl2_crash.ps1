# Fix WSL2 Service Error E_UNEXPECTED
# Ejecutar como Administrador en PowerShell

Write-Host "🔧 Reparando servicio WSL2..." -ForegroundColor Yellow

# 1. Detener todos los procesos WSL
Write-Host "`n1️⃣ Deteniendo WSL..." -ForegroundColor Cyan
wsl --shutdown
Start-Sleep -Seconds 3

# 2. Reiniciar servicio LxssManager (WSL2 Service)
Write-Host "`n2️⃣ Reiniciando servicio LxssManager..." -ForegroundColor Cyan
Restart-Service LxssManager -Force
Start-Sleep -Seconds 2

# 3. Verificar estado del servicio
Write-Host "`n3️⃣ Verificando estado del servicio..." -ForegroundColor Cyan
Get-Service LxssManager | Format-List

# 4. Reiniciar distribución
Write-Host "`n4️⃣ Reiniciando Ubuntu-24.04..." -ForegroundColor Cyan
wsl -d Ubuntu-24.04 -- echo "WSL2 reiniciado correctamente"

Write-Host "`n✅ Reparación completada. Ahora intenta reconectar VS Code." -ForegroundColor Green
Write-Host "👉 Presiona 'Ctrl+Shift+P' -> 'WSL: Connect to WSL'" -ForegroundColor Yellow
