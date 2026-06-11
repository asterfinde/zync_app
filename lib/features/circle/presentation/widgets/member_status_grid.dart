import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nunakin_app/app/theme/design_tokens.dart';
import 'package:nunakin_app/core/models/user_status.dart';

/// Grid de estados de miembros del círculo.
/// Widget puro: sin acceso a Firestore, CircleService ni servicios estáticos.
/// Extraído de in_circle_view.dart en Sem 5 Día 2.
class MemberStatusGrid extends StatelessWidget {
  final List<String> sortedMemberIds;
  final Map<String, String> nicknamesCache;
  final Map<String, Map<String, dynamic>> memberDataCache;
  final bool isLoading;
  final String? currentUserId;
  final String? currentUserNickname;
  final String? lastKnownStatusId;
  final List<StatusType>? predefinedEmojis;
  final void Function(BuildContext context, String? activeStatusId) onTapStatus;
  final void Function(BuildContext context, Map<String, dynamic> coords, String memberName) onOpenMaps;

  const MemberStatusGrid({
    super.key,
    required this.sortedMemberIds,
    required this.nicknamesCache,
    required this.memberDataCache,
    required this.isLoading,
    required this.currentUserId,
    required this.currentUserNickname,
    required this.lastKnownStatusId,
    required this.predefinedEmojis,
    required this.onTapStatus,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.people_outline, size: 24, color: NkColors.mint),
        const SizedBox(height: 16),
        if (isLoading)
          const Center(child: CircularProgressIndicator(color: NkColors.mint))
        else
          Column(
            children: sortedMemberIds.asMap().entries.map((entry) {
              final index = entry.key;
              final memberId = entry.value;
              final isCurrentUser = currentUserId == memberId;
              final nickname = isCurrentUser
                  ? (currentUserNickname ?? nicknamesCache[memberId] ?? '...')
                  : (nicknamesCache[memberId] ?? '...');
              final memberData = memberDataCache[memberId] ??
                  {
                    'emoji': '⏳',
                    'status': lastKnownStatusId ?? 'fine',
                    'hasGPS': false,
                    'coordinates': null,
                    'lastUpdate': null,
                  };
              final status = memberData['status'] as String? ?? (lastKnownStatusId ?? 'fine');

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _MemberListItem(
                  key: ValueKey('${memberId}_$status'),
                  memberId: memberId,
                  nickname: nickname,
                  isCurrentUser: isCurrentUser,
                  isFirst: index == 0,
                  memberData: memberData,
                  onTap: isCurrentUser
                      ? () {
                          final activeStatusId =
                              (status == 'loading' || status == 'unknown')
                                  ? lastKnownStatusId
                                  : status;
                          onTapStatus(context, activeStatusId);
                        }
                      : null,
                  onOpenMaps: onOpenMaps,
                  predefinedEmojis: predefinedEmojis,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

// ==============================================================================
// _MemberListItem — movido desde in_circle_view.dart (Sem 5 Día 2)
// ==============================================================================
class _MemberListItem extends StatelessWidget {
  final String memberId;
  final String nickname;
  final bool isCurrentUser;
  final bool isFirst;
  final Map<String, dynamic> memberData;
  final VoidCallback? onTap;
  final void Function(BuildContext context, Map<String, dynamic> coords, String memberName)
      onOpenMaps;
  final List<StatusType>? predefinedEmojis;

  const _MemberListItem({
    super.key,
    required this.memberId,
    required this.nickname,
    required this.isCurrentUser,
    required this.isFirst,
    required this.memberData,
    this.onTap,
    required this.onOpenMaps,
    this.predefinedEmojis,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = memberData['emoji'] as String? ?? '⏳';
    final status = memberData['status'] as String? ?? 'loading';
    final hasGPS = memberData['hasGPS'] as bool? ?? false;
    final coordinates = memberData['coordinates'] as Map<String, dynamic>?;
    final lastUpdate = memberData['lastUpdate'] as DateTime?;
    final displayText = memberData['displayText'] as String?;
    final showManualBadge = memberData['showManualBadge'] as bool? ?? false;
    final locationInfo = memberData['locationInfo'] as String?;
    final isSOS = status == 'sos';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0x18FFFFFF),
        border: Border.all(color: NkColors.surfaceBorder),
        borderRadius: NkRadius.forCard,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: status == 'loading'
              ? null
              : (isCurrentUser && onTap != null) || (hasGPS && coordinates != null)
                  ? () {
                      if (isCurrentUser && onTap != null) {
                        HapticFeedback.mediumImpact();
                        onTap!();
                      } else {
                        HapticFeedback.lightImpact();
                        onOpenMaps(context, coordinates!, nickname);
                      }
                    }
                  : null,
          borderRadius: NkRadius.forCard,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Emoji avatar con badge de edición para el usuario actual
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0x20FFFFFF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: Text(emoji,
                                key: ValueKey(emoji),
                                style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                        if (isCurrentUser && status != 'loading')
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: NkColors.mint,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, size: 10, color: NkColors.canvas),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nombre + badge TÚ
                          Row(
                            children: [
                              Flexible(
                                child: Text(nickname,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: NkColors.onDark),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (isCurrentUser) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: NkColors.mint,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'TÚ',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: NkColors.canvas,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // Estado
                          if (displayText != null)
                            Text(displayText,
                                style: isSOS
                                    ? const TextStyle(
                                        fontSize: 13,
                                        color: NkColors.danger,
                                        fontWeight: FontWeight.bold)
                                    : const TextStyle(
                                        fontSize: 13, color: NkColors.fgSub)),
                          // Línea meta: timestamp • Creador • Manual
                          Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (lastUpdate != null)
                                Text(
                                  key: const Key('text_member_timestamp'),
                                  _formatTimestamp(lastUpdate),
                                  style: const TextStyle(
                                      fontSize: 11, color: NkColors.fgHint),
                                ),
                              if (isFirst && status != 'loading')
                                Text(
                                  '• Creador',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: NkColors.mintSoft(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              if (showManualBadge)
                                const Text(
                                  key: Key('badge_manual'),
                                  '• ✋ Manual',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.orange),
                                ),
                            ],
                          ),
                          if (locationInfo != null)
                            Text(
                              key: const Key('text_location_info'),
                              locationInfo,
                              style: const TextStyle(
                                  fontSize: 11, color: NkColors.fgHint),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasGPS && coordinates != null && status != 'loading') ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onOpenMaps(context, coordinates, nickname);
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 16, color: NkColors.danger),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Ubicación SOS compartida',
                            style: TextStyle(
                                fontSize: 12,
                                color: NkColors.onDark,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            size: 12,
                            color: NkColors.danger.withValues(alpha: 0.7)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final difference = DateTime.now().difference(dt);
    if (difference.inSeconds < 60) return 'Justo Ahora';
    if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Hace ${difference.inHours} h';
    return 'Hace ${difference.inDays} d';
  }
}
