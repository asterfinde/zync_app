# connect_android.ps1 (ejecutar como Admin después de iniciar)
usbipd bind --busid 1-2
usbipd attach --wsl --busid 1-2
echo "✅ Dispositivo conectado a WSL2"