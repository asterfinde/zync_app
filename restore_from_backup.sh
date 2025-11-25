#!/bin/bash

# Script para restaurar archivos desde backup
# Uso: ./restore_from_backup.sh [archivo_backup] [archivo_destino]

BACKUP_DIR="./backups"

if [ "$#" -ne 2 ]; then
    echo "❌ Uso: ./restore_from_backup.sh [archivo_backup] [archivo_destino]"
    echo ""
    echo "Backups disponibles:"
    ls -la $BACKUP_DIR/ | grep -E "\.(dart|sh|yaml)$" | awk '{print $9}' | sort -r
    exit 1
fi

BACKUP_FILE="$BACKUP_DIR/$1"
DEST_FILE="$2"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup no encontrado: $BACKUP_FILE"
    echo ""
    echo "Backups disponibles:"
    ls -la $BACKUP_DIR/ | grep -E "\.(dart|sh|yaml)$" | awk '{print $9}' | sort -r
    exit 1
fi

# Crear backup del archivo actual antes de restaurar
if [ -f "$DEST_FILE" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    filename=$(basename "$DEST_FILE")
    current_backup="${filename%.*}_current_${TIMESTAMP}.${filename##*.}"
    cp "$DEST_FILE" "$BACKUP_DIR/$current_backup"
    echo "🔒 Backup del archivo actual: $BACKUP_DIR/$current_backup"
fi

# Restaurar
cp "$BACKUP_FILE" "$DEST_FILE"
echo "✅ Restaurado: $BACKUP_FILE → $DEST_FILE"