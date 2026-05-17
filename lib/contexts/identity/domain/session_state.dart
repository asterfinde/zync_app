sealed class SessionState {
  const SessionState();
  bool get isAuthenticated => this is Authenticated;
}

final class Anonymous extends SessionState {
  const Anonymous();
}

final class Authenticated extends SessionState {
  final String uid;
  final String email;
  const Authenticated({required this.uid, required this.email});
}
