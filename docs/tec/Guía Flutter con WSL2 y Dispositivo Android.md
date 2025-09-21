# **Resumen de Configuración: Entorno de Desarrollo Flutter con WSL2 y Dispositivo Android Físico**

## 1\. Contexto y Objetivo

El objetivo de esta sesión fue configurar un entorno de desarrollo profesional para aplicaciones Flutter, utilizando **WSL2 (Ubuntu 24.04)** en Windows 11 para conectar, desplegar y depurar en un **dispositivo Android físico**. La meta era lograr un flujo de trabajo eficiente que combinara el poder de las herramientas de Linux con la comodidad del escritorio de Windows.

## 2\. El Desafío y la Solución: La Conexión Windows-WSL2

La parte más significativa de este proceso fue superar la barrera de aislamiento entre Windows 11 y el subsistema de WSL2.

  * **El Problema:** WSL2 se ejecuta en un entorno virtualizado con su propio kernel de Linux, lo que significa que no tiene acceso directo a los puertos USB del sistema anfitrión (Windows). Un dispositivo conectado a la laptop no es visible automáticamente dentro de Ubuntu.

  * **La Solución Clave: `usbipd-win`**: La tecnología que hizo esto posible fue **`usbipd-win`**. Esta herramienta implementa el protocolo *USB over IP*, permitiendo a Windows "compartir" un dispositivo USB a través de una conexión de red virtual local directamente con el kernel de WSL2.

  * **El Significado:** Al usar `usbipd`, logramos que el dispositivo Android apareciera dentro del entorno de Ubuntu **como si estuviera conectado físicamente a él**. Esto nos permite:

    1.  **Aprovechar la velocidad y el rendimiento** de las herramientas de compilación de Flutter en Linux.
    2.  **Mantener un flujo de trabajo unificado**, utilizando VS Code en Windows para editar el código mientras los comandos de compilación y depuración se ejecutan de forma nativa en Linux.
    3.  **Depurar directamente en hardware real**, lo cual es crucial para probar el rendimiento, los sensores y las funcionalidades nativas de la aplicación.

## 3\. Proceso de Configuración y Diagnóstico (Checklist)

Seguimos un checklist interactivo paso a paso para diagnosticar y configurar la conexión:

1.  **Instalación de `usbipd-win` en Windows**: Se instaló la herramienta `usbipd-win` usando `winget` en PowerShell, estableciendo la base para la comunicación.
2.  **Vinculación del Dispositivo (`bind`)**: Se utilizó `usbipd bind --busid <BUSID>` para indicarle a Windows que preparara el dispositivo para ser compartido.
3.  **Conexión a WSL2 (`attach`)**: Con `usbipd attach --wsl --busid <BUSID>`, se completó el "puente", entregando el control del dispositivo a WSL2. Durante este paso, se autorizó la depuración por USB en el dispositivo Android.
4.  **Verificación en Múltiples Capas dentro de WSL2**:
      * **Kernel de Linux**: Se confirmó la detección a bajo nivel con `lsusb` (tras instalar `usbutils`).
      * **Herramientas de Android**: Se verificó el reconocimiento por parte de ADB con `adb devices`.
      * **Toolchain de Flutter**: Se validó la integración final con `fvm flutter devices`.

## 4\. Automatización y Eficiencia: Scripts de PowerShell

Para agilizar el proceso diario de conexión y desconexión, se crearon dos scripts de PowerShell y accesos directos en el Escritorio.

### Script 1: `conectar_android.ps1`

  * **Propósito**: Automatizar la conexión del dispositivo a WSL2 con un solo clic.
  * **Funcionamiento**:
    1.  Busca dinámicamente el dispositivo conectado que contenga la palabra clave "Galaxy".
    2.  Extrae su `BUSID` actual, eliminando la necesidad de buscarlo manualmente.
    3.  Ejecuta el comando `usbipd attach` usando el `BUSID` encontrado.
    4.  Realiza una verificación final ejecutando `adb devices` dentro de WSL.

<!-- end list -->

```powershell
# Script para conectar automáticamente un dispositivo Android a WSL2
$nombreDispositivo = "Galaxy"
# ... (lógica para buscar, extraer BUSID y adjuntar)
```

### Script 2: `desconectar_android.ps1`

  * **Propósito**: Desconectar de forma segura y limpia el dispositivo de WSL2 antes de desenchufar el cable USB.
  * **Funcionamiento**:
    1.  Busca el dispositivo "Galaxy" que se encuentre en estado `Attached`.
    2.  Extrae su `BUSID`.
    3.  Ejecuta el comando `usbipd detach` para liberar el dispositivo de WSL2 y devolver el control a Windows.

<!-- end list -->

```powershell
# Script para desconectar de forma segura un dispositivo Android de WSL2
$nombreDispositivo = "Galaxy"
# ... (lógica para buscar, extraer BUSID y des-adjuntar)
```

### Accesos Directos del Escritorio

Se crearon accesos directos en el Escritorio para ambos scripts, configurados para **ejecutarse como administrador** y mantener la ventana de PowerShell abierta (`-NoExit`) para poder ver los resultados. Esto reduce el proceso completo a un simple doble clic.

## 5\. Estado Final

El resultado es un **entorno de desarrollo Flutter de nivel profesional**: robusto, rápido y altamente automatizado, que permite un ciclo de desarrollo y depuración eficiente sobre un dispositivo físico real, todo ello integrando lo mejor de los ecosistemas de Windows y Linux.