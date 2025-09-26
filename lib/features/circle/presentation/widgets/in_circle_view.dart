// lib/features/circle/presentation/widgets/in_circle_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart'; // Importante: Asegúrate de tener esta dependencia
import 'package:zync_app/features/circle/presentation/provider/circle_provider.dart';

import '../../../../core/global_keys.dart';
import '../../domain/entities/circle.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/user_status.dart';
// import '../../../auth/presentation/pages/sign_in_page.dart';

class InCircleView extends ConsumerWidget {
  final Circle circle;
  const InCircleView({super.key, required this.circle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    log('[InCircleView] invitationCode: "${circle.invitationCode}"');
    log('[InCircleView] Members hydrated: ${circle.members.map((e) => e.name)}');
    
    // --- UI UPDATE: Definimos la paleta de colores para consistencia ---
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final accentColor = Colors.tealAccent.shade400;
    final primaryTextColor = isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700;
    final cardBackgroundColor = isDarkMode ? Colors.grey.shade800.withOpacity(0.5) : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- UI UPDATE: Título del círculo con nuevo icono y estilo ---
          Row(
            children: [
              Icon(
                Icons.track_changes, // Un ícono más moderno que representa un 'círculo' o 'radar'
                color: accentColor,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  circle.name,
                  style: GoogleFonts.lato(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- UI UPDATE: Tarjeta de código de invitación rediseñada ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: cardBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: isDarkMode ? Border.all(color: Colors.grey.shade700, width: 0.5) : null,
              boxShadow: isDarkMode ? [] : [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CÓDIGO DE INVITACIÓN',
                      style: GoogleFonts.lato(
                        color: secondaryTextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      circle.invitationCode,
                      style: GoogleFonts.sourceCodePro(
                        color: primaryTextColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.copy_all_outlined, color: accentColor),
                  onPressed: () {
                    if (circle.invitationCode.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: circle.invitationCode));
                      rootScaffoldMessengerKey.currentState?.showSnackBar(
                        SnackBar(
                          content: const Text('¡Código de invitación copiado!'),
                          backgroundColor: accentColor,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // --- UI UPDATE: Título de la sección de miembros con estilo ---
          Text(
            'Miembros (${circle.members.length})',
            style: GoogleFonts.lato(
              color: primaryTextColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // --- UI UPDATE: Lista de miembros rediseñada como tarjetas individuales ---
          Expanded(
            child: circle.members.isEmpty
                ? Center(
                    child: Text(
                      'Buscando miembros...',
                      style: GoogleFonts.lato(color: secondaryTextColor),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8.0),
                    itemCount: circle.members.length,
                    itemBuilder: (context, index) {
                      final User member = circle.members[index];
                      final status = circle.memberStatus[member.uid];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                           border: isDarkMode ? Border.all(color: Colors.grey.shade800, width: 1) : null,
                        ),
                        child: Row(
                          children: [
                            Text(
                              status?.statusType.emoji ?? '⏳',
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (member.nickname.isNotEmpty)
                                        ? member.nickname
                                        : (member.name.isNotEmpty)
                                            ? member.name
                                            : 'Usuario: ${member.uid.substring(0, 6)}...',
                                    style: GoogleFonts.lato(
                                      color: primaryTextColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    status?.statusType.description ?? "Sin estado todavía",
                                    style: GoogleFonts.lato(
                                      color: secondaryTextColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          
          // --- UI UPDATE: Botón de acción con gradiente y sombra (consistente con login) ---
          Center(
            child: Container(
               decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withOpacity(0.8), accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  ref
                      .read(circleProvider.notifier)
                      .sendUserStatus(StatusType.fine);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Enviar Estado "Estoy Bien"',
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
