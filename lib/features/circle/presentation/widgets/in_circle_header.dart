import 'package:flutter/material.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/splash/splash_screen.dart' show ZyncLogoPainter;
import '../../../settings/presentation/pages/settings_page.dart';

class InCircleHeader extends StatelessWidget {
  final String nickname;

  const InCircleHeader({super.key, required this.nickname});

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
              mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(height: 4),
                Text(
                  nickname,
                  style: NkTextStyle.body.copyWith(color: NkColors.fgSub),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            key: const Key('btn_settings'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: NkColors.mint,
              backgroundColor: const Color(0xFF052A1D),
              side: BorderSide.none,
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: NkRadius.forInput),
            ),
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Ajustes'),
          ),
        ],
      ),
    );
  }
}
