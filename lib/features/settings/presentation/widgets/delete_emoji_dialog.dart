// lib/features/settings/presentation/widgets/delete_emoji_dialog.dart
import 'package:flutter/material.dart';
import 'package:nunakin_app/core/models/user_status.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/services/emoji_management_service.dart';

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
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Estado eliminado correctamente'),
            backgroundColor: NkColors.mint,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: NkColors.danger,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NkColors.surface2,
      shape: RoundedRectangleBorder(borderRadius: NkRadius.forButton),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: NkColors.danger),
          SizedBox(width: NkSpacing.xs2),
          Text(
            '¿Borrar estado?',
            style: TextStyle(
              color: NkColors.onDark,
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
          Container(
            padding: const EdgeInsets.all(NkSpacing.s),
            decoration: BoxDecoration(
              color: NkColors.canvas,
              borderRadius: NkRadius.forInput,
            ),
            child: Row(
              children: [
                Text(widget.emoji.emoji, style: NkTextStyle.display),
                const SizedBox(width: NkSpacing.xs2),
                Expanded(
                  child: Text(
                    widget.emoji.label,
                    style: const TextStyle(
                      color: NkColors.onDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: NkSpacing.s),
          if (_isLoadingUsageInfo)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NkColors.mint,
                ),
              ),
            )
          else ...[
            if (_currentUsers.isNotEmpty) ...[
              Text(
                'Usuarios que lo están usando ahora:',
                style: NkTextStyle.micro,
              ),
              const SizedBox(height: NkSpacing.xs2),
              ...(_currentUsers.map((userName) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: NkColors.mint),
                        const SizedBox(width: 6),
                        Text(userName, style: NkTextStyle.meta),
                      ],
                    ),
                  ))),
              const SizedBox(height: NkSpacing.xs2),
            ],
            Container(
              padding: const EdgeInsets.all(NkSpacing.xs3),
              decoration: BoxDecoration(
                color: NkColors.canvas,
                borderRadius: NkRadius.forSmall,
                border: Border.all(color: NkColors.dangerSoft),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: NkColors.danger),
                  const SizedBox(width: NkSpacing.xs2),
                  Expanded(
                    child: Text(
                      _currentUsers.isEmpty
                          ? 'Este estado se eliminará permanentemente.'
                          : 'Al borrar, ${_currentUsers.length == 1 ? "este usuario cambiará" : "estos usuarios cambiarán"} a "Disponible".',
                      style: NkTextStyle.micro.copyWith(color: NkColors.onDark),
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
          key: const Key('btn_delete_emoji_cancel'),
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: Text('Cancelar', style: NkTextStyle.meta),
        ),
        ElevatedButton(
          key: const Key('btn_delete_emoji_confirm'),
          onPressed: _isDeleting ? null : _handleDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: NkColors.danger,
            foregroundColor: NkColors.onDark,
          ),
          child: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NkColors.onDark,
                  ),
                )
              : const Text('Borrar'),
        ),
      ],
    );
  }
}
