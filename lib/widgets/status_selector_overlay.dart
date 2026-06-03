import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/user_status.dart';
import '../app/theme/design_tokens.dart';
import 'zone_selection_not_allowed_dialog.dart';

/// Modal de selección de estado. Widget puro: sin Firestore, Auth ni servicios estáticos.
/// El caller (showEmojiStatusBottomSheet) provee los datos y maneja los efectos.
class StatusSelectorOverlay extends StatefulWidget {
  final List<StatusType> available;
  final Set<String> blockedZoneTypes;
  final String? activeStatusId;
  final void Function(StatusType) onSelect;
  final VoidCallback onSosTriggered;
  final VoidCallback? onDismiss;

  const StatusSelectorOverlay({
    super.key,
    required this.available,
    required this.onSelect,
    required this.onSosTriggered,
    this.blockedZoneTypes = const {},
    this.activeStatusId,
    this.onDismiss,
  });

  @override
  State<StatusSelectorOverlay> createState() => _StatusSelectorOverlayState();
}

class _StatusSelectorOverlayState extends State<StatusSelectorOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  Timer? _sosTimer;
  bool _sosHolding = false;

  List<StatusType> get _displayGrid =>
      widget.available.where((s) => s.id != 'sos').toList();

  bool _isBlockedZone(StatusType status) =>
      widget.blockedZoneTypes.contains(status.id);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _sosTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startSosHold() {
    setState(() => _sosHolding = true);
    _sosTimer = Timer(const Duration(milliseconds: 1000), _triggerSos);
  }

  void _cancelSosHold() {
    _sosTimer?.cancel();
    _sosTimer = null;
    if (mounted) setState(() => _sosHolding = false);
  }

  void _triggerSos() {
    _cancelSosHold();
    unawaited(_closeModal());
    widget.onSosTriggered();
  }

  Future<void> _handleStatusSelection(StatusType status) async {
    if (_isBlockedZone(status)) {
      if (mounted) await showZoneSelectionNotAllowedDialog(context);
      return;
    }
    HapticFeedback.lightImpact();
    await _closeModal();
    widget.onSelect(status);
  }

  Future<void> _closeModal() async {
    try {
      await _animationController.reverse();
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDismiss?.call();
      }
    } catch (e) {
      debugPrint('[StatusSelectorOverlay] Error durante cierre: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final safeArea = MediaQuery.of(context).padding;
    final hMargin = screenWidth * 0.08;
    final vMargin = screenHeight * 0.06;
    const double reservedForNonGrid = 24.0 + 78.0;
    final availableModalHeight =
        screenHeight - 2 * vMargin - safeArea.top - safeArea.bottom;
    final maxGridHeight =
        (availableModalHeight - reservedForNonGrid).clamp(100.0, screenHeight * 0.55);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return GestureDetector(
          onTap: _closeModal,
          child: Container(
            color: NkColors.canvas.withValues(alpha: 0.85 * _fadeAnimation.value),
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: hMargin,
                      vertical: vMargin,
                    ),
                    constraints: const BoxConstraints(maxWidth: 380),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NkColors.surface2.withValues(alpha: 0.95),
                      borderRadius: NkRadius.forCard,
                      border: Border.all(
                        color: NkColors.surface4.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: NkColors.canvas.withValues(alpha: 0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: maxGridHeight),
                          child: Scrollbar(
                            thumbVisibility: true,
                            thickness: 4,
                            radius: const Radius.circular(8),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(8),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1,
                              ),
                              itemCount: _displayGrid.length,
                              itemBuilder: (context, index) =>
                                  _buildStatusButton(_displayGrid[index]),
                            ),
                          ),
                        ),
                        _buildSosButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSosButton() {
    final isSosActive = widget.activeStatusId == 'sos';
    return Listener(
      onPointerDown: (_) => _startSosHold(),
      onPointerUp: (_) => _cancelSosHold(),
      onPointerCancel: (_) => _cancelSosHold(),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: isSosActive && !_sosHolding
              ? NkColors.mintSoft(0.12)
              : NkColors.danger,
          borderRadius: NkRadius.forInput,
          border: Border.all(
            color: isSosActive ? NkColors.mint : NkColors.danger,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'S.O.S',
              style: TextStyle(
                color: NkColors.onDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _sosHolding ? 'Enviando SOS...' : 'Mantén presionado para enviar',
              style: const TextStyle(
                color: NkColors.onDark,
                fontSize: 11,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(StatusType status) {
    final isBlockedZone = _isBlockedZone(status);
    final isActive = widget.activeStatusId == status.id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleStatusSelection(status),
        borderRadius: NkRadius.forInput,
        child: Container(
          decoration: BoxDecoration(
            color: isActive
                ? NkColors.mintSoft(0.12)
                : isBlockedZone
                    ? NkColors.surface3.withValues(alpha: 0.3)
                    : NkColors.surface3.withValues(alpha: 0.6),
            borderRadius: NkRadius.forInput,
            border: Border.all(
              color: isActive
                  ? NkColors.mint
                  : NkColors.fgHint,
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: isBlockedZone ? 0.35 : 1.0,
                child: Text(
                  status.emoji,
                  style: const TextStyle(fontSize: 24, color: NkColors.onDark),
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Opacity(
                  opacity: isBlockedZone ? 0.35 : 0.8,
                  child: Text(
                    status.shortDescription,
                    style: const TextStyle(
                      fontSize: 9,
                      color: NkColors.onDark,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
