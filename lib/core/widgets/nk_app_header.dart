import 'package:flutter/material.dart';
import '../splash/splash_screen.dart' show ZyncLogoPainter;
import '../../app/theme/design_tokens.dart';

class NkAppHeader extends StatelessWidget {
  final String? subtitle;
  final Widget? trailing;

  const NkAppHeader({super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      color: NkColors.canvas,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CustomPaint(painter: ZyncLogoPainter(color: NkColors.mint)),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'NunaKin',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: NkColors.mint,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: NkTextStyle.body.copyWith(color: NkColors.fgSub),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
