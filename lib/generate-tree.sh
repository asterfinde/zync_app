#!/bin/bash

# Obtener la fecha actual en formato YYYY-MM-DD
fecha=$(date +"%Y-%m-%d")

# Nombre del archivo de salida
output_file="tree-${fecha}.txt"

# Mostrar información inicial
echo "================================================"
echo " GENERADOR DE ESTRUCTURA DE DIRECTORIOS"
echo "================================================"
echo ""
echo "Ubicacion actual: $(pwd)"
echo "Archivo de salida: ${output_file}"
echo ""
echo "Generando estructura de archivos y carpetas..."
echo ""

# Crear y escribir la cabecera en el archivo de salida
{
    echo "ESTRUCTURA DE DIRECTORIOS Y ARCHIVOS"
    echo "=========================================="
    echo ""
    echo "Ubicacion: $(pwd)"
    echo "Fecha de generacion: ${fecha}"
    echo "Hora de generacion: $(date +"%T")"
    echo ""
    echo "=========================================="
    echo ""
} > "${output_file}"

# --- LÍNEA SIMPLIFICADA ---
# Simplemente ejecutar tree y añadir (>>) el resultado.
# tree desactivará los colores/códigos automáticamente.
tree >> "${output_file}"

# Agregar información adicional al final
{
    echo ""
    echo "=========================================="
    echo "Generado por: generate-tree.sh"
    echo "Sistema: $(hostname)"
    echo "Usuario: $(whoami)"
    echo "=========================================="
} >> "${output_file}"

# Mostrar resultado
echo "================================================"
echo " GENERACION COMPLETADA"
echo "================================================"
echo ""
echo "El archivo se ha guardado como: ${output_file}"
echo ""
read -p "Presiona Enter para abrir el archivo..."

# Abrir el archivo generado con el editor por defecto o nano/vim
if command -v xdg-open &> /dev/null
then
  xdg-open "${output_file}"  # Para entornos con GUI
else
  nano "${output_file}"      # Alternativa para terminal pura
fi

echo ""
read -p "Presiona Enter para salir..."
