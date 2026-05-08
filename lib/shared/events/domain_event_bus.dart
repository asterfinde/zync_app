import 'dart:async';
import 'package:nunakin_app/shared/events/domain_event.dart';

/// Bus de eventos de dominio. Singleton registrado en DI (platform_module).
/// Nunca como static global — inyectar siempre desde GetIt.
class DomainEventBus {
  final _controller = StreamController<DomainEvent>.broadcast();

  Stream<DomainEvent> get events => _controller.stream;

  /// Stream filtrado por tipo de evento.
  Stream<T> on<T extends DomainEvent>() =>
      _controller.stream.where((e) => e is T).cast<T>();

  void publish(DomainEvent event) => _controller.add(event);

  void dispose() => _controller.close();
}
