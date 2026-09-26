import 'dart:async';

class OwnerSession {
  OwnerSession._();

  static final OwnerSession instance = OwnerSession._();

  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  String? _accessToken;
  DateTime? _expiresAt;
  String? _email;

  Stream<bool> get changes => _changes.stream;
  String? get email => _email;

  bool get isAuthenticated {
    final token = _accessToken;
    final expiry = _expiresAt;
    return token != null && expiry != null && expiry.isAfter(DateTime.now().toUtc());
  }

  String? get bearerToken {
    if (!isAuthenticated) {
      clear();
      return null;
    }
    return _accessToken;
  }

  void establish({required String accessToken, required DateTime expiresAt, required String email}) {
    _accessToken = accessToken;
    _expiresAt = expiresAt.toUtc();
    _email = email;
    _changes.add(true);
  }

  void clear() {
    final hadSession = _accessToken != null || _expiresAt != null || _email != null;
    _accessToken = null;
    _expiresAt = null;
    _email = null;
    if (hadSession) _changes.add(false);
  }
}
