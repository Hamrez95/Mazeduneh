import 'dart:convert';

import 'admin_browser_location.dart';
import 'auth_session.dart';

const _draftLifetime = Duration(days: 7);
const _sensitiveKeyParts = [
  'password',
  'token',
  'mobile',
  'phone',
  'email',
  'customer',
  'address',
  'city',
  'postal',
  'payment',
  'card',
  'recipient',
  'buyer',
];

String _fingerprint(String value) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(value)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _draftKey(String form, String recordId) {
  final session = OwnerSession.instance;
  final identity =
      '${session.storeId}\u0000${session.email?.toLowerCase() ?? ''}';
  return 'mazeduneh.admin.draft.v1.${_fingerprint(identity)}.'
      '${_fingerprint(form)}.${_fingerprint(recordId)}';
}

bool _isSensitiveKey(String key) {
  final normalized = key.toLowerCase();
  return _sensitiveKeyParts.any(normalized.contains);
}

Object? _safeValue(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key is String && !_isSensitiveKey(entry.key as String))
          entry.key: _safeValue(entry.value),
    };
  }
  if (value is List) return value.map(_safeValue).toList();
  if (value is String || value is num || value is bool || value == null) {
    return value;
  }
  return null;
}

/// Returns only non-sensitive, JSON-safe values suitable for a local draft.
Map<String, dynamic> sanitizeAdminFormDraft(Map<String, dynamic> values) {
  final safe = _safeValue(values);
  if (safe is! Map) return {};
  return {
    for (final entry in safe.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

Map<String, dynamic>? readAdminFormDraft(String form, String recordId) {
  final raw = readAdminBrowserValue(_draftKey(form, recordId));
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    final updated = DateTime.tryParse(decoded['updatedAt'] as String? ?? '');
    final values = decoded['values'];
    if (updated == null ||
        DateTime.now().toUtc().difference(updated.toUtc()) > _draftLifetime ||
        values is! Map<String, dynamic>) {
      removeAdminBrowserValue(_draftKey(form, recordId));
      return null;
    }
    return sanitizeAdminFormDraft(values);
  } catch (_) {
    removeAdminBrowserValue(_draftKey(form, recordId));
    return null;
  }
}

void writeAdminFormDraft(
  String form,
  String recordId,
  Map<String, dynamic> values,
) {
  final safe = sanitizeAdminFormDraft(values);
  if (safe.isEmpty) return;
  writeAdminBrowserValue(
    _draftKey(form, recordId),
    jsonEncode({
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'values': safe,
    }),
  );
}

void clearAdminFormDraft(String form, String recordId) =>
    removeAdminBrowserValue(_draftKey(form, recordId));
