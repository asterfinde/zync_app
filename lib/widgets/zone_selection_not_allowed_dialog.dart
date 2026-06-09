import 'package:flutter/material.dart';
import '../core/widgets/nk_dialog.dart';

/// Diálogo informativo cuando el usuario intenta seleccionar manualmente
/// un emoji asociado a una zona configurada por geofencing.
Future<void> showZoneSelectionNotAllowedDialog(BuildContext context) {
  return NkDialog.inform(
    context,
    title: 'Acción no permitida',
    body: 'No puedes seleccionar zonas manualmente. El estado de zonas se actualiza automáticamente por geofencing.',
  );
}
