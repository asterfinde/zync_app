// lib/features/settings/presentation/pages/emoji_management_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/user_status.dart';
import '../../../../core/services/emoji_service.dart';
import '../../../../core/services/emoji_management_service.dart';
import '../widgets/create_emoji_dialog.dart';
import '../widgets/delete_emoji_dialog.dart';

/// Colores de la app
class _AppColors {
  static const Color background = Color(0xFF000000);
  static const Color accent = Color(0xFF1EE9A4);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color cardBackground = Color(0xFF1C1C1E);
  static const Color cardBorder = Color(0xFF3A3A3C);
}

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
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        backgroundColor: _AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mis Estados',
          style: TextStyle(
            color: _AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadEmojis,
        color: _AppColors.accent,
        backgroundColor: _AppColors.cardBackground,
        child: ListView(
          padding: const EdgeInsets.all(16),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _customEmojiCount >= EmojiManagementService.maxCustomEmojis ? null : _handleCreateEmoji,
        backgroundColor:
            _customEmojiCount >= EmojiManagementService.maxCustomEmojis ? _AppColors.cardBorder : _AppColors.accent,
        foregroundColor: _AppColors.background,
        icon: const Icon(Icons.add),
        label: Text(
          'Crear estado ($_customEmojiCount/${EmojiManagementService.maxCustomEmojis})',
        ),
      ),
    );
  }

  Widget _buildPredefinedSection() {
    return Container(
      decoration: BoxDecoration(
        color: _AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estados de ZYNC',
                  style: TextStyle(
                    color: _AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _AppColors.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_predefinedEmojis.length} estados',
                    style: const TextStyle(
                      color: _AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: _AppColors.cardBorder, height: 1),
          if (_isLoadingPredefined)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(
                  color: _AppColors.accent,
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
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _showAllPredefined ? 'Ver menos' : 'Ver todos (${_predefinedEmojis.length})',
                        style: const TextStyle(
                          color: _AppColors.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showAllPredefined ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: _AppColors.accent,
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
        color: _AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Mis estados personalizados',
              style: TextStyle(
                color: _AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Divider(color: _AppColors.cardBorder, height: 1),
          if (_isLoadingCustom)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(
                  color: _AppColors.accent,
                ),
              ),
            )
          else if (_customEmojis.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 48,
                    color: _AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Aún no tienes estados personalizados',
                    style: TextStyle(
                      color: _AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea uno para personalizar tu experiencia',
                    style: TextStyle(
                      color: _AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _AppColors.cardBorder.withOpacity(0.5),
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
              const SizedBox(width: 16),

              // Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emoji.label,
                      style: const TextStyle(
                        color: _AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (emoji.shortLabel != emoji.label)
                      Text(
                        'Grid: ${emoji.shortLabel}',
                        style: const TextStyle(
                          color: _AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),

              // Delete button (solo para custom)
              if (showDeleteButton)
                StreamBuilder<bool>(
                  stream: _canDeleteStream(emoji.id),
                  builder: (context, snapshot) {
                    final canDelete = snapshot.data ?? false;

                    return IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: canDelete ? _AppColors.textSecondary : _AppColors.textSecondary.withOpacity(0.3),
                      onPressed: canDelete ? () => _handleDeleteEmoji(emoji) : null,
                      tooltip: canDelete ? 'Borrar estado' : 'Solo el creador puede borrar',
                    );
                  },
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildInfoTooltip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.cardBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _AppColors.accent.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: _AppColors.accent,
            size: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Todos los miembros del círculo pueden usar estos estados',
              style: TextStyle(
                color: _AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Stream<bool> _canDeleteStream(String emojiId) async* {
    if (_currentUserId == null) {
      yield false;
      return;
    }

    final canDelete = await EmojiManagementService.canDeleteEmoji(
      circleId: widget.circleId,
      userId: _currentUserId!,
      emojiId: emojiId,
    );

    yield canDelete;
  }
}
