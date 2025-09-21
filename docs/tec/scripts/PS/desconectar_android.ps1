# disconnect_android.ps1 (ejecutar como Admin antes de hibernar/apagar)
usbipd detach --busid 1-2
usbipd unbind --busid 1-2
echo "✅ Dispositivo desconectado y liberado"