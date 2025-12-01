// lib/features/settings/presentation/widgets/create_emoji_dialog.dart
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/emoji_management_service.dart';

/// Colores de la app
class _AppColors {
  static const Color background = Color(0xFF000000);
  static const Color accent = Color(0xFF1EE9A4);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color cardBackground = Color(0xFF1C1C1E);
  static const Color inputFill = Color(0xFF2C2C2E);
  static const Color sosRed = Color(0xFFD32F2F);
}

/// Dialog para crear un nuevo estado personalizado
///
/// Features:
/// - Emoji picker con búsqueda integrada
/// - Validación de nombre (2-30 chars)
/// - Previsualización del estado
/// - Muestra límite actual (X/10)
class CreateEmojiDialog extends StatefulWidget {
  final String circleId;
  final int currentCount; // Actual count of custom emojis

  const CreateEmojiDialog({
    super.key,
    required this.circleId,
    required this.currentCount,
  });

  @override
  State<CreateEmojiDialog> createState() => _CreateEmojiDialogState();
}

class _CreateEmojiDialogState extends State<CreateEmojiDialog> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedEmoji = '';
  bool _showEmojiPicker = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEmoji.isEmpty) {
      _showError('Por favor selecciona un emoji');
      return;
    }

    setState(() => _isCreating = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Usuario no autenticado');

      await EmojiManagementService.createCustomEmoji(
        circleId: widget.circleId,
        userId: userId,
        emoji: _selectedEmoji,
        label: _nameController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true = emoji creado
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Estado creado correctamente'),
            backgroundColor: _AppColors.accent,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isCreating = false);
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _AppColors.sosRed,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Crear Estado Personalizado',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.currentCount}/${EmojiManagementService.maxCustomEmojis}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: _AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Emoji selector
              _buildEmojiSelector(),
              const SizedBox(height: 16),

              // Emoji picker (si está activo)
              if (_showEmojiPicker) _buildEmojiPicker(),

              // Name field (solo si no está el picker abierto)
              if (!_showEmojiPicker) ...[
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: _AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nombre del estado',
                      labelStyle: const TextStyle(color: _AppColors.textSecondary),
                      hintText: 'Ej: Natación, Guitarra, Doctor',
                      hintStyle: const TextStyle(color: _AppColors.textSecondary),
                      filled: true,
                      fillColor: _AppColors.inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      counter: Text(
                        '${_nameController.text.length}/30',
                        style: const TextStyle(
                          color: _AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    maxLength: 30,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa un nombre';
                      }
                      if (value.trim().length < 2) {
                        return 'Mínimo 2 caracteres';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 16),

                // Preview
                if (_selectedEmoji.isNotEmpty && _nameController.text.trim().isNotEmpty) _buildPreview(),

                const SizedBox(height: 20),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isCreating ? null : () => Navigator.pop(context),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: _AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isCreating ? null : _handleCreate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _AppColors.accent,
                        foregroundColor: _AppColors.background,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _AppColors.background,
                              ),
                            )
                          : const Text('Crear'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiSelector() {
    return InkWell(
      onTap: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _AppColors.inputFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _AppColors.cardBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _selectedEmoji.isEmpty ? '?' : _selectedEmoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Emoji',
                    style: TextStyle(
                      color: _AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedEmoji.isEmpty ? 'Toca para elegir' : 'Toca para cambiar',
                    style: const TextStyle(
                      color: _AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _showEmojiPicker ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: _AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return Container(
      height: 300,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: _AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          setState(() {
            _selectedEmoji = emoji.emoji;
            _showEmojiPicker = false;
          });
        },
        config: Config(
          height: 300,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            emojiSizeMax: 28,
            backgroundColor: _AppColors.inputFill,
            columns: 7,
            buttonMode: ButtonMode.MATERIAL,
          ),
          skinToneConfig: const SkinToneConfig(),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: _AppColors.inputFill,
            iconColor: _AppColors.textSecondary,
            iconColorSelected: _AppColors.accent,
            indicatorColor: _AppColors.accent,
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: _AppColors.inputFill,
            buttonColor: _AppColors.inputFill,
            buttonIconColor: _AppColors.textSecondary,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: _AppColors.inputFill,
            buttonIconColor: _AppColors.textSecondary,
            hintText: 'Buscar emoji...',
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final label = _nameController.text.trim();
    final shortLabel = label.length > 6 ? '${label.substring(0, 6)}.' : label;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text(
            'Vista previa:',
            style: TextStyle(
              color: _AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _AppColors.cardBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _selectedEmoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(height: 2),
                Text(
                  shortLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    color: _AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
