import 'dart:async';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nunakin_app/contexts/identity/application/ports/identity_repository.dart';
import 'package:nunakin_app/contexts/identity/domain/session_state.dart';

class FirebaseIdentityRepository implements IdentityRepository {
  final FirebaseAuth _auth;
  final _controller = StreamController<SessionState>.broadcast();
  StreamSubscription<User?>? _sub;
  SessionState _current = const Anonymous();

  FirebaseIdentityRepository(this._auth) {
    _sub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    _current = _mapUser(user);
    _controller.add(_current);
    log('[IdentityRepository] session → ${_current.runtimeType}');
  }

  SessionState _mapUser(User? user) => user != null
      ? Authenticated(uid: user.uid, email: user.email ?? '')
      : const Anonymous();

  @override
  Stream<SessionState> get session => _controller.stream;

  @override
  SessionState get current => _current;

  @override
  Future<void> signOut() => _auth.signOut();

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
