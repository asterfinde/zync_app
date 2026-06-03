// lib/features/settings/presentation/widgets/create_emoji_dialog.dart
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/services/emoji_management_service.dart';

/// Dialog para crear un nuevo estado personalizado
///
/// Features:
/// - Emoji picker con búsqueda integrada
/// - Validación de nombre (2-30 chars)
/// - Previsualización del estado
/// - Muestra límite actual (X/10)
class CreateEmojiDialog extends StatefulWidget {
  final String circleId;
  final int currentCount;

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
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Estado creado correctamente'),
            backgroundColor: NkColors.mint,
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
        backgroundColor: NkColors.danger,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: NkColors.surface2,
      shape: RoundedRectangleBorder(borderRadius: NkRadius.forButton),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(NkSpacing.m),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Crear Estado Personalizado',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: NkColors.onDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: NkSpacing.xs2),
                  Text(
                    '${widget.currentCount}/${EmojiManagementService.maxCustomEmojis}',
                    style: NkTextStyle.meta,
                  ),
                ],
              ),
              const SizedBox(height: NkSpacing.m),
              _buildEmojiSelector(),
              const SizedBox(height: NkSpacing.s),
              if (_showEmojiPicker) _buildEmojiPicker(),
              if (!_showEmojiPicker) ...[
                Form(
                  key: _formKey,
                  child: TextFormField(
                    key: const Key('field_emoji_name'),
                    controller: _nameController,
                    style: const TextStyle(color: NkColors.onDark),
                    decoration: InputDecoration(
                      labelText: 'Nombre del estado',
                      labelStyle: NkTextStyle.meta,
                      hintText: 'Ej: Natación, Guitarra, Doctor',
                      hintStyle: NkTextStyle.meta,
                      filled: true,
                      fillColor: NkColors.surface3,
                      border: OutlineInputBorder(
                        borderRadius: NkRadius.forInput,
                        borderSide: BorderSide.none,
                      ),
                      counter: Text(
                        '${_nameController.text.length}/30',
                        style: NkTextStyle.micro,
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
                const SizedBox(height: NkSpacing.s),
                if (_selectedEmoji.isNotEmpty && _nameController.text.trim().isNotEmpty)
                  _buildPreview(),
                const SizedBox(height: NkSpacing.m),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isCreating ? null : () => Navigator.pop(context),
                      child: Text('Cancelar', style: NkTextStyle.meta),
                    ),
                    const SizedBox(width: NkSpacing.xs2),
                    ElevatedButton(
                      key: const Key('btn_create_emoji'),
                      onPressed: _isCreating ? null : _handleCreate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NkColors.mint,
                        foregroundColor: NkColors.onMint,
                        padding: const EdgeInsets.symmetric(
                          horizontal: NkSpacing.m,
                          vertical: NkSpacing.xs2,
                        ),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: NkColors.onMint,
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
      key: const Key('btn_select_emoji'),
      onTap: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
      borderRadius: NkRadius.forInput,
      child: Container(
        padding: const EdgeInsets.all(NkSpacing.s),
        decoration: BoxDecoration(
          color: NkColors.surface3,
          borderRadius: NkRadius.forInput,
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: NkColors.surface2,
                borderRadius: NkRadius.forSmall,
              ),
              child: Center(
                child: Text(
                  _selectedEmoji.isEmpty ? '?' : _selectedEmoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: NkSpacing.xs2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Emoji', style: NkTextStyle.micro),
                  const SizedBox(height: 4),
                  Text(
                    _selectedEmoji.isEmpty ? 'Toca para elegir' : 'Toca para cambiar',
                    style: NkTextStyle.meta,
                  ),
                ],
              ),
            ),
            Icon(
              _showEmojiPicker ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: NkColors.fgSub,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return Container(
      height: 300,
      margin: const EdgeInsets.only(top: NkSpacing.xs2),
      decoration: BoxDecoration(
        color: NkColors.surface3,
        borderRadius: NkRadius.forInput,
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
            backgroundColor: NkColors.surface3,
            columns: 7,
            buttonMode: ButtonMode.MATERIAL,
          ),
          skinToneConfig: const SkinToneConfig(),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor: NkColors.surface3,
            iconColor: NkColors.fgSub,
            iconColorSelected: NkColors.mint,
            indicatorColor: NkColors.mint,
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor: NkColors.surface3,
            buttonColor: NkColors.surface3,
            buttonIconColor: NkColors.fgSub,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: NkColors.surface3,
            buttonIconColor: NkColors.fgSub,
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
      padding: const EdgeInsets.all(NkSpacing.xs3),
      decoration: BoxDecoration(
        color: NkColors.surface3,
        borderRadius: NkRadius.forInput,
      ),
      child: Row(
        children: [
          Text('Vista previa:', style: NkTextStyle.micro),
          const SizedBox(width: NkSpacing.xs2),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: NkColors.surface2,
              borderRadius: NkRadius.forSmall,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_selectedEmoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 2),
                Text(
                  shortLabel,
                  style: NkTextStyle.micro,
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
