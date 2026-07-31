// Sem 9 Paso 8 Debug: Widget para probar cierre remoto de sesión (revoke_own_sessions)
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RemoteLogoutTestWidget extends StatefulWidget {
  const RemoteLogoutTestWidget({super.key});

  @override
  State<RemoteLogoutTestWidget> createState() => _RemoteLogoutTestWidgetState();
}

class _RemoteLogoutTestWidgetState extends State<RemoteLogoutTestWidget> {
  String _status = 'Sin probar';
  bool _isCalling = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('🔒 Sem9 P8 Debug: Logout Remoto'),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sesión actual',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user != null ? 'uid: ${user.uid}' : 'Sin usuario autenticado',
                      style: TextStyle(color: Colors.grey[300]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: (_isCalling || user == null) ? null : _testRevokeOwnSessions,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión remota (propio uid)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _testRevokeOwnSessions() async {
    setState(() {
      _isCalling = true;
      _status = 'Invocando revoke_own_sessions...';
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('revoke_own_sessions');
      final result = await callable.call();

      setState(() {
        _status = 'Éxito: ${result.data}';
      });
      HapticFeedback.mediumImpact();
      _showSuccess('revoke_own_sessions respondió OK: ${result.data}');
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _status = 'Error [${e.code}]: ${e.message}';
      });
      _showError('Error Cloud Function: ${e.code} — ${e.message}');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      _showError('Error inesperado: $e');
    } finally {
      setState(() {
        _isCalling = false;
      });
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
