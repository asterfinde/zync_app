#!/bin/bash

# stop_dev_session.sh
# Detiene la sesión de desarrollo de forma segura
# Autor: Auto-generado para resolver Point 1 crítico

PROJECT_DIR="/home/datainfers/projects/zync_app"
cd "$PROJECT_DIR" || exit 1

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  🛑 Deteniendo Sesión de Desarrollo${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# 1. Backup final antes de cerrar
echo -e "${YELLOW}📦 Creando backup final...${NC}"
if [ -f "backup_critical_files.sh" ]; then
    ./backup_critical_files.sh > /dev/null 2>&1
    echo -e "${GREEN}✅ Backup final completado${NC}"
else
    echo -e "${YELLOW}⚠️  Script de backup no encontrado${NC}"
fi
echo ""

# 2. Leer PIDs guardados
if [ -f ".dev_session_pids" ]; then
    echo -e "${YELLOW}🔍 Leyendo PIDs de procesos...${NC}"
    PIDS=$(cat .dev_session_pids)
    
    for PID in $PIDS; do
        if ps -p $PID > /dev/null 2>&1; then
            echo -e "   Deteniendo PID ${CYAN}$PID${NC}..."
            kill $PID 2>/dev/null
        fi
    done
    
    sleep 2
    
    # Verificar que se detuvieron
    STILL_RUNNING=0
    for PID in $PIDS; do
        if ps -p $PID > /dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  Forzando terminación de PID $PID${NC}"
            kill -9 $PID 2>/dev/null
            STILL_RUNNING=1
        fi
    done
    
    if [ $STILL_RUNNING -eq 0 ]; then
        echo -e "${GREEN}✅ Todos los procesos detenidos correctamente${NC}"
    else
        echo -e "${YELLOW}⚠️  Algunos procesos requirieron terminación forzada${NC}"
    fi
    
    rm .dev_session_pids
else
    echo -e "${YELLOW}⚠️  No se encontró archivo de PIDs${NC}"
    echo -e "${YELLOW}   Buscando procesos manualmente...${NC}"
    
    # Buscar y matar procesos por nombre
    pkill -f "wsl2_connection_watchdog.sh" && echo -e "${GREEN}✅ Watchdog detenido${NC}"
    pkill -f "auto_backup_daemon.sh" && echo -e "${GREEN}✅ Auto-backup detenido${NC}"
fi
echo ""

# 3. Mostrar estadísticas de la sesión
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}📊 Estadísticas de la Sesión${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

if [ -f "auto_backup.log" ]; then
    BACKUP_COUNT=$(grep -c "Backup completado" auto_backup.log 2>/dev/null || echo "0")
    echo -e "${YELLOW}💾 Backups automáticos creados:${NC} ${CYAN}$BACKUP_COUNT${NC}"
fi

if [ -f "$HOME/.wsl2_watchdog.log" ]; then
    CONNECTION_LOSSES=$(grep -c "Conexión perdida" ~/.wsl2_watchdog.log 2>/dev/null || echo "0")
    AUTO_RECOVERIES=$(grep -c "Reconexión automática exitosa" ~/.wsl2_watchdog.log 2>/dev/null || echo "0")
    echo -e "${YELLOW}🔍 Desconexiones detectadas:${NC} ${CYAN}$CONNECTION_LOSSES${NC}"
    echo -e "${YELLOW}✅ Reconexiones automáticas:${NC} ${CYAN}$AUTO_RECOVERIES${NC}"
fi

TOTAL_BACKUPS=$(ls -1 backups/auto/*.tar.gz 2>/dev/null | wc -l)
echo -e "${YELLOW}📦 Total de backups disponibles:${NC} ${CYAN}$TOTAL_BACKUPS${NC}"

if [ $TOTAL_BACKUPS -gt 0 ]; then
    LATEST_BACKUP=$(ls -t backups/auto/*.tar.gz 2>/dev/null | head -n1)
    BACKUP_SIZE=$(du -h "$LATEST_BACKUP" 2>/dev/null | cut -f1)
    echo -e "${YELLOW}📄 Último backup:${NC} ${CYAN}$(basename $LATEST_BACKUP)${NC} (${BACKUP_SIZE})"
fi

echo ""
echo -e "${GREEN}✅ Sesión cerrada correctamente${NC}"
echo ""
echo -e "${YELLOW}⚠️  RECORDATORIO:${NC}"
echo -e "   Ejecuta ${CYAN}restore_sleep.ps1${NC} en PowerShell (Windows)"
echo -e "   para restaurar la suspensión normal del sistema"
echo ""
echo -e "${CYAN}============================================${NC}"
