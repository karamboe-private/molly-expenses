import 'package:cloud_firestore/cloud_firestore.dart';

class Account {
  final String id;
  final String beneficiaryName;
  final String ownerId;
  final DateTime createdAt;

  Account({
    required this.id,
    required this.beneficiaryName,
    required this.ownerId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'beneficiaryName': beneficiaryName,
      'ownerId': ownerId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Account.fromMap(String id, Map<String, dynamic> map) {
    return Account(
      id: id,
      beneficiaryName: map['beneficiaryName'] ?? 'Molly',
      ownerId: map['ownerId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class AccountMember {
  final String userId;
  final String role;
  final String email;
  final String displayName;
  final DateTime invitedAt;

  AccountMember({
    required this.userId,
    required this.role,
    required this.email,
    required this.displayName,
    required this.invitedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'email': email,
      'displayName': displayName,
      'invitedAt': Timestamp.fromDate(invitedAt),
    };
  }

  factory AccountMember.fromMap(String userId, Map<String, dynamic> map) {
    return AccountMember(
      userId: userId,
      role: map['role'] ?? 'assistant',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      invitedAt: (map['invitedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class InviteCode {
  final String code;
  final String accountId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool used;

  InviteCode({
    required this.code,
    required this.accountId,
    required this.createdBy,
    required this.createdAt,
    this.expiresAt,
    this.used = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'accountId': accountId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'used': used,
    };
  }

  factory InviteCode.fromMap(String code, Map<String, dynamic> map) {
    return InviteCode(
      code: code,
      accountId: map['accountId'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
      used: map['used'] ?? false,
    );
  }

  bool get isValid {
    if (used) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }
}
