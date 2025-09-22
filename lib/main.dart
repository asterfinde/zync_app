// lib/main.dart

import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zync_app/core/di/injection_container.dart' as di;
import 'package:zync_app/firebase_options.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_provider.dart';
import 'package:zync_app/features/auth/presentation/provider/auth_state.dart';
import 'package:zync_app/features/auth/presentation/pages/sign_in_page.dart';
import 'package:zync_app/features/circle/presentation/pages/home_page.dart';
import 'package:zync_app/features/circle/services/quick_status_service.dart';
// import 'package:zync_app/features/circle/presentation/widgets/quick_status_send_dialog.dart';
import 'package:zync_app/features/circle/presentation/pages/quick_status_selector_page.dart';
import 'package:zync_app/core/widgets/emoji_modal.dart';
// import 'package:zync_app/features/circle/domain/entities/user_status.dart';
// import 'package:zync_app/features/circle/presentation/provider/circle_provider.dart';
// import 'package:zync_app/features/circle/presentation/provider/circle_state.dart';
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

// SINGLETON PARA EVITAR CONFIGURAR METHODCHANNEL MÚLTIPLES VECES
bool _methodChannelConfigured = false;

// NUEVA FUNCIÓN PARA SER LLAMADA DESDE EL TEST
Future<void> initializeApp() async {
  log('[main.dart] initializeApp() called');
  // MethodChannel YA configurado en main()
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      log('Firebase ya estaba inicializado: $e');
    } else {
      rethrow;
    }
  }
  await di.init();
  QuickStatusService.initialize();
  log("--- App Initialization Complete ---");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀🚀🚀 [FLUTTER] Iniciando app');
  
  // CONFIGURAR METHODCHANNEL INMEDIATAMENTE AQUÍ
  _setupMethodChannelEarly();
  
  await initializeApp();
  runApp(ProviderScope(child: MyApp()));
}

void _setupMethodChannelEarly() {
  if (_methodChannelConfigured) {
    print('🔥🔥🔥 [FLUTTER] MethodChannel YA configurado, saltando...');
    return;
  }
  
  final MethodChannel channel = MethodChannel('zync/notification');
  final MethodChannel emojiChannel = MethodChannel('mini_emoji/notification');
  print('🔥🔥🔥 [FLUTTER] MethodChannel configurado TEMPRANO en main()');
  _methodChannelConfigured = true;
  
  // PRUEBA INMEDIATA PARA VER SI EL HANDLER FUNCIONA
  Future.delayed(Duration(seconds: 3), () {
    print('🔥🔥🔥 [FLUTTER] Enviando TEST call desde Flutter...');
    channel.invokeMethod('showQuickStatusModal', {});
  });
  
  // Handler para el canal original de ZYNC
  channel.setMethodCallHandler((call) async {
    print('🔥🔥🔥 [FLUTTER] MethodChannel call recibido: ${call.method}');
    print('🔥🔥🔥 [FLUTTER] Arguments: ${call.arguments}');
    
    if (call.method == 'showQuickStatusModal') {
      print('🔥🔥🔥 [FLUTTER] ¡showQuickStatusModal llamado desde Android!');
      
      // Usar schedulerBinding para asegurar que el widget tree esté listo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = rootNavigatorKey.currentContext;
        if (context != null) {
          print('🔥🔥🔥 [FLUTTER] Context encontrado, navegando a QuickStatusSelectorPage');
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const QuickStatusSelectorPage(),
              fullscreenDialog: true,
            ),
          );
        } else {
          print('🔥🔥🔥 [FLUTTER] ERROR: Context es null, no se puede navegar');
        }
      });
    }
  });
  
  // Handler para el canal del mini_emoji_app
  emojiChannel.setMethodCallHandler((call) async {
    print('🎯 [EMOJI] MethodChannel call recibido: ${call.method}');
    
    if (call.method == 'showEmojiModal') {
      print('🎯 [EMOJI] ¡showEmojiModal llamado desde Android!');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = rootNavigatorKey.currentContext;
        if (context != null) {
          print('🎯 [EMOJI] Context encontrado, mostrando EmojiModal');
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const EmojiModal();
            },
          );
        } else {
          print('🎯 [EMOJI] ERROR: Context es null, no se puede mostrar modal');
        }
      });
    }
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Zync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: switch (authState) {
        Authenticated() => const HomePage(),
        Unauthenticated() || AuthError() => const SignInPage(),
        _ => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      },
    );
  }
}

// Funciones utilitarias para la funcionalidad del emoji modal
class EmojiNotificationService {
  static const MethodChannel _channel = MethodChannel('mini_emoji/notification');

  static Future<void> requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
      print('✅ Permisos de notificación solicitados');
    } on PlatformException catch (e) {
      print('❌ Error solicitando permisos: ${e.message}');
    }
  }

  static Future<void> showNotification() async {
    try {
      await _channel.invokeMethod('showNotification');
      print('✅ Notificación mostrada');
    } on PlatformException catch (e) {
      print('❌ Error mostrando notificación: ${e.message}');
    }
  }
}


