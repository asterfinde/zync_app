// lib/features/settings/presentation/pages/emoji_management_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/user_status.dart';
import '../../../../core/services/emoji_service.dart';
import '../../../../core/services/emoji_management_service.dart';
import '../widgets/create_emoji_dialog.dart';
import '../widgets/delete_emoji_dialog.dart';
import '../../../../app/theme/design_tokens.dart';

/// Página de gestión de estados/emojis
///
/// Muestra:
/// - Estados predefinidos de ZYNC (colapsables)
/// - Estados personalizados del círculo
/// - Botón para crear nuevo estado
/// - Contador de límite (X/10)
class EmojiManagementPage extends StatefulWidget {
  final String circleId;

  const EmojiManagementPage({
    super.key,
    required this.circleId,
  });

  @override
  State<EmojiManagementPage> createState() => _EmojiManagementPageState();
}

class _EmojiManagementPageState extends State<EmojiManagementPage> {
  bool _isLoadingPredefined = true;
  bool _isLoadingCustom = true;
  bool _showAllPredefined = false;

  List<StatusType> _predefinedEmojis = [];
  List<StatusType> _customEmojis = [];
  int _customEmojiCount = 0;

  String? _currentUserId;
  Map<String, bool> _deletePermissions = {}; // Cache de permisos

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadEmojis();
  }

  Future<void> _loadEmojis() async {
    setState(() {
      _isLoadingPredefined = true;
      _isLoadingCustom = true;
    });

    try {
      // Cargar predefinidos
      final predefined = await EmojiService.getPredefinedEmojis();
      setState(() {
        _predefinedEmojis = predefined;
        _isLoadingPredefined = false;
      });

      // Cargar custom
      final custom = await EmojiService.getCustomEmojis(widget.circleId);
      final count = await EmojiManagementService.getCustomEmojiCount(widget.circleId);

      // Cargar permisos de borrado para todos los emojis personalizados
      if (_currentUserId != null) {
        final permissions = <String, bool>{};
        for (final emoji in custom) {
          final canDelete = await EmojiManagementService.canDeleteEmoji(
            circleId: widget.circleId,
            userId: _currentUserId!,
            emojiId: emoji.id,
          );
          permissions[emoji.id] = canDelete;
        }
        _deletePermissions = permissions;
      }

      setState(() {
        _customEmojis = custom;
        _customEmojiCount = count;
        _isLoadingCustom = false;
      });
    } catch (e) {
      debugPrint('[EmojiManagement] Error cargando emojis: $e');
      setState(() {
        _isLoadingPredefined = false;
        _isLoadingCustom = false;
      });
    }
  }

  Future<void> _handleCreateEmoji() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CreateEmojiDialog(
        circleId: widget.circleId,
        currentCount: _customEmojiCount,
      ),
    );

    if (result == true) {
      // Recargar lista de custom emojis
      _loadEmojis();
    }
  }

  Future<void> _handleDeleteEmoji(StatusType emoji) async {
    if (_currentUserId == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteEmojiDialog(
        circleId: widget.circleId,
        userId: _currentUserId!,
        emoji: emoji,
      ),
    );

    if (result == true) {
      // Recargar lista de custom emojis
      _loadEmojis();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NkColors.canvas,
      appBar: AppBar(
        backgroundColor: NkColors.canvas,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mis Estados',
          style: TextStyle(
            color: NkColors.onDark,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadEmojis,
        color: NkColors.mint,
        backgroundColor: NkColors.surface2,
        child: ListView(
          padding: const EdgeInsets.all(NkSpacing.s),
          children: [
            // Sección: Estados de ZYNC (predefinidos)
            _buildPredefinedSection(),
            const SizedBox(height: 24),

            // Sección: Estados personalizados
            _buildCustomSection(),
            const SizedBox(height: 16),

            // Info tooltip
            _buildInfoTooltip(),
            const SizedBox(height: 100), // Espacio para el FAB
          ],
        ),
      ),
      floatingActionButton: SizedBox(
        width: 56,
        height: 56,
        child: FloatingActionButton(
          key: const Key('fab_create_emoji'),
          onPressed: _customEmojiCount >= EmojiManagementService.maxCustomEmojis ? null : _handleCreateEmoji,
          backgroundColor:
              _customEmojiCount >= EmojiManagementService.maxCustomEmojis ? NkColors.surface4 : NkColors.mint,
          foregroundColor: NkColors.canvas,
          shape: RoundedRectangleBorder(
            borderRadius: NkRadius.forButton,
          ),
          child: const Icon(Icons.add, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildPredefinedSection() {
    return Container(
      decoration: BoxDecoration(
        color: NkColors.surface2,
        borderRadius: NkRadius.forInput,
        border: Border.all(color: NkColors.surface4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(NkSpacing.s),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estados de ZYNC',
                  style: TextStyle(
                    color: NkColors.onDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: NkColors.mintSoft(0.2),
                    borderRadius: NkRadius.forInput,
                  ),
                  child: Text(
                    '${_predefinedEmojis.length} estados',
                    style: const TextStyle(
                      color: NkColors.mint,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: NkColors.surface4, height: 1),
          if (_isLoadingPredefined)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(
                  color: NkColors.mint,
                ),
              ),
            )
          else ...[
            // Mostrar los primeros 5 o todos
            ..._buildEmojiList(
              _showAllPredefined ? _predefinedEmojis : _predefinedEmojis.take(5).toList(),
              showDeleteButton: false,
            ),

            // Botón "Ver todos" si hay más de 5
            if (_predefinedEmojis.length > 5)
              InkWell(
                onTap: () => setState(() => _showAllPredefined = !_showAllPredefined),
                child: Container(
                  padding: const EdgeInsets.all(NkSpacing.s),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showAllPredefined ? 'Ver menos' : 'Ver todos (${_predefinedEmojis.length})',
                        style: const TextStyle(
                          color: NkColors.mint,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showAllPredefined ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: NkColors.mint,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomSection() {
    return Container(
      decoration: BoxDecoration(
        color: NkColors.surface2,
        borderRadius: NkRadius.forInput,
        border: Border.all(color: NkColors.surface4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(NkSpacing.s),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mis estados personalizados',
                  style: TextStyle(
                    color: NkColors.onDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$_customEmojiCount/${EmojiManagementService.maxCustomEmojis}',
                  style: const TextStyle(
                    color: NkColors.fgSub,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: NkColors.surface4, height: 1),
          if (_isLoadingCustom)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(
                  color: NkColors.mint,
                ),
              ),
            )
          else if (_customEmojis.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aún no tienes estados personalizados',
                  style: TextStyle(
                    color: NkColors.fgSub,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ..._buildEmojiList(_customEmojis, showDeleteButton: true),
        ],
      ),
    );
  }

  List<Widget> _buildEmojiList(List<StatusType> emojis, {required bool showDeleteButton}) {
    return emojis.map((emoji) {
      return InkWell(
        onTap: null, // Sin acción al tocar (solo visualización)
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: NkSpacing.s, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: NkColors.surface4.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              // Emoji
              Text(
                emoji.emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: NkSpacing.s),

              // Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emoji.label,
                      style: const TextStyle(
                        color: NkColors.onDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Delete button (solo para custom)
              if (showDeleteButton)
                IconButton(
                  key: ValueKey('btn_delete_emoji_${emoji.id}'),
                  icon: const Icon(Icons.delete_outline),
                  color: (_deletePermissions[emoji.id] ?? false)
                      ? NkColors.fgSub
                      : NkColors.fgDisabled,
                  onPressed: (_deletePermissions[emoji.id] ?? false) ? () => _handleDeleteEmoji(emoji) : null,
                  tooltip: (_deletePermissions[emoji.id] ?? false) ? 'Borrar estado' : 'Solo el creador puede borrar',
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildInfoTooltip() {
    return Container(
      padding: const EdgeInsets.all(NkSpacing.s),
      decoration: BoxDecoration(
        color: NkColors.surface2.withValues(alpha: 0.5),
        borderRadius: NkRadius.forInput,
        border: Border.all(
          color: NkColors.mintSoft(0.3),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.info_outline,
            color: NkColors.mint,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Todos los miembros del círculo pueden usar estos estados',
              style: TextStyle(
                color: NkColors.fgSub,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
