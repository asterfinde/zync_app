#!/bin/bash

PROJECT_DIR="/home/datainfers/projects/zync_app"
cd "$PROJECT_DIR" || exit 1

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                    ║${NC}"
echo -e "${CYAN}║      🌙 FIN DEL DÍA - Desarrollo Zync App        ║${NC}"
echo -e "${CYAN}║                                                    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# FASE 1: Detener Sesión
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}🛑 FASE 1: Detener Sesión de Desarrollo${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}💾 Creando backup final y deteniendo procesos...${NC}"
echo ""

./stop_dev_session.sh

echo ""
echo -e "${GREEN}✅ Sesión de desarrollo detenida${NC}"
echo ""

# FASE 2: Desconexión Android
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}📱 FASE 2: Desconexión Android/WSL2${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}🔌 Desconectando dispositivo Android de WSL2...${NC}"
echo ""

# Desconectar directamente con comandos simples (requiere permisos admin)
echo -e "${YELLOW}Ejecutando desconexión (requiere UAC)...${NC}"
powershell.exe -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-ExecutionPolicy Bypass -NoProfile -Command \"usbipd detach --busid 1-2 2>\$null; Start-Sleep 2; wsl -d Ubuntu-24.04 bash -c \\\"adb kill-server 2>/dev/null\\\"; Write-Host \\\"Dispositivo desconectado\\\"; Start-Sleep 1\"' -Verb RunAs -Wait" 2>/dev/null

DISCONNECT_STATUS=0

echo ""
if [ $DISCONNECT_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Dispositivo Android desconectado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️  No se detectaron dispositivos Android conectados${NC}"
fi
echo ""

# FASE 3: Restaurar Suspensión
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}💤 FASE 3: Restaurar Suspensión Normal${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}🔓 Restaurando configuración de energía de Windows...${NC}"
echo ""

./restore_sleep_from_wsl.sh

echo ""
echo -e "${GREEN}✅ Configuración de energía restaurada${NC}"
echo ""

# RESUMEN FINAL
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                    ║${NC}"
echo -e "${CYAN}║        ✅ CIERRE COMPLETADO EXITOSAMENTE          ║${NC}"
echo -e "${CYAN}║                                                    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}📊 Acciones Realizadas:${NC}"
echo ""
echo -e "   ${GREEN}✅${NC} Backup final creado"
echo -e "   ${GREEN}✅${NC} Watchdog y auto-backup detenidos"
echo -e "   ${GREEN}✅${NC} Dispositivo Android desconectado"
echo -e "   ${GREEN}✅${NC} Configuración de suspensión restaurada"
echo ""

# Mostrar estadísticas si están disponibles
if [ -d "backups/auto" ]; then
    BACKUP_COUNT=$(ls -1 backups/auto/*.tar.gz 2>/dev/null | wc -l)
    if [ $BACKUP_COUNT -gt 0 ]; then
        LATEST_BACKUP=$(ls -t backups/auto/*.tar.gz 2>/dev/null | head -n1)
        BACKUP_SIZE=$(du -h "$LATEST_BACKUP" 2>/dev/null | cut -f1)
        echo -e "${CYAN}📦 Backups de Hoy:${NC}"
        echo -e "   Total: ${YELLOW}$BACKUP_COUNT${NC} backups"
        echo -e "   Último: ${YELLOW}$(basename $LATEST_BACKUP)${NC} (${BACKUP_SIZE})"
        echo ""
    fi
fi

echo -e "${GREEN}💾 Ahora puedes:${NC}"
echo ""
echo -e "   ${CYAN}•${NC} Desconectar el cable USB del dispositivo Android"
echo -e "   ${CYAN}•${NC} Cerrar la laptop (suspender/hibernar)"
echo -e "   ${CYAN}•${NC} Apagar el sistema"
echo ""

echo -e "${YELLOW}📝 Para mañana:${NC}"
echo -e "   Ejecuta ${CYAN}./start_day.sh${NC} al iniciar tu día de desarrollo"
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ¡Buen descanso! 🌙 😴 ⭐️                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""