import 'dart:async';

class OwnerSession {
  OwnerSession._();

  static final OwnerSession instance = OwnerSession._();

  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  String? _accessToken;
  int revision = 0;
  DateTime? _expiresAt;
  String? _email;
  String? _role;
  String _storeId = 'default';
  List<String> _permissions = const [];

  Stream<bool> get changes => _changes.stream;
  String? get email => _email;
  DateTime? get expiresAt => _expiresAt;
  String? get role => _role;
  String get storeId => _storeId;
  List<String> get permissions => List.unmodifiable(_permissions);
  bool can(String permission) =>
      _role == 'Owner' || _permissions.contains(permission);

  bool get isAuthenticated {
    final token = _accessToken;
    final expiry = _expiresAt;
    return token != null &&
        expiry != null &&
        expiry.isAfter(DateTime.now().toUtc());
  }

  String? get bearerToken {
    if (!isAuthenticated) {
      if (_accessToken != null) clear();
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
    String storeId = 'default',
  }) {
    revision++;
    _accessToken = accessToken;
    _expiresAt = expiresAt.toUtc();
    _email = email;
    _role = role;
    _storeId = storeId;
    _permissions = List.unmodifiable(
      permissions.where((item) => item.trim().isNotEmpty),
    );
    _changes.add(true);
  }

  void updateIdentity({
    required String role,
    required List<String> permissions,
    String? storeId,
  }) {
    _role = role;
    if (storeId != null && storeId.trim().isNotEmpty) _storeId = storeId;
    _permissions = List.unmodifiable(
      permissions.where((item) => item.trim().isNotEmpty),
    );
    _changes.add(true);
  }

  void clear() {
    revision++;
    final hadSession =
        _accessToken != null ||
        _expiresAt != null ||
        _email != null ||
        _role != null ||
        _permissions.isNotEmpty;
    _accessToken = null;
    _expiresAt = null;
    _email = null;
    _role = null;
    _storeId = 'default';
    _permissions = const [];
    if (hadSession) _changes.add(false);
  }
}
