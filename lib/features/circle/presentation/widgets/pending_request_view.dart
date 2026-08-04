import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nunakin_app/core/services/session_cache_service.dart';
import 'package:nunakin_app/contexts/identity/presentation/pages/auth_final_page.dart';
import 'package:nunakin_app/app/theme/design_tokens.dart';
import '../../../../services/circle_service.dart';

class PendingRequestView extends StatefulWidget {
  final String pendingCircleId;

  const PendingRequestView({super.key, required this.pendingCircleId});

  @override
  State<PendingRequestView> createState() => _PendingRequestViewState();
}

class _PendingRequestViewState extends State<PendingRequestView> {
  String? _circleName;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _requestSubscription;

  @override
  void initState() {
    super.initState();
    _loadCircleName();
    // DT-RULES-CIRCLES-OPEN: el creador ya no puede escribir el circleId de
    // este usuario directamente — este listener aplica el veredicto (self-write)
    // apenas el creador aprueba/rechaza. HomePage.getUserCircleStream() ya
    // reacciona a ese cambio y transiciona la pantalla automáticamente.
    _requestSubscription = CircleService().listenToOwnJoinRequest(
      circleId: widget.pendingCircleId,
    );
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCircleName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('circles')
          .doc(widget.pendingCircleId)
          .get();
      if (mounted && doc.exists) {
        setState(() {
          _circleName = doc.data()?['name'] as String?;
        });
      }
    } catch (_) {
      // Si falla, no mostramos el nombre — no es crítico
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('pending_request_view'),
      backgroundColor: NkColors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 72,
                color: NkColors.mint,
              ),
              const SizedBox(height: 32),
              const Text(
                'Solicitud enviada',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: NkColors.onDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_circleName != null) ...[
                Text(
                  _circleName!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: NkColors.mint,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'Tu solicitud fue enviada. Esperando que el creador del círculo la apruebe.',
                style: TextStyle(
                  fontSize: 16,
                  color: NkColors.fgMuted,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(NkSpacing.s),
                decoration: BoxDecoration(
                  border: Border.all(color: NkColors.line),
                  borderRadius: NkRadius.forInput,
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: NkColors.fgHint),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'La pantalla se actualizará automáticamente cuando el creador tome una decisión.',
                        style: TextStyle(
                          fontSize: 13,
                          color: NkColors.fgHint,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () async {
                  await SessionCacheService.clearSession();
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthFinalPage()),
                      (route) => false,
                    );
                  }
                },
                child: const Text(
                  'Cerrar sesión',
                  style: TextStyle(color: NkColors.fgHint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
