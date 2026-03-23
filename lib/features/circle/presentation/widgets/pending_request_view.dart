import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingRequestView extends StatefulWidget {
  final String pendingCircleId;

  const PendingRequestView({super.key, required this.pendingCircleId});

  @override
  State<PendingRequestView> createState() => _PendingRequestViewState();
}

class _PendingRequestViewState extends State<PendingRequestView> {
  String? _circleName;

  @override
  void initState() {
    super.initState();
    _loadCircleName();
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
      backgroundColor: Colors.black,
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
                color: Color(0xFF1CE4B3),
              ),
              const SizedBox(height: 32),
              const Text(
                'Solicitud enviada',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                    color: Color(0xFF1CE4B3),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Tu solicitud fue enviada. Esperando que el creador del círculo la apruebe.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: Colors.white38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'La pantalla se actualizará automáticamente cuando el creador tome una decisión.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
