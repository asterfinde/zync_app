#!/bin/bash
# Script para eliminar emuladores fantasma y conectar solo dispositivo físico
# Ejecutar antes de cada sesión de desarrollo

DEVICE_IP="192.168.1.50:5555"

echo "🧹 Limpiando conexiones ADB..."

# Limpiar procesos colgados
pkill -f "adb -s emulator" 2>/dev/null

# Reiniciar servidor ADB completamente
adb kill-server 2>/dev/null
sleep 1

# Conectar solo dispositivo físico
echo "📱 Conectando dispositivo físico..."
adb connect $DEVICE_IP
sleep 1

# Mostrar dispositivos
echo ""
echo "✅ Dispositivos:"
adb devices

echo ""
echo "✨ Si aparece 'emulator-5554', ignóralo. Solo usa el dispositivo físico."
echo "🚀 Ejecuta: flutter run --device-id=192.168.1.50:5555"
