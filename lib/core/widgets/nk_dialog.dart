import 'package:flutter/material.dart';
import '../../app/theme/design_tokens.dart';

/// Diálogo unificado del Design System NunaKin.
///
/// UFV de estilo: modal "Silencio" en in_circle_footer.dart.
///
/// Uso básico:
///   final ok = await NkDialog.confirm(context, title: 'Silencio', body: '...');
///   await NkDialog.inform(context, title: 'Mi Cuenta', contentWidget: myCol);
class NkDialog {
  NkDialog._();

  // ─── Confirm ──────────────────────────────────────────────────────────────

  /// Muestra un diálogo de confirmación con dos acciones (cancelar / confirmar).
  /// Retorna `true` si el usuario confirma, `false` o `null` en caso contrario.
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String body,
    String cancelLabel = 'Cancelar',
    String confirmLabel = 'Confirmar',
    bool confirmDestructive = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: NkColors.canvas.withValues(alpha: 0.75),
      barrierDismissible: barrierDismissible,
      builder: (ctx) => Dialog(
        backgroundColor: NkColors.canvas,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: NkSpacing.m,
          vertical: NkSpacing.m,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: NkRadius.forButton,
          side: BorderSide(color: NkColors.mintSoft(0.4), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(NkSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NkTextStyle.h3),
              const SizedBox(height: 12),
              Text(
                body,
                style: NkTextStyle.meta.copyWith(color: NkColors.fgMuted),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: NkColors.fgSub,
                    ),
                    child: Text(cancelLabel),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: TextButton.styleFrom(
                      foregroundColor: confirmDestructive
                          ? NkColors.danger
                          : NkColors.mint,
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Inform ───────────────────────────────────────────────────────────────

  /// Muestra un diálogo informativo con una sola acción de cierre.
  /// Acepta [body] (texto plano) o [contentWidget] (widget custom).
  /// Si se pasan ambos, [contentWidget] tiene prioridad.
  static Future<void> inform(
    BuildContext context, {
    required String title,
    String? body,
    Widget? contentWidget,
    String closeLabel = 'Entendido',
    Color? closeColor,
  }) {
    assert(body != null || contentWidget != null,
        'NkDialog.inform requiere body o contentWidget');
    return showDialog<void>(
      context: context,
      barrierColor: NkColors.canvas.withValues(alpha: 0.75),
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: NkColors.canvas,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: NkSpacing.m,
          vertical: NkSpacing.m,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: NkRadius.forButton,
          side: BorderSide(color: NkColors.mintSoft(0.4), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(NkSpacing.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: NkTextStyle.h3),
              const SizedBox(height: 12),
              if (contentWidget != null)
                contentWidget
              else
                Text(
                  body!,
                  style: NkTextStyle.meta.copyWith(color: NkColors.fgMuted),
                ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: closeColor ?? NkColors.mint,
                  ),
                  child: Text(
                    closeLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
