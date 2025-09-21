import 'package:flutter/material.dart';
import 'package:zync_app/features/circle/domain/entities/user_status.dart';
import 'package:zync_app/features/circle/domain/usecases/send_user_status.dart';
import 'package:zync_app/core/di/injection_container.dart' as di;

class QuickStatusSendDialog extends StatefulWidget {
  final StatusType statusType;
  final String userId;
  final String circleId;
  const QuickStatusSendDialog({Key? key, required this.statusType, required this.userId, required this.circleId}) : super(key: key);
  @override
  State<QuickStatusSendDialog> createState() => _QuickStatusSendDialogState();
}

class _QuickStatusSendDialogState extends State<QuickStatusSendDialog> {
  bool _showCheck = false;
  @override
  void initState() {
    super.initState();
    _sendStatus();
  }
  Future<void> _sendStatus() async {
    final sendUserStatus = di.sl<SendUserStatus>();
    await sendUserStatus(SendUserStatusParams(
      circleId: widget.circleId,
      statusType: widget.statusType,
    ));
    setState(() => _showCheck = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.of(context).pop();
  }
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 120,
        height: 120,
        child: Center(
          child: AnimatedScale(
            scale: _showCheck ? 1.0 : 0.7,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: _showCheck ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Icon(Icons.check_circle_rounded, color: Colors.green[700], size: 72),
            ),
          ),
        ),
      ),
    );
  }
}
