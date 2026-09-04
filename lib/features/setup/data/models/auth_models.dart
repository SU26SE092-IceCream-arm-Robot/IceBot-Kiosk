class AccountRoleScope {
  const AccountRoleScope({
    required this.roleCode,
    this.organizationId,
    this.storeId,
    this.kioskId,
  });

  final String roleCode;
  final String? organizationId;
  final String? storeId;
  final String? kioskId;

  factory AccountRoleScope.fromJson(Object? json) {
    final map = _asMap(json);
    return AccountRoleScope(
      roleCode: map['roleCode'] as String? ?? '',
      organizationId: _trimmed(map['organizationId']),
      storeId: _trimmed(map['storeId']),
      kioskId: _trimmed(map['kioskId']),
    );
  }

  Map<String, Object?> toJson() => {
    'roleCode': roleCode,
    'organizationId': organizationId,
    'storeId': storeId,
    'kioskId': kioskId,
  };
}

class AuthenticatedAccountResult {
  const AuthenticatedAccountResult({
    required this.accessToken,
    required this.refreshToken,
    required this.id,
    required this.userName,
    required this.fullName,
    required this.email,
    required this.roles,
  });

  final String accessToken;
  final String refreshToken;
  final String id;
  final String userName;
  final String fullName;
  final String email;
  final List<AccountRoleScope> roles;

  factory AuthenticatedAccountResult.fromJson(Object? json) {
    final map = _asMap(json);
    final rawRoles = map['roles'];
    return AuthenticatedAccountResult(
      accessToken: map['accessToken'] as String? ?? '',
      refreshToken: map['refreshToken'] as String? ?? '',
      id: map['id'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      roles: rawRoles is Iterable
          ? rawRoles.map(AccountRoleScope.fromJson).toList(growable: false)
          : const [],
    );
  }
}

class ManagedKiosk {
  const ManagedKiosk({
    required this.id,
    required this.storeId,
    this.code,
    this.name,
  });

  final String id;
  final String storeId;
  final String? code;
  final String? name;

  factory ManagedKiosk.fromJson(Object? json) {
    final map = _asMap(json);
    return ManagedKiosk(
      id: map['id'] as String? ?? '',
      storeId: map['storeId'] as String? ?? '',
      code: _trimmed(map['code']),
      name: _trimmed(map['name']),
    );
  }
}

class KioskAuthSession {
  const KioskAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accountId,
    required this.userName,
    required this.managerName,
    required this.organizationId,
    required this.storeId,
    required this.kioskId,
    this.kioskCode,
    this.kioskName,
  });

  final String accessToken;
  final String refreshToken;
  final String accountId;
  final String userName;
  final String managerName;
  final String? organizationId;
  final String? storeId;
  final String kioskId;
  final String? kioskCode;
  final String? kioskName;

  KioskAuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    String? accountId,
    String? userName,
    String? managerName,
    String? organizationId,
    String? storeId,
  }) {
    return KioskAuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accountId: accountId ?? this.accountId,
      userName: userName ?? this.userName,
      managerName: managerName ?? this.managerName,
      organizationId: organizationId ?? this.organizationId,
      storeId: storeId ?? this.storeId,
      kioskId: kioskId,
      kioskCode: kioskCode,
      kioskName: kioskName,
    );
  }

  factory KioskAuthSession.fromJson(Object? json) {
    final map = _asMap(json);
    return KioskAuthSession(
      accessToken: map['accessToken'] as String? ?? '',
      refreshToken: map['refreshToken'] as String? ?? '',
      accountId: map['accountId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      managerName: map['managerName'] as String? ?? '',
      organizationId: _trimmed(map['organizationId']),
      storeId: _trimmed(map['storeId']),
      kioskId: map['kioskId'] as String? ?? '',
      kioskCode: _trimmed(map['kioskCode']),
      kioskName: _trimmed(map['kioskName']),
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accountId': accountId,
    'userName': userName,
    'managerName': managerName,
    'organizationId': organizationId,
    'storeId': storeId,
    'kioskId': kioskId,
    'kioskCode': kioskCode,
    'kioskName': kioskName,
  };

  bool get isValid =>
      accessToken.trim().isNotEmpty &&
      refreshToken.trim().isNotEmpty &&
      accountId.trim().isNotEmpty &&
      kioskId.trim().isNotEmpty;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return Map<String, dynamic>.from(value);
}

String? _trimmed(Object? value) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? null : text;
}
