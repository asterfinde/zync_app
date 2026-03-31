import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/user_status.dart';
import '../core/services/status_service.dart';

/// Modal de selección de estado ESPECÍFICO para notificaciones
/// Idéntico al StatusSelectorOverlay del Círculo — fuente de verdad: fallbackPredefined
class NotificationStatusSelector extends StatefulWidget {
  final VoidCallback? onClose;

  const NotificationStatusSelector({
    super.key,
    this.onClose,
  });

  @override
  State<NotificationStatusSelector> createState() => _NotificationStatusSelectorState();
}

class _NotificationStatusSelectorState extends State<NotificationStatusSelector> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isUpdating = false;

  // Grid dinámico — inicializado con fallbackPredefined para evitar timing issues
  List<StatusType?> _statusGrid = StatusType.fallbackPredefined;

  // Solo los tipos de zona configurados geográficamente se inhabilitan en el selector
  Set<String> _configuredZoneTypes = {};
  bool _isLoadingGrid = true;

  // SOS press & hold
  Timer? _sosTimer;
  double _sosHoldProgress = 0.0;
  bool _sosHolding = false;

  // Grid sin SOS (SOS va en botón separado)
  List<StatusType?> get _displayGrid => _statusGrid.where((s) => s?.id != 'sos').toList();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadStatusGrid();
    _waitForGridThenAnimate();
  }

  /// Espera a que el grid esté cargado antes de animar
  Future<void> _waitForGridThenAnimate() async {
    while (_isLoadingGrid && mounted) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (mounted) {
      _animationController.forward();
    }
  }

  Future<void> _loadStatusGrid() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final circleId = userDoc.data()?['circleId'] as String?;
      if (circleId == null) throw Exception('Usuario sin círculo');

      final zonesSnapshot =
          await FirebaseFirestore.instance.collection('circles').doc(circleId).collection('zones').get();

      final predefinedZones = zonesSnapshot.docs.where((doc) {
        final type = doc.data()['type'] as String?;
        return type != null && ['home', 'school', 'university', 'work'].contains(type);
      }).toList();

      final configuredTypes = predefinedZones
          .map((doc) => doc.data()['type'] as String)
          .toSet();

      await Future.delayed(const Duration(milliseconds: 50));

      if (mounted) {
        setState(() {
          _configuredZoneTypes = configuredTypes;
          _isLoadingGrid = false;
        });

        if (configuredTypes.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() {});
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusGrid = StatusType.fallbackPredefined;
          _configuredZoneTypes = {};
          _isLoadingGrid = false;
        });
      }
    }
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _sosTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startSosHold() {
    if (_isUpdating) return;
    setState(() {
      _sosHolding = true;
      _sosHoldProgress = 0.0;
    });
    _sosTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _sosHoldProgress += 30 / 1000);
      if (_sosHoldProgress >= 1.0) {
        timer.cancel();
        _triggerSos();
      }
    });
  }

  void _cancelSosHold() {
    _sosTimer?.cancel();
    _sosTimer = null;
    if (mounted) {
      setState(() {
        _sosHolding = false;
        _sosHoldProgress = 0.0;
      });
    }
  }

  Future<void> _triggerSos() async {
    final sos = StatusType.fallbackPredefined.firstWhere((s) => s.id == 'sos');
    _cancelSosHold();
    await _handleStatusSelection(sos);
  }

  Widget _buildSosButton() {
    return GestureDetector(
      onTapDown: (_) => _startSosHold(),
      onTapUp: (_) => _cancelSosHold(),
      onTapCancel: _cancelSosHold,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_sosHolding)
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: _sosHoldProgress,
                  color: Colors.white,
                  strokeWidth: 3,
                  backgroundColor: Colors.red.shade700,
                ),
              )
            else
              const Text(
                'S.O.S',
                style: TextStyle(
                  color: Colors.white,
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
                color: Colors.white,
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

  Future<void> _handleStatusSelection(StatusType status) async {
    if (_isUpdating) return;

    if (_configuredZoneTypes.contains(status.id)) {
      await _showZoneSelectionNotAllowedModal();
      return;
    }

    setState(() => _isUpdating = true);

    try {
      HapticFeedback.lightImpact();

      final result = await StatusService.updateUserStatus(status);

      if (result.isSuccess) {
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 300));
        await _closeModal();
      } else {
        if (result.errorMessage == 'zone_manual_selection_not_allowed') {
          await _showZoneSelectionNotAllowedModal();
        }
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _showZoneSelectionNotAllowedModal() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.grey.shade300.withOpacity(0.92),
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Acción no permitida',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No puedes seleccionar zonas manualmente. El estado de zonas se actualiza automáticamente por geofencing.',
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _closeModal() async {
    try {
      await _animationController.reverse();
      if (mounted) {
        Navigator.of(context).pop();
        widget.onClose?.call();
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final modalMargin = screenWidth * 0.08;
    final maxGridHeight = screenHeight * 0.55;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return GestureDetector(
          onTap: _closeModal,
          child: Container(
            color: Colors.black.withOpacity(0.85 * _fadeAnimation.value),
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    key: const Key('notification_status_selector'),
                    margin: EdgeInsets.all(modalMargin),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey.shade700.withOpacity(0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isLoadingGrid
                            ? SizedBox(
                                height: maxGridHeight,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF1EE9A4),
                                  ),
                                ),
                              )
                            : ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: maxGridHeight),
                                child: Scrollbar(
                                  thumbVisibility: true,
                                  thickness: 4,
                                  radius: const Radius.circular(8),
                                  child: GridView.builder(
                                    shrinkWrap: true,
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(8),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 1,
                                    ),
                                    itemCount: _displayGrid.length,
                                    itemBuilder: (context, index) {
                                      if (_displayGrid.isEmpty || index >= _displayGrid.length) {
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF1EE9A4),
                                            strokeWidth: 2,
                                          ),
                                        );
                                      }

                                      final gridItem = _displayGrid[index];

                                      if (gridItem != null) {
                                        return _buildStatusButton(gridItem);
                                      }

                                      return const SizedBox.shrink();
                                    },
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

  Widget _buildStatusButton(StatusType status) {
    final isBlockedZone = _configuredZoneTypes.contains(status.id);

    return Material(
      key: ValueKey('btn_status_${status.id}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: _isUpdating ? null : () => _handleStatusSelection(status),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: (_isUpdating || isBlockedZone)
                ? Colors.grey.shade800.withOpacity(0.3)
                : Colors.grey.shade800.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade600.withOpacity(0.4),
              width: 1,
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
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                  ),
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
                      color: Colors.white,
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
