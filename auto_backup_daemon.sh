#!/bin/bash

# Auto-Backup Daemon para desarrollo Flutter
# Hace backup automático cada 5 minutos de archivos críticos
# Autor: Auto-generado para resolver Point 1 crítico

PROJECT_DIR="/home/datainfers/projects/zync_app"
BACKUP_DIR="$PROJECT_DIR/backups/auto"
LOG_FILE="$PROJECT_DIR/auto_backup.log"
BACKUP_INTERVAL=300  # 5 minutos en segundos
MAX_BACKUPS=20       # Mantener solo los últimos 20 backups

# Archivos críticos (extensible)
CRITICAL_FILES=(
    "lib/core/services/silent_functionality_coordinator.dart"
    "lib/core/services/status_service.dart"
    "lib/core/services/session_cache_service.dart"
    "lib/features/auth/presentation/provider/auth_provider.dart"
    "lib/features/auth/presentation/pages/auth_wrapper.dart"
    "lib/widgets/status_selector_overlay.dart"
    "lib/notifications/notification_service.dart"
    "lib/quick_actions/quick_actions_service.dart"
    "lib/features/circle/presentation/pages/home_page.dart"
    "lib/features/circle/presentation/widgets/in_circle_view.dart"
    "lib/main.dart"
    "android/app/src/main/AndroidManifest.xml"
    "pubspec.yaml"
)

# Crear directorio de backups si no existe
mkdir -p "$BACKUP_DIR"

echo "🤖 Auto-Backup Daemon iniciado - $(date)" | tee -a "$LOG_FILE"
echo "📂 Directorio: $BACKUP_DIR" | tee -a "$LOG_FILE"
echo "⏱️  Intervalo: ${BACKUP_INTERVAL}s (5 min)" | tee -a "$LOG_FILE"
echo "📦 Máximo backups: $MAX_BACKUPS" | tee -a "$LOG_FILE"
echo "---" | tee -a "$LOG_FILE"

cleanup_old_backups() {
    # Eliminar backups antiguos si superan el límite
    local total_backups=$(find "$BACKUP_DIR" -type f -name "*.tar.gz" | wc -l)
    
    if [ $total_backups -gt $MAX_BACKUPS ]; then
        local to_delete=$((total_backups - MAX_BACKUPS))
        echo "🧹 Limpiando $to_delete backups antiguos..." | tee -a "$LOG_FILE"
        
        find "$BACKUP_DIR" -type f -name "*.tar.gz" -printf '%T+ %p\n' | \
        sort | head -n $to_delete | cut -d' ' -f2- | \
        xargs rm -f
    fi
}

create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="auto_backup_${timestamp}.tar.gz"
    local temp_dir="/tmp/zync_backup_$$"
    
    echo "📦 [$(date +%H:%M:%S)] Creando backup: $backup_name" >> "$LOG_FILE"
    
    # Crear directorio temporal
    mkdir -p "$temp_dir"
    
    # Copiar archivos críticos que existen
    local files_backed=0
    for file in "${CRITICAL_FILES[@]}"; do
        local full_path="$PROJECT_DIR/$file"
        if [ -f "$full_path" ]; then
            local dir_path=$(dirname "$file")
            mkdir -p "$temp_dir/$dir_path"
            cp "$full_path" "$temp_dir/$file"
            files_backed=$((files_backed + 1))
        fi
    done
    
    # Crear tarball comprimido
    if [ $files_backed -gt 0 ]; then
        tar -czf "$BACKUP_DIR/$backup_name" -C "$temp_dir" . 2>/dev/null
        
        if [ $? -eq 0 ]; then
            local size=$(du -h "$BACKUP_DIR/$backup_name" | cut -f1)
            echo "✅ [$(date +%H:%M:%S)] Backup completado: $files_backed archivos, $size" >> "$LOG_FILE"
        else
            echo "❌ [$(date +%H:%M:%S)] Error al crear tarball" >> "$LOG_FILE"
        fi
    else
        echo "⚠️  [$(date +%H:%M:%S)] No se encontraron archivos para backup" >> "$LOG_FILE"
    fi
    
    # Limpiar directorio temporal
    rm -rf "$temp_dir"
    
    # Limpiar backups antiguos
    cleanup_old_backups
}

# Trap para limpieza al salir
trap "echo '🛑 Auto-Backup Daemon detenido - $(date)' | tee -a '$LOG_FILE'; exit 0" SIGINT SIGTERM

# Loop principal
backup_count=0
while true; do
    create_backup
    backup_count=$((backup_count + 1))
    
    # Log de progreso cada 6 backups (30 min)
    if [ $((backup_count % 6)) -eq 0 ]; then
        echo "📊 [$(date +%H:%M:%S)] Total backups creados: $backup_count" | tee -a "$LOG_FILE"
    fi
    
    sleep $BACKUP_INTERVAL
done
