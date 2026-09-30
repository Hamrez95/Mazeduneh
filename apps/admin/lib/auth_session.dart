import 'dart:async';

class OwnerSession {
  OwnerSession._();

  static final OwnerSession instance = OwnerSession._();

  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  String? _accessToken;
  DateTime? _expiresAt;
  String? _email;
  String? _role;
  List<String> _permissions = const [];

  Stream<bool> get changes => _changes.stream;
  String? get email => _email;
  String? get role => _role;
  List<String> get permissions => List.unmodifiable(_permissions);
  bool can(String permission) => _role == 'Owner' || _permissions.contains(permission);

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

  void establish({
    required String accessToken,
    required DateTime expiresAt,
    required String email,
    String role = 'Owner',
    List<String> permissions = const [],
  }) {
    _accessToken = accessToken;
    _expiresAt = expiresAt.toUtc();
    _email = email;
    _role = role;
    _permissions = List.unmodifiable(permissions.where((item) => item.trim().isNotEmpty));
    _changes.add(true);
  }

  void updateIdentity({required String role, required List<String> permissions}) {
    _role = role;
    _permissions = List.unmodifiable(permissions.where((item) => item.trim().isNotEmpty));
    _changes.add(true);
  }

  void clear() {
    final hadSession = _accessToken != null || _expiresAt != null || _email != null || _role != null || _permissions.isNotEmpty;
    _accessToken = null;
    _expiresAt = null;
    _email = null;
    _role = null;
    _permissions = const [];
    if (hadSession) _changes.add(false);
  }
}
