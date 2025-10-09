// lib/features/circle/providers/simple_circle_provider.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:zync_app/features/circle/services/firebase_circle_service.dart';

enum CircleStatus { initial, loading, loaded, error }

class SimpleCircleProvider extends ChangeNotifier {
  final FirebaseCircleService _service = FirebaseCircleService();
  
  // Estado
  CircleStatus _status = CircleStatus.initial;
  Circle? _circle;
  String? _error;
  StreamSubscription? _circleSubscription;

  // Getters
  CircleStatus get status => _status;
  Circle? get circle => _circle;
  String? get error => _error;
  bool get isLoading => _status == CircleStatus.loading;
  bool get hasCircle => _circle != null;

  SimpleCircleProvider() {
    _initializeCircleStream();
  }

  /// Inicializa el stream para escuchar cambios en el círculo del usuario
  void _initializeCircleStream() {
    log('[SimpleCircleProvider] Inicializando stream del círculo');
    
    _circleSubscription?.cancel();
    _circleSubscription = _service.getUserCircleStream().listen(
      (circle) {
        log('[SimpleCircleProvider] Stream actualizado: ${circle?.name ?? 'null'}');
        _circle = circle;
        _status = circle != null ? CircleStatus.loaded : CircleStatus.initial;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        log('[SimpleCircleProvider] Stream error: $error');
        _error = error.toString();
        _status = CircleStatus.error;
        notifyListeners();
      },
    );
  }

  /// Crea un nuevo círculo
  Future<void> createCircle(String name) async {
    if (name.trim().isEmpty) {
      _error = 'El nombre del círculo no puede estar vacío';
      _status = CircleStatus.error;
      notifyListeners();
      return;
    }

    log('[SimpleCircleProvider] Creando círculo: $name');
    
    _status = CircleStatus.loading;
    _error = null;
    notifyListeners();

    try {
      await _service.createCircle(name.trim());
      log('[SimpleCircleProvider] ✅ Círculo creado exitosamente');
      // El stream se encargará de actualizar el estado
    } catch (e) {
      log('[SimpleCircleProvider] Error creando círculo: $e');
      _error = e.toString();
      _status = CircleStatus.error;
      notifyListeners();
    }
  }

  /// Une al usuario a un círculo existente
  Future<void> joinCircle(String invitationCode) async {
    if (invitationCode.trim().isEmpty) {
      _error = 'El código de invitación no puede estar vacío';
      _status = CircleStatus.error;
      notifyListeners();
      return;
    }

    log('[SimpleCircleProvider] Uniéndose al círculo: $invitationCode');
    
    _status = CircleStatus.loading;
    _error = null;
    notifyListeners();

    try {
      await _service.joinCircle(invitationCode.trim());
      log('[SimpleCircleProvider] ✅ Unido al círculo exitosamente');
      // El stream se encargará de actualizar el estado
    } catch (e) {
      log('[SimpleCircleProvider] Error uniéndose al círculo: $e');
      _error = e.toString();
      _status = CircleStatus.error;
      notifyListeners();
    }
  }

  /// Refresca manualmente el círculo del usuario
  Future<void> refreshCircle() async {
    log('[SimpleCircleProvider] Refrescando círculo...');
    
    _status = CircleStatus.loading;
    notifyListeners();

    try {
      final circle = await _service.getUserCircle();
      _circle = circle;
      _status = circle != null ? CircleStatus.loaded : CircleStatus.initial;
      _error = null;
      log('[SimpleCircleProvider] ✅ Círculo refrescado: ${circle?.name ?? 'null'}');
    } catch (e) {
      log('[SimpleCircleProvider] Error refrescando círculo: $e');
      _error = e.toString();
      _status = CircleStatus.error;
    }
    
    notifyListeners();
  }

  /// Limpia el error actual
  void clearError() {
    _error = null;
    if (_status == CircleStatus.error) {
      _status = _circle != null ? CircleStatus.loaded : CircleStatus.initial;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _circleSubscription?.cancel();
    super.dispose();
  }
}