# ✅ Checklist Diario - Desarrollo Zync App

## 🌅 Al Iniciar el Día

### Terminal 1 - Desarrollo Principal

```bash
cd /home/dante/projects/zync_app
```

- [ ] **Paso 1:** Limpiar emuladores offline
  ```bash
  ./clean_offline_devices.sh
  ```
  **Resultado esperado:** `List of devices attached` (vacío o sin offline)

- [ ] **Paso 2:** Conectar dispositivo Android
  ```bash
  ./fix_adb_connection.sh 192.168.1.50:5555
  ```
  **Resultado esperado:** `✓ Dispositivo conectado: 192.168.1.50:5555`

- [ ] **Paso 3:** Verificar conexión
  ```bash
  adb devices -l
  ```
  **Resultado esperado:** Tu dispositivo listado como `device`

- [ ] **Paso 4:** Verificar Flutter
  ```bash
  flutter devices
  ```
  **Resultado esperado:** Tu dispositivo visible en Flutter

### Terminal 2 - Watchdog (Opcional pero Recomendado)

```bash
cd /home/dante/projects/zync_app
```

- [ ] **Paso 5:** Iniciar watchdog
  ```bash
  ./adb_connection_watchdog.sh 192.168.1.50:5555
  ```
  **Qué hace:** Mantiene la conexión estable automáticamente
  **Dejar corriendo:** No cerrar esta terminal

### Terminal 1 - Ejecutar App

- [ ] **Paso 6:** Ejecutar Flutter
  ```bash
  flutter run -d 192.168.1.50:5555
  ```

---

## 🔄 Durante el Desarrollo

### Si la conexión se interrumpe:

**Opción A: Con Watchdog (Automático)**
- El watchdog detecta y reconecta automáticamente
- Verifica en Terminal 2 el estado

**Opción B: Sin Watchdog (Manual)**
```bash
./fix_adb_connection.sh 192.168.1.50:5555
```

### Si aparece "emulator-5554 offline":
```bash
./clean_offline_devices.sh
```

### Si ADB no responde:
```bash
adb kill-server
sleep 2
adb start-server
./clean_offline_devices.sh
```

---

## 🌙 Al Finalizar el Día

- [ ] **Paso 1:** Detener Flutter (Ctrl+C en Terminal 1)

- [ ] **Paso 2:** Detener Watchdog (Ctrl+C en Terminal 2)
  - Verás estadísticas de la sesión

- [ ] **Paso 3:** (Opcional) Desconectar dispositivo
  ```bash
  adb disconnect 192.168.1.50:5555
  ```

- [ ] **Paso 4:** (Opcional) Backup
  ```bash
  ./backup_critical_files.sh
  ```

---

## 🚨 Solución Rápida de Problemas

| Problema | Solución Rápida | Comando |
|----------|----------------|---------|
| Emulador offline | Limpiar dispositivos | `./clean_offline_devices.sh` |
| Dispositivo no conecta | Reconectar | `./fix_adb_connection.sh <IP:PORT>` |
| Conexión inestable | Usar watchdog | `./adb_connection_watchdog.sh <IP:PORT>` |
| ADB no responde | Reiniciar servidor | `adb kill-server && adb start-server` |
| Flutter no ve dispositivo | Verificar ADB primero | `adb devices -l` |

---

## 📊 Verificación de Estado

### Estado Saludable ✅
```bash
$ adb devices -l
List of devices attached
192.168.1.50:5555      device product:a14x model:SM_A145M device:a14x
```

### Estado con Problemas ❌
```bash
$ adb devices -l
List of devices attached
emulator-5554          offline
192.168.1.50:5555      offline
```
**Solución:** `./clean_offline_devices.sh`

---

## 🎯 Comandos de Verificación Rápida

```bash
# Ver dispositivos ADB
adb devices -l

# Ver dispositivos Flutter
flutter devices

# Estado de Flutter
flutter doctor

# Ver logs del watchdog
tail -f logs/adb_watchdog_*.log

# Verificar alias ADB
which adb
# Debe mostrar: /mnt/c/platform-tools/adb.exe
```

---

## 💡 Tips

- ✅ **SIEMPRE** ejecuta `clean_offline_devices.sh` antes de conectar
- ✅ **USA** el watchdog para evitar interrupciones
- ✅ **VERIFICA** el estado con `adb devices` regularmente
- ✅ **MANTÉN** la Terminal 2 (watchdog) abierta durante desarrollo

- ❌ **NO** cierres el watchdog durante desarrollo activo
- ❌ **NO** ignores emuladores offline
- ❌ **NO** uses múltiples servidores ADB

---

## 📁 Archivos de Referencia

- **Guía rápida:** `INICIO_RAPIDO_ADB.md`
- **Guía completa:** `GUIA_CONEXION_ADB_ESTABLE.md`
- **Logs:** `logs/adb_watchdog_*.log`

---

## 🔄 Resumen del Flujo Ideal

```
1. Terminal 1: ./clean_offline_devices.sh
2. Terminal 1: ./fix_adb_connection.sh <IP:PORT>
3. Terminal 2: ./adb_connection_watchdog.sh <IP:PORT>
4. Terminal 1: flutter run -d <IP:PORT>
5. Desarrollar sin preocuparte por la conexión
6. Al finalizar: Ctrl+C en ambas terminales
```

---

**Última actualización:** 2025-11-20  
**Estado:** ✅ Listo para usar
