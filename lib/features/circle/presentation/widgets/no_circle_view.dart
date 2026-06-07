import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../contexts/identity/presentation/provider/auth_provider.dart';
import '../../../../contexts/identity/presentation/provider/auth_state.dart';
import '../../../../contexts/identity/presentation/pages/auth_final_page.dart';
import '../../../../core/services/session_cache_service.dart';
import '../../../../services/circle_service.dart';
import '../../../../app/theme/design_tokens.dart';
import 'create_circle_view.dart';
import 'join_circle_view.dart';

class NoCircleView extends ConsumerStatefulWidget {
  const NoCircleView({super.key});

  @override
  ConsumerState<NoCircleView> createState() => _NoCircleViewState();
}

class _NoCircleViewState extends ConsumerState<NoCircleView> {
  String _getCurrentUserNickname() {
    final authState = ref.watch(authProvider);
    if (authState is Authenticated) {
      return authState.user.nickname.isNotEmpty
          ? authState.user.nickname
          : authState.user.email.split('@')[0];
    }
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser?.displayName?.isNotEmpty == true) return fbUser!.displayName!;
    if (fbUser?.email?.isNotEmpty == true) return fbUser!.email!.split('@')[0];
    return '...';
  }

  void _navigateToCreateCircle() {
    // TODO: re-enable email verification gate after defining UX (see deuda técnica)
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CreateCircleView()),
    );
  }

  void _navigateToJoinCircle() {
    // TODO: re-enable email verification gate after defining UX (see deuda técnica)
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const JoinCircleView()),
    );
  }

  void _showAccountDialog(BuildContext context) {
    final authState = ref.read(authProvider);
    final fbUser = FirebaseAuth.instance.currentUser;

    // ════════════════════════════════════════════════════════════
    // [FIX] Dialog no aparecía si authProvider aún estaba en AuthLoading
    // Fecha: 2026-06-04
    // PROBLEMA: el guard `authState is! Authenticated` retornaba silenciosamente
    //   mientras el header ya mostraba el nickname real (vía Firebase fallback),
    //   dando la impresión de que la funcionalidad fue eliminada.
    // SOLUCIÓN: mismo patrón fallback que _getCurrentUserNickname — si Riverpod
    //   no tiene datos aún, usar FirebaseAuth directamente.
    // ════════════════════════════════════════════════════════════
    if (authState is! Authenticated && fbUser == null) return;

    final nickname = authState is Authenticated
        ? authState.user.nickname
        : (fbUser?.displayName?.isNotEmpty == true
            ? fbUser!.displayName!
            : fbUser?.email?.split('@')[0] ?? '');
    final email = authState is Authenticated
        ? authState.user.email
        : (fbUser?.email ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NkColors.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: NkRadius.forButton,
          side: BorderSide(color: NkColors.mintSoft(0.4), width: 1),
        ),
        title: const Text(
          'Mi Cuenta',
          style: TextStyle(color: NkColors.onDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nickname', style: TextStyle(color: NkColors.fgHint, fontSize: 12)),
            const SizedBox(height: 4),
            Text(nickname, style: const TextStyle(color: NkColors.onDark, fontSize: 16)),
            const SizedBox(height: 16),
            const Text('Email', style: TextStyle(color: NkColors.fgHint, fontSize: 12)),
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(color: NkColors.onDark, fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeleteAccountDialog(context);
            },
            child: const Text('Eliminar Cuenta', style: TextStyle(color: NkColors.danger)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar', style: TextStyle(color: NkColors.mint)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext parentContext) {
    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NkColors.surface2,
        shape: RoundedRectangleBorder(borderRadius: NkRadius.forButton),
        title: const Text('Eliminar Cuenta', style: TextStyle(color: NkColors.onDark)),
        content: const Text(
          '¿Estás seguro? Esta acción es irreversible. Se eliminarán tu cuenta y todos tus datos.',
          style: TextStyle(color: NkColors.fgSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar', style: TextStyle(color: NkColors.fgSub)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // FIX: Usar mounted del State y this.context en lugar del context del diálogo
              if (mounted) {
                _executeDeleteAccount(context);
              }
            },
            style: TextButton.styleFrom(foregroundColor: NkColors.danger),
            child: const Text('Eliminar Cuenta'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeleteAccount(BuildContext context) async {
    debugPrint('[NoCircleView] _executeDeleteAccount: INICIO');
    if (!context.mounted) {
      debugPrint('[NoCircleView] _executeDeleteAccount: context no montado, saliendo');
      return;
    }
    debugPrint('[NoCircleView] _executeDeleteAccount: Mostrando spinner...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(NkColors.mint),
        ),
      ),
    );

    try {
      debugPrint('[NoCircleView] _executeDeleteAccount: Limpiando SessionCache...');
      await SessionCacheService.clearSession();
      debugPrint('[NoCircleView] _executeDeleteAccount: Llamando CircleService().deleteAccount()...');
      await CircleService().deleteAccount();
      debugPrint('[NoCircleView] _executeDeleteAccount: deleteAccount() completado SIN excepción');

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthFinalPage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (e.code == 'requires-recent-login') {
        _showReauthDialog(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar la cuenta. Intenta de nuevo.', style: TextStyle(color: NkColors.onDark)),
            backgroundColor: NkColors.danger,
          ),
        );
      }
    } catch (e) {
      debugPrint('[NoCircleView] ❌ Error genérico en deleteAccount: $e (tipo: ${e.runtimeType})');
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        // FIX: Verificar si es FirebaseAuthException por runtimeType (en caso de que el catch tipado falle)
        if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
          debugPrint(
              '[NoCircleView] 🔄 Detectado requires-recent-login en catch genérico, mostrando diálogo de reauth');
          _showReauthDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al eliminar la cuenta. Intenta de nuevo.', style: TextStyle(color: NkColors.onDark)),
              backgroundColor: NkColors.danger,
            ),
          );
        }
      }
    }
  }

  void _showReauthDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    bool isPasswordObscured = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: NkColors.surface2,
          shape: RoundedRectangleBorder(borderRadius: NkRadius.forButton),
          title: const Text('Confirmar identidad', style: TextStyle(color: NkColors.onDark)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Por seguridad, ingresa tu contraseña para confirmar la eliminación.',
                style: TextStyle(color: NkColors.fgSub),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: isPasswordObscured,
                style: const TextStyle(color: NkColors.onDark),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle: const TextStyle(color: NkColors.fgSub),
                  filled: true,
                  fillColor: NkColors.surface3,
                  border: OutlineInputBorder(
                    borderRadius: NkRadius.forInput,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: NkRadius.forInput,
                    borderSide: const BorderSide(color: NkColors.mint, width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: NkColors.fgSub,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        isPasswordObscured = !isPasswordObscured;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar', style: TextStyle(color: NkColors.fgSub)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                if (!context.mounted) return;

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(NkColors.mint),
                    ),
                  ),
                );

                try {
                  final credential = EmailAuthProvider.credential(
                    email: email,
                    password: passwordController.text,
                  );
                  await FirebaseAuth.instance.currentUser!.reauthenticateWithCredential(credential);
                  await CircleService().deleteAccount();

                  if (context.mounted) {
                    // Cerrar el spinner antes de navegar
                    Navigator.of(context, rootNavigator: true).pop();

                    // Mostrar SnackBar de éxito
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('✅ Tu cuenta ha sido eliminada exitosamente', style: TextStyle(color: NkColors.onDark)),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );

                    // Navegar a login
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthFinalPage()),
                      (route) => false,
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  if (!context.mounted) return;
                  Navigator.of(context, rootNavigator: true).pop();
                  final msg = (e.code == 'wrong-password' || e.code == 'invalid-credential')
                      ? 'Contraseña incorrecta. Intenta de nuevo.'
                      : 'Error de autenticación. Intenta de nuevo.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg, style: const TextStyle(color: NkColors.onDark)),
                      backgroundColor: NkColors.danger,
                    ),
                  );
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error al eliminar la cuenta. Intenta de nuevo.',
                            style: TextStyle(color: NkColors.onDark)),
                        backgroundColor: NkColors.danger,
                      ),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: NkColors.danger),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NkColors.surface2,
        title: const Text(
          'Cerrar Sesión',
          style: TextStyle(color: NkColors.onDark),
        ),
        content: const Text(
          '¿Estás seguro de que quieres cerrar sesión?',
          style: TextStyle(color: NkColors.fgSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: NkColors.fgSub),
            ),
          ),
          TextButton(
            key: const Key('dialog_btn_logout_confirm'),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                print('🔴 [LOGOUT] Iniciando logout desde NoCircleView (sin círculo)...');

                // PASO 1: Limpiar cache PRIMERO (evita parpadeo de NoCircleView)
                print('🔴 [LOGOUT] Limpiando SessionCache...');
                await SessionCacheService.clearSession();

                // PASO 2: Cerrar sesión Firebase
                await FirebaseAuth.instance.signOut();
                print('🔴 [LOGOUT] Firebase signOut completado');

                // PASO 3: Navegar directo a login (sin SnackBar)
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthFinalPage()),
                    (route) => false,
                  );
                  print('✅ [LOGOUT] Navegación completada');
                }
              } catch (e) {
                print('❌ [LOGOUT] Error: $e');
                // Solo mostrar error si realmente falla
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al cerrar sesión: $e'),
                      backgroundColor: NkColors.danger,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: NkColors.danger),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // AppBar personalizado (igual que InCircleView)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
          color: NkColors.canvas,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NunaKin',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: NkColors.mint,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getCurrentUserNickname(),
                      style: NkTextStyle.body.copyWith(color: NkColors.fgSub),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showAccountDialog(context),
                icon: const Icon(Icons.account_circle_outlined, color: NkColors.onDark, size: 28),
                tooltip: 'Mi Cuenta',
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                key: const Key('btn_logout'),
                onPressed: () => _showLogoutDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NkColors.mintSoft(0.08),
                  foregroundColor: NkColors.mint,
                  side: BorderSide(color: NkColors.mintSoft(0.3), width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: NkRadius.forInput),
                  elevation: 0,
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),

        // Contenido principal
        Expanded(
          child: Container(
            color: NkColors.canvas,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // Ícono de estado vacío
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: NkColors.surfaceCard,
                        border: Border.all(color: NkColors.surfaceBorder),
                        borderRadius: NkRadius.forCard,
                      ),
                      child: const Icon(Icons.group_off_outlined, color: NkColors.mint, size: 28),
                    ),
                  ),
                  const SizedBox(height: NkSpacing.s),

                  // Mensaje principal
                  const Text(
                    "Aún no estás en un círculo",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: NkColors.onDark,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Mensaje de acción
                  const Text(
                    "¿Qué te gustaría hacer?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: NkColors.fgMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Tarjeta Crear Círculo
                  GestureDetector(
                    key: const Key('btn_navigate_create_circle'),
                    onTap: _navigateToCreateCircle,
                    child: Container(
                      padding: const EdgeInsets.all(NkSpacing.s5),
                      decoration: BoxDecoration(
                        color: NkColors.surfaceCard,
                        border: Border.all(color: NkColors.surfaceBorder),
                        borderRadius: NkRadius.forCard,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: NkColors.mintSoft(0.1),
                              borderRadius: NkRadius.forButton,
                            ),
                            child: const Icon(Icons.add, color: NkColors.mint),
                          ),
                          const SizedBox(width: NkSpacing.s),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Crear un Círculo',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: NkColors.onDark),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Inicia un nuevo círculo e invita a otros',
                                  style: TextStyle(fontSize: 12, color: NkColors.fgHint),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: NkSpacing.xs3),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: NkColors.surfaceBorder)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: NkSpacing.xs3),
                        child: Text(
                          'o',
                          style: TextStyle(
                            color: NkColors.fgHint,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: NkColors.surfaceBorder)),
                    ],
                  ),
                  const SizedBox(height: NkSpacing.xs3),

                  // Tarjeta Unirse a Círculo
                  GestureDetector(
                    key: const Key('btn_navigate_join_circle'),
                    onTap: _navigateToJoinCircle,
                    child: Container(
                      padding: const EdgeInsets.all(NkSpacing.s5),
                      decoration: BoxDecoration(
                        color: NkColors.surfaceCard,
                        border: Border.all(color: NkColors.surfaceBorder),
                        borderRadius: NkRadius.forCard,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: NkColors.surfaceCard,
                              borderRadius: NkRadius.forButton,
                            ),
                            child: const Icon(Icons.group_add, color: NkColors.fgSub),
                          ),
                          const SizedBox(width: NkSpacing.s),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Unirse a un Círculo',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: NkColors.onDark),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Únete con un código de invitación',
                                  style: TextStyle(fontSize: 12, color: NkColors.fgHint),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: NkSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
