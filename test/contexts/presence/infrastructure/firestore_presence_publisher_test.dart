// TODO(sem2-day4): estos tests requieren `fake_cloud_firestore` en dev_dependencies.
// Agregar a pubspec.yaml antes de activar:
//
//   dev_dependencies:
//     fake_cloud_firestore: ^3.0.4   # verificar última versión compatible
//
// Una vez agregado, descomentar los tests y remover el @Skip.
//
// Escenarios a cubrir:
//   1. Normal state → batch escribe en circles/{id}/memberStatus/{uid}
//      y en circles/{id}/statusEvents/ sin campo 'coordinates'.
//   2. SOSActive state → batch incluye 'coordinates' en memberStatus y statusEvents.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestorePresencePublisher', () {
    test(
      'pendiente: requiere fake_cloud_firestore en dev_dependencies',
      () {},
      skip: 'Agregar fake_cloud_firestore a pubspec.yaml para activar estos tests',
    );
  });
}
