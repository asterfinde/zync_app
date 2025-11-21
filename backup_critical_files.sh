#!/bin/bash

# Script para hacer backup de archivos críticos antes de modificarlos
# Uso: ./backup_critical_files.sh [archivo_especifico]

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Archivos críticos que modificamos frecuentemente
CRITICAL_FILES=(
    "lib/core/services/silent_functionality_coordinator.dart"
    "lib/features/auth/presentation/provider/auth_provider.dart"
    "lib/widgets/status_selector_overlay.dart"
    "lib/notifications/notification_service.dart"
    "lib/quick_actions/quick_actions_service.dart"
    "lib/features/circle/presentation/widgets/no_circle_view.dart"
    "lib/core/services/status_service.dart"
)

echo "🔒 Iniciando backup de archivos críticos..."

# Si se especifica un archivo, solo hacer backup de ese
if [ "$1" != "" ]; then
    if [ -f "$1" ]; then
        filename=$(basename "$1")
        backup_name="${filename%.*}_backup_${TIMESTAMP}.${filename##*.}"
        cp "$1" "$BACKUP_DIR/$backup_name"
        echo "✅ Backup creado: $BACKUP_DIR/$backup_name"
    else
        echo "❌ Archivo no encontrado: $1"
        exit 1
    fi
    exit 0
fi

# Hacer backup de todos los archivos críticos
for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        backup_name="${filename%.*}_backup_${TIMESTAMP}.${filename##*.}"
        cp "$file" "$BACKUP_DIR/$backup_name"
        echo "✅ $file → $BACKUP_DIR/$backup_name"
    else
        echo "⚠️  Archivo no encontrado: $file"
    fi
done

echo ""
echo "🎉 Backup completado en: $BACKUP_DIR"
echo "📅 Timestamp: $TIMESTAMP"
echo ""
echo "Para restaurar un archivo:"
echo "cp $BACKUP_DIR/[archivo_backup] [archivo_original]"