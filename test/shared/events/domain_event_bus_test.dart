import 'package:flutter_test/flutter_test.dart';
import 'package:nunakin_app/shared/events/domain_event.dart';
import 'package:nunakin_app/shared/events/domain_event_bus.dart';

void main() {
  group('DomainEventBus', () {
    late DomainEventBus bus;

    setUp(() => bus = DomainEventBus());
    tearDown(() => bus.dispose());

    test('publish entrega el evento al suscriptor', () async {
      final received = <DomainEvent>[];
      bus.events.listen(received.add);

      bus.publish(const SessionEnded(userId: 'u1'));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.first, isA<SessionEnded>());
    });

    test('on<T> filtra por tipo — ZoneEntered no llega a listener de SessionEnded', () async {
      final sessionEvents = <SessionEnded>[];
      bus.on<SessionEnded>().listen(sessionEvents.add);

      bus.publish(const ZoneEntered(zoneId: 'z1', userId: 'u1'));
      bus.publish(const SessionEnded(userId: 'u2'));
      await Future<void>.delayed(Duration.zero);

      expect(sessionEvents, hasLength(1));
      expect(sessionEvents.first.userId, 'u2');
    });

    test('múltiples suscriptores reciben el mismo evento', () async {
      final a = <DomainEvent>[];
      final b = <DomainEvent>[];
      bus.events.listen(a.add);
      bus.events.listen(b.add);

      bus.publish(const ZoneExited(zoneId: 'z2', userId: 'u3'));
      await Future<void>.delayed(Duration.zero);

      expect(a, hasLength(1));
      expect(b, hasLength(1));
    });

    test('dispose cierra el stream sin excepción', () {
      expect(() => bus.dispose(), returnsNormally);
    });
  });
}
