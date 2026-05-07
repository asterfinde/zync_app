import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nunakin_app/platform/persistence/shared_prefs_kv_store.dart';

void main() {
  late SharedPrefsKvStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = SharedPrefsKvStore(prefs);
  });

  group('getString / setString', () {
    test('retorna null si la clave no existe', () async {
      expect(await store.getString('missing'), isNull);
    });

    test('persiste y recupera el valor', () async {
      await store.setString('key', 'value');
      expect(await store.getString('key'), 'value');
    });
  });

  group('getBool / setBool', () {
    test('retorna null si la clave no existe', () async {
      expect(await store.getBool('missing'), isNull);
    });

    test('persiste true', () async {
      await store.setBool('flag', true);
      expect(await store.getBool('flag'), isTrue);
    });

    test('persiste false', () async {
      await store.setBool('flag', false);
      expect(await store.getBool('flag'), isFalse);
    });
  });

  group('getInt / setInt', () {
    test('retorna null si la clave no existe', () async {
      expect(await store.getInt('missing'), isNull);
    });

    test('persiste el valor entero', () async {
      await store.setInt('count', 42);
      expect(await store.getInt('count'), 42);
    });
  });

  group('remove', () {
    test('elimina la clave existente', () async {
      await store.setString('to_remove', 'x');
      await store.remove('to_remove');
      expect(await store.getString('to_remove'), isNull);
    });

    test('no lanza si la clave no existe', () async {
      expect(() => store.remove('ghost'), returnsNormally);
    });
  });

  group('containsKey', () {
    test('retorna false si la clave no existe', () async {
      expect(await store.containsKey('missing'), isFalse);
    });

    test('retorna true después de setString', () async {
      await store.setString('exists', 'y');
      expect(await store.containsKey('exists'), isTrue);
    });

    test('retorna false después de remove', () async {
      await store.setString('temp', 'z');
      await store.remove('temp');
      expect(await store.containsKey('temp'), isFalse);
    });
  });
}
