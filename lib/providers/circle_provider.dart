// lib/providers/circle_provider.dart

import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:zync_app/services/circle_service.dart';

enum CircleStatus { initial, loading, loaded, error }

class CircleProvider extends ChangeNotifier {
  final CircleService _service = CircleService();
  
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

  CircleProvider() {
    _initializeCircleStream();
  }

  /// Inicializa el stream para escuchar cambios en el círculo del usuario
  void _initializeCircleStream() {
    log('[CircleProvider] Inicializando stream del círculo');
    
    _circleSubscription?.cancel();
    _circleSubscription = _service.getUserCircleStream().listen(
      (circle) {
        log('[CircleProvider] Stream actualizado: ${circle?.name ?? 'null'}');
        _circle = circle;
        _status = circle != null ? CircleStatus.loaded : CircleStatus.initial;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        log('[CircleProvider] Stream error: $error');
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

    log('[CircleProvider] Creando círculo: $name');
    
    _status = CircleStatus.loading;
    _error = null;
    notifyListeners();

    try {
      await _service.createCircle(name.trim());
      log('[CircleProvider] ✅ Círculo creado exitosamente');
      // El stream se encargará de actualizar el estado
    } catch (e) {
      log('[CircleProvider] Error creando círculo: $e');
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

    log('[CircleProvider] Uniéndose al círculo: $invitationCode');
    
    _status = CircleStatus.loading;
    _error = null;
    notifyListeners();

    try {
      await _service.joinCircle(invitationCode.trim());
      log('[CircleProvider] ✅ Unido al círculo exitosamente');
      // El stream se encargará de actualizar el estado
    } catch (e) {
      log('[CircleProvider] Error uniéndose al círculo: $e');
      _error = e.toString();
      _status = CircleStatus.error;
      notifyListeners();
    }
  }

  /// Refresca manualmente el círculo del usuario
  Future<void> refreshCircle() async {
    log('[CircleProvider] Refrescando círculo...');
    
    _status = CircleStatus.loading;
    notifyListeners();

    try {
      final circle = await _service.getUserCircle();
      _circle = circle;
      _status = circle != null ? CircleStatus.loaded : CircleStatus.initial;
      _error = null;
      log('[CircleProvider] ✅ Círculo refrescado: ${circle?.name ?? 'null'}');
    } catch (e) {
      log('[CircleProvider] Error refrescando círculo: $e');
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
