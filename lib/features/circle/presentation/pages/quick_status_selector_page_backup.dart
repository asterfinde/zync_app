// lib/features/circle/presentation/pages/quick_status_selector_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // Necesario para el efecto de desenfoque (blur)
import 'package:zync_app/features/circle/domain/entities/user_status.dart';
import 'package:zync_app/features/circle/domain/usecases/send_user_status.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_provider.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_state.dart';
import 'package:zync_app/features/circle/presentation/provider/circle_provider.dart';
import 'package:zync_app/features/circle/presentation/provider/circle_state.dart';
import 'package:zync_app/core/di/injection_container.dart' as di;

class QuickStatusSelectorPage extends ConsumerWidget {
  const QuickStatusSelectorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = StatusType.values;
    final authState = ref.watch(authProvider);
    final circleState = ref.watch(circleProvider);
    final userId = authState is Authenticated ? authState.user.uid : null;
    String? circleId;
    if (circleState is CircleLoaded) {
      circleId = circleState.circle.id;
    }
    return Scaffold(
      backgroundColor: Colors.transparent, // Hacemos el fondo transparente
      body: _QuickStatusSelectorContent(
        statuses: statuses,
        userId: userId,
        circleId: circleId,
      ),
    );
  }
}

class _QuickStatusSelectorContent extends StatefulWidget {
  final List<StatusType> statuses;
  final String? userId;
  final String? circleId;

  const _QuickStatusSelectorContent({
    required this.statuses,
    required this.userId,
    required this.circleId,
  });

  @override
  State<_QuickStatusSelectorContent> createState() => _QuickStatusSelectorContentState();
}

class _QuickStatusSelectorContentState extends State<_QuickStatusSelectorContent> with SingleTickerProviderStateMixin {
  bool _showCheck = false;
  bool _isSending = false;
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    // Animación para que el panel se deslice hacia arriba
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onStatusTap(StatusType status) async {
    if (widget.userId != null && widget.circleId != null && !_isSending) {
      setState(() => _isSending = true);
      final sendUserStatus = di.sl<SendUserStatus>();
      await sendUserStatus(SendUserStatusParams(
        circleId: widget.circleId!,
        statusType: status,
      ));
      setState(() => _showCheck = true);
      await Future.delayed(const Duration(milliseconds: 400));
      _controller.reverse(); // Desliza el panel hacia abajo antes de cerrar
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop();
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }
  
  // Mapeo de colores para cada estado
  Color _getColorForStatus(StatusType status, bool isDarkMode) {
    switch (status) {
      case StatusType.sos:
        return Colors.red.shade400;
      case StatusType.leave:
        return Colors.blue.shade400;
      case StatusType.busy:
        return Colors.orange.shade400;
      case StatusType.fine:
        return Colors.green.shade400;
      case StatusType.sad:
        return Colors.amber.shade400;
      case StatusType.ready:
        return Colors.purple.shade400;
      default:
        return isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final accentColor = Colors.tealAccent.shade400;
    final cardBackgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return GestureDetector(
      onTap: () async { // Permite cerrar al tocar fuera del panel
        await _controller.reverse();
        if (mounted) Navigator.of(context).pop();
      },
      // Fondo con efecto de desenfoque (blur)
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          color: Colors.black.withOpacity(0.4),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _offsetAnimation,
              child: GestureDetector(
                onTap: () {}, // Evita que el panel se cierre al tocar dentro de él
                child: Container(
                  padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 32),
                  decoration: BoxDecoration(
                    color: cardBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Contenido principal (lista vertical de estados)
                      AnimatedOpacity(
                        opacity: _showCheck ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // "Handle" o tirador para indicar que es un panel deslizable
                            Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade600,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "Actualiza tu estado",
                              style: GoogleFonts.lato(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Lista de estados con nuevo diseño
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: widget.statuses.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final status = widget.statuses[index];
                                final statusColor = _getColorForStatus(status, isDarkMode);
                                return Material(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: () => _onStatusTap(status),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(status.emoji, style: const TextStyle(fontSize: 22)),
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            status.description,
                                            style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // Animación de confirmación
                      AnimatedScale(
                        scale: _showCheck ? 1.0 : 0.7,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: _showCheck ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          child: Icon(Icons.check_circle_rounded, color: accentColor, size: 80),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
