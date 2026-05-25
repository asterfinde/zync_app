import 'package:flutter/material.dart';
import '../../../settings/presentation/pages/settings_page.dart';

class InCircleHeader extends StatelessWidget {
  final String nickname;

  const InCircleHeader({super.key, required this.nickname});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      color: Colors.black,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NunaKin',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  nickname,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF9E9E9E),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            key: const Key('btn_settings'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1CE7E8),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Ajustes'),
          ),
        ],
      ),
    );
  }
}
