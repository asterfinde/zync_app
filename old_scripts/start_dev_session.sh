#!/bin/bash

# start_dev_session.sh
# Inicia una sesión de desarrollo con todas las protecciones contra desconexiones
# Autor: Auto-generado para resolver Point 1 crítico

PROJECT_DIR="/home/datainfers/projects/zync_app"
cd "$PROJECT_DIR" || exit 1

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  🚀 Iniciando Sesión de Desarrollo WSL2${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# Verificar que los scripts existen
if [ ! -f "wsl2_connection_watchdog.sh" ]; then
    echo -e "${RED}❌ Error: wsl2_connection_watchdog.sh no encontrado${NC}"
    exit 1
fi

if [ ! -f "auto_backup_daemon.sh" ]; then
    echo -e "${RED}❌ Error: auto_backup_daemon.sh no encontrado${NC}"
    exit 1
fi

# Hacer scripts ejecutables
chmod +x wsl2_connection_watchdog.sh
chmod +x auto_backup_daemon.sh
chmod +x backup_critical_files.sh
chmod +x restore_from_backup.sh

echo -e "${GREEN}✅ Scripts preparados${NC}"
echo ""

# 1. Backup inicial
echo -e "${YELLOW}📦 Creando backup inicial...${NC}"
./backup_critical_files.sh > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Backup inicial completado${NC}"
else
    echo -e "${YELLOW}⚠️  Backup inicial falló (no crítico)${NC}"
fi
echo ""

# 2. Verificar recursos del sistema
echo -e "${YELLOW}📊 Verificando recursos del sistema...${NC}"
TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2}')
FREE_MEM=$(free -h | awk '/^Mem:/ {print $4}')
echo -e "   Memoria total: ${CYAN}$TOTAL_MEM${NC}"
echo -e "   Memoria libre: ${CYAN}$FREE_MEM${NC}"

# Verificar si hay suficiente memoria
FREE_MEM_MB=$(free -m | awk '/^Mem:/ {print $4}')
if [ $FREE_MEM_MB -lt 1000 ]; then
    echo -e "${YELLOW}⚠️  ADVERTENCIA: Poca memoria libre (<1GB)${NC}"
    echo -e "${YELLOW}   Considera cerrar aplicaciones pesadas en Windows${NC}"
else
    echo -e "${GREEN}✅ Memoria suficiente disponible${NC}"
fi
echo ""

# 3. Limpiar procesos zombies de sesiones anteriores
echo -e "${YELLOW}🧹 Limpiando sesiones anteriores...${NC}"
pkill -f "wsl2_connection_watchdog.sh" 2>/dev/null
pkill -f "auto_backup_daemon.sh" 2>/dev/null
sleep 2
echo -e "${GREEN}✅ Limpieza completada${NC}"
echo ""

# 4. Crear directorio de logs si no existe
mkdir -p logs
mkdir -p backups/auto

# 5. Iniciar watchdog de conexión
echo -e "${YELLOW}🔍 Iniciando watchdog de conexión...${NC}"
nohup ./wsl2_connection_watchdog.sh > logs/watchdog.log 2>&1 &
WATCHDOG_PID=$!
sleep 1

if ps -p $WATCHDOG_PID > /dev/null; then
    echo -e "${GREEN}✅ Watchdog iniciado (PID: $WATCHDOG_PID)${NC}"
else
    echo -e "${RED}❌ Error al iniciar watchdog${NC}"
fi
echo ""

# 6. Iniciar auto-backup daemon
echo -e "${YELLOW}💾 Iniciando auto-backup daemon...${NC}"
nohup ./auto_backup_daemon.sh > logs/auto_backup.log 2>&1 &
BACKUP_PID=$!
sleep 1

if ps -p $BACKUP_PID > /dev/null; then
    echo -e "${GREEN}✅ Auto-backup iniciado (PID: $BACKUP_PID)${NC}"
else
    echo -e "${RED}❌ Error al iniciar auto-backup${NC}"
fi
echo ""

# 7. Guardar PIDs para facilitar detención posterior
echo $WATCHDOG_PID > .dev_session_pids
echo $BACKUP_PID >> .dev_session_pids

# 8. Mostrar resumen
echo -e "${CYAN}============================================${NC}"
echo -e "${GREEN}✅ Sesión de desarrollo iniciada${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${YELLOW}📋 Procesos activos:${NC}"
echo -e "   🔍 Watchdog: PID ${CYAN}$WATCHDOG_PID${NC}"
echo -e "   💾 Auto-backup: PID ${CYAN}$BACKUP_PID${NC}"
echo ""
echo -e "${YELLOW}📂 Archivos de log:${NC}"
echo -e "   • Watchdog: ${CYAN}~/.wsl2_watchdog.log${NC}"
echo -e "   • Auto-backup: ${CYAN}auto_backup.log${NC}"
echo ""
echo -e "${YELLOW}🛑 Para detener la sesión:${NC}"
echo -e "   ${CYAN}./stop_dev_session.sh${NC}"
echo ""
echo -e "${YELLOW}👀 Monitorear en tiempo real:${NC}"
echo -e "   Watchdog: ${CYAN}tail -f ~/.wsl2_watchdog.log${NC}"
echo -e "   Backups: ${CYAN}tail -f auto_backup.log${NC}"
echo ""
echo -e "${YELLOW}⚠️  RECORDATORIOS:${NC}"
echo -e "   1. Ejecuta ${CYAN}prevent_sleep.ps1${NC} en PowerShell (Windows)"
echo -e "   2. Verifica que ${CYAN}.wslconfig${NC} esté configurado en Windows"
echo -e "   3. Mantén VSCode auto-save activado"
echo ""
echo -e "${GREEN}🎯 ¡Listo para desarrollar sin interrupciones!${NC}"
echo -e "${CYAN}============================================${NC}"
