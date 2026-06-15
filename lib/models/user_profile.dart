import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  String displayName;
  String? accountId;
  String? role;
  DateTime createdAt;
  DateTime updatedAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.accountId,
    this.role,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isOwner => role == 'owner';
  bool get isAssistant => role == 'assistant';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'accountId': accountId,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      accountId: map['accountId'],
      role: map['role'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? accountId,
    String? role,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      accountId: accountId ?? this.accountId,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
