// lib/features/settings/presentation/widgets/delete_emoji_dialog.dart
import 'package:flutter/material.dart';
import 'package:zync_app/core/models/user_status.dart';
import '../../../../core/services/emoji_management_service.dart';

/// Colores de la app
class _AppColors {
  static const Color background = Color(0xFF000000);
  static const Color accent = Color(0xFF1EE9A4);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color cardBackground = Color(0xFF1C1C1E);
  static const Color sosRed = Color(0xFFD32F2F);
}

/// Dialog de confirmación para borrar un estado personalizado
///
/// Features:
/// - Muestra información contextual (quién lo usa)
/// - Prevención de borrados accidentales
/// - Feedback visual claro
class DeleteEmojiDialog extends StatefulWidget {
  final String circleId;
  final String userId; // ID del usuario actual
  final StatusType emoji;

  const DeleteEmojiDialog({
    super.key,
    required this.circleId,
    required this.userId,
    required this.emoji,
  });

  @override
  State<DeleteEmojiDialog> createState() => _DeleteEmojiDialogState();
}

class _DeleteEmojiDialogState extends State<DeleteEmojiDialog> {
  bool _isDeleting = false;
  bool _isLoadingUsageInfo = true;
  List<String> _currentUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsageInfo();
  }

  Future<void> _loadUsageInfo() async {
    try {
      final usageInfo = await EmojiManagementService.getEmojiUsageInfo(
        circleId: widget.circleId,
        emojiId: widget.emoji.id,
      );

      setState(() {
        _currentUsers = List<String>.from(usageInfo['currentUsers']);
        _isLoadingUsageInfo = false;
      });
    } catch (e) {
      setState(() => _isLoadingUsageInfo = false);
    }
  }

  Future<void> _handleDelete() async {
    setState(() => _isDeleting = true);

    try {
      final success = await EmojiManagementService.deleteCustomEmoji(
        circleId: widget.circleId,
        userId: widget.userId,
        emojiId: widget.emoji.id,
      );

      if (mounted && success) {
        Navigator.pop(context, true); // Return true = emoji borrado
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Estado eliminado correctamente'),
            backgroundColor: _AppColors.accent,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: _AppColors.sosRed,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: _AppColors.sosRed),
          SizedBox(width: 12),
          Text(
            '¿Borrar estado?',
            style: TextStyle(
              color: _AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji preview
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  widget.emoji.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.emoji.label,
                        style: const TextStyle(
                          color: _AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Usage information
          if (_isLoadingUsageInfo)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _AppColors.accent,
                ),
              ),
            )
          else ...[
            if (_currentUsers.isNotEmpty) ...[
              const Text(
                'Usuarios que lo están usando ahora:',
                style: TextStyle(
                  color: _AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              ...(_currentUsers.map((userName) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person,
                          size: 16,
                          color: _AppColors.accent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          userName,
                          style: const TextStyle(
                            color: _AppColors.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ))),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _AppColors.sosRed.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: _AppColors.sosRed,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentUsers.isEmpty
                          ? 'Este estado se eliminará permanentemente.'
                          : 'Al borrar, ${_currentUsers.length == 1 ? "este usuario cambiará" : "estos usuarios cambiarán"} a "Disponible".',
                      style: const TextStyle(
                        color: _AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: _AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _isDeleting ? null : _handleDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: _AppColors.sosRed,
            foregroundColor: _AppColors.textPrimary,
          ),
          child: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _AppColors.textPrimary,
                  ),
                )
              : const Text('Borrar'),
        ),
      ],
    );
  }
}
