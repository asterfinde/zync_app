#!/bin/bash

echo "🧪 ===== EJECUTANDO APP DE PRUEBA ====="
echo ""
echo "📱 TESTING: Minimizar/Maximizar Performance"
echo ""
echo "INSTRUCCIONES:"
echo "1. ✅ La app se abrirá con datos por defecto"
echo "2. 📱 Minimiza la app (botón Home)"
echo "3. 🔄 Maximiza la app (Recent Apps)"
echo "4. ⏱️ Observa: Debe aparecer INSTANTÁNEAMENTE con 'CACHE HIT' y <100ms"
echo ""
echo "LOGS A OBSERVAR:"
echo "  ✅ [TestCache] Cargados X items"
echo "  🟢 CACHE HIT"
echo "  ✅ [LoadData] Duration: <100ms"
echo ""
echo "Si NO funciona:"
echo "  ❌ [TestCache] No hay datos"
echo "  🔴 CACHE MISS"
echo "  ⏰ [LoadData] Duration: >500ms"
echo ""
echo "================================================"
echo ""

# Ejecutar app de prueba
flutter run -t lib/main_test.dart
