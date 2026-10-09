import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/admin_users_api.dart';
import 'package:mazeduneh_admin/auth_session.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'users-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });
  tearDown(OwnerSession.instance.clear);

  test('parses users and roles and sends authenticated mutations', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/roles')) {
        return http.Response(utf8Body(jsonEncode([
          {'role': 'WarehouseOperator', 'permissions': ['inventory.read', 'inventory.write'], 'titleFa': 'اپراتور انبار'},
        ])), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (request.method == 'POST') {
        return http.Response(utf8Body(jsonEncode({'user': userJson(isActive: true), 'invitationToken': 'invite-once', 'expiresAt': '2026-10-04T12:00:00Z'})), 201, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (request.method == 'PATCH') {
        if (request.url.path.endsWith('/permissions')) {
          return http.Response(utf8Body(jsonEncode(userJson(permissions: ['inventory.read']))), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response(utf8Body(jsonEncode(userJson(isActive: false, deactivatedAt: '2026-10-03T12:00:00Z'))), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response(utf8Body(jsonEncode([userJson()])), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final api = AdminUsersApiClient(baseUrl: 'https://api.test', client: client);

    final users = await api.fetchUsers();
    final roles = await api.fetchRoles();
    final selectedPermissions = ['inventory.read', 'customers.pii.read'];
    final created = await api.createUser(email: 'warehouse@example.com', displayName: 'اپراتور انبار', role: 'WarehouseOperator', permissions: selectedPermissions);
    final updated = await api.setPermissions(created.user.id, ['inventory.read']);
    final disabled = await api.setStatus(created.user.id, false);

    expect(users.single.displayName, 'اپراتور انبار');
    expect(roles.single.titleFa, 'اپراتور انبار');
    expect(created.user.isActive, isTrue);
    expect(updated.permissions, ['inventory.read']);
    expect(disabled.isActive, isFalse);
    expect(requests.where((request) => request.headers['authorization'] == 'Bearer users-token'), hasLength(5));
    expect(jsonDecode(requests[2].body)['role'], 'WarehouseOperator');
    expect(jsonDecode(requests[2].body)['permissions'], selectedPermissions);
    expect(requests[3].url.path, '/api/v1/admin/users/user-1/permissions');
    expect(jsonDecode(requests[3].body)['permissions'], ['inventory.read']);
    expect(jsonDecode(requests[4].body)['isActive'], isFalse);
  });

  test('clears the session when the server returns unauthorized', () async {
    final api = AdminUsersApiClient(baseUrl: 'https://api.test', client: MockClient((_) async => http.Response.bytes(utf8.encode('باید دوباره وارد شوید'), 401, headers: {'content-type': 'text/plain; charset=utf-8'})));
    await expectLater(api.fetchUsers(), throwsA(isA<AdminUsersApiException>()));
    expect(OwnerSession.instance.isAuthenticated, isFalse);
  });
}

String utf8Body(String value) => value;

Map<String, dynamic> userJson({bool isActive = true, String? deactivatedAt, List<String>? permissions}) => {
      'id': 'user-1',
      'email': 'warehouse@example.com',
      'displayName': 'اپراتور انبار',
      'role': 'WarehouseOperator',
      'isActive': isActive,
      'permissions': permissions ?? ['inventory.read', 'inventory.write'],
      'createdAt': '2026-10-03T12:00:00Z',
      'deactivatedAt': deactivatedAt,
    };

\n