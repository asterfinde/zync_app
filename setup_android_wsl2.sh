#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then 
    echo "❌ Ejecutar con: sudo ./setup_android_wsl2.sh"
    exit 1
fi

echo "📦 Instalando dependencias..."
apt update -qq && apt install -y android-tools-adb usbutils > /dev/null 2>&1
echo "✅ Dependencias instaladas"
echo ""

echo "📝 Configurando reglas udev..."
cat > /etc/udev/rules.d/51-android.rules << 'EOF'
# Samsung devices
SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="plugdev"
# Google devices
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"
# General fallback
SUBSYSTEM=="usb", MODE="0666", GROUP="plugdev"
EOF
chmod 644 /etc/udev/rules.d/51-android.rules
echo "✅ Reglas udev creadas"
echo ""

echo "👥 Configurando grupo plugdev..."
groupadd -r plugdev 2>/dev/null || true
USER_NAME=$(logname 2>/dev/null || echo $SUDO_USER)
usermod -a -G plugdev $USER_NAME
echo "✅ Usuario $USER_NAME agregado a plugdev"
echo ""

echo "🔐 Configurando sudoers sin contraseña..."
cat > /etc/sudoers.d/android-wsl2 << EOF
$USER_NAME ALL=(ALL) NOPASSWD: /bin/chmod -R * /dev/bus/usb/*
$USER_NAME ALL=(ALL) NOPASSWD: /bin/chmod * /dev/bus/usb/*/*
$USER_NAME ALL=(ALL) NOPASSWD: /sbin/udevadm control --reload-rules
$USER_NAME ALL=(ALL) NOPASSWD: /sbin/udevadm trigger
EOF
chmod 440 /etc/sudoers.d/android-wsl2
echo "✅ Sudoers configurado"
echo ""

echo "🔄 Recargando reglas udev..."
udevadm control --reload-rules
udevadm trigger
echo "✅ Reglas recargadas"
echo ""

echo "═══════════════════════════════════════"
echo "✅ SETUP COMPLETADO"
echo "═══════════════════════════════════════"
echo ""
echo "⚠️  IMPORTANTE: Ejecuta uno de estos:"
echo "   1. Cerrar sesión y volver a entrar"
echo "   2. Ejecutar: newgrp plugdev"
echo ""
echo "📝 Próximos pasos:"
echo "   ./start_day.sh    (inicio del día)"
echo "   ./end_day.sh      (fin del día)"
echo ""