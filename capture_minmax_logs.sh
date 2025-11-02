#!/bin/bash
# Script para capturar logs de performance de minimización/maximización
# Uso: ./capture_minmax_logs.sh

echo "🎯 Test de Performance - Point 20"
echo "=================================="
echo ""
echo "📱 INSTRUCCIONES:"
echo "1. La app debe estar corriendo (flutter run en otra terminal)"
echo "2. Haz login en la app"
echo "3. Presiona ENTER cuando estés en HomePage"
read -p "Presiona ENTER para continuar..."

echo ""
echo "4. Ahora MINIMIZA la app (botón Home)"
echo "5. Espera 5 segundos"
echo "6. MAXIMIZA la app (toca el ícono de Zync)"
echo "7. Espera 2 segundos más"
read -p "Presiona ENTER cuando hayas completado el test..."

echo ""
echo "📊 Filtrando logs relevantes..."
echo "=================================="
echo ""

# Crear archivo de logs
LOG_FILE="logs/minmax_performance_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p logs

# Capturar logs de flutter
flutter logs | grep -E "MainActivity|App\]|START|END|📊|⏱️|✅|🔴|🟡|🟢|Firebase|DI Init|Cache Init|AuthWrapper|HomePage|InCircleView" > "$LOG_FILE" &
LOG_PID=$!

echo "Capturando logs por 10 segundos..."
sleep 10

# Detener captura
kill $LOG_PID 2>/dev/null

echo ""
echo "✅ Logs guardados en: $LOG_FILE"
echo ""
echo "📋 RESUMEN:"
cat "$LOG_FILE" | grep -E "App Maximization|onCreate|onResume|onDestroy"

echo ""
echo "📊 REPORTE COMPLETO:"
cat "$LOG_FILE"

echo ""
echo "================================================================"
echo "📌 SIGUIENTE PASO: Copia estos logs y pégalos en el plan de acción"
echo "================================================================"
