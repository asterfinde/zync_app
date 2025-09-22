import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      backgroundColor: Colors.black.withOpacity(0.2),
      body: Align(
        alignment: Alignment.topCenter,
        child: _QuickStatusSelectorContent(
          statuses: statuses,
          userId: userId,
          circleId: circleId,
        ),
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

  Future<void> _onStatusTap(StatusType status) async {
    if (widget.userId != null && widget.circleId != null && !_isSending) {
      setState(() => _isSending = true);
      final sendUserStatus = di.sl<SendUserStatus>();
      await sendUserStatus(SendUserStatusParams(
        circleId: widget.circleId!,
        statusType: status,
      ));
      setState(() => _showCheck = true);
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop();
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black26)],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedOpacity(
            opacity: _showCheck ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 250),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: widget.statuses.map((status) {
                return GestureDetector(
                  onTap: () => _onStatusTap(status),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(status.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 4),
                      Text(status.description, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          AnimatedScale(
            scale: _showCheck ? 1.0 : 0.7,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: _showCheck ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(24),
                child: Icon(Icons.check_circle_rounded, color: Colors.green[700], size: 56),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
