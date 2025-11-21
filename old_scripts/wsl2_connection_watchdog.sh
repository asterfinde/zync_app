#!/bin/bash

# WSL2 Connection Watchdog
# Monitorea la conexión entre WSL2 y VSCode Server
# Autor: Auto-generado para resolver Point 1 crítico

LOG_FILE="$HOME/.wsl2_watchdog.log"
CHECK_INTERVAL=30  # Segundos entre verificaciones
MAX_RETRIES=3

echo "🔍 Watchdog WSL2-VSCode iniciado - $(date)" | tee -a "$LOG_FILE"
echo "📊 Verificando cada ${CHECK_INTERVAL}s" | tee -a "$LOG_FILE"
echo "---" | tee -a "$LOG_FILE"

check_connection() {
    # Verificar si VSCode Server está corriendo
    if pgrep -f ".vscode-server" > /dev/null; then
        return 0  # Conexión OK
    else
        return 1  # Conexión perdida
    fi
}

attempt_reconnect() {
    echo "⚠️  [$(date)] Conexión perdida. Intentando reconectar..." | tee -a "$LOG_FILE"
    
    # Intento 1: Verificar si es problema temporal
    sleep 5
    if check_connection; then
        echo "✅ [$(date)] Reconexión automática exitosa (temporal glitch)" | tee -a "$LOG_FILE"
        return 0
    fi
    
    # Intento 2: Reiniciar extensiones de VSCode
    echo "🔄 [$(date)] Reiniciando extensiones VSCode..." | tee -a "$LOG_FILE"
    pkill -f ".vscode-server/extensions"
    sleep 10
    
    if check_connection; then
        echo "✅ [$(date)] Reconexión exitosa (extensiones reiniciadas)" | tee -a "$LOG_FILE"
        return 0
    fi
    
    # Intento 3: Limpiar socket de VSCode Server
    echo "🧹 [$(date)] Limpiando sockets de VSCode Server..." | tee -a "$LOG_FILE"
    rm -rf /tmp/vscode-* 2>/dev/null
    rm -rf $HOME/.vscode-server/data/Machine/*.sock 2>/dev/null
    
    echo "❌ [$(date)] Reconexión automática falló. Requiere intervención manual." | tee -a "$LOG_FILE"
    echo "📌 [$(date)] ACCIÓN REQUERIDA: Recargar VSCode manualmente (Ctrl+Shift+P > 'Reload Window')" | tee -a "$LOG_FILE"
    
    # Notificar al usuario (si notify-send está disponible)
    if command -v notify-send &> /dev/null; then
        notify-send "⚠️ WSL2 Desconectado" "Recargar VSCode manualmente (Ctrl+Shift+P > Reload Window)"
    fi
    
    return 1
}

# Loop principal de monitoreo
retry_count=0
while true; do
    if ! check_connection; then
        retry_count=$((retry_count + 1))
        
        if [ $retry_count -le $MAX_RETRIES ]; then
            attempt_reconnect
        else
            echo "🚨 [$(date)] Límite de reintentos alcanzado ($MAX_RETRIES)" | tee -a "$LOG_FILE"
            echo "💡 [$(date)] Sugerencia: Verificar si Windows entró en suspensión" | tee -a "$LOG_FILE"
            # Resetear contador después de 5 minutos
            sleep 300
            retry_count=0
        fi
    else
        # Conexión OK, resetear contador
        if [ $retry_count -gt 0 ]; then
            echo "✅ [$(date)] Conexión estable restaurada" | tee -a "$LOG_FILE"
            retry_count=0
        fi
    fi
    
    sleep $CHECK_INTERVAL
done
