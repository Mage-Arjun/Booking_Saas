import 'package:flutter/foundation.dart';

/// Strongly typed representation of an authenticated user.
@immutable
class User {
  const User({
    required this.id,
    required this.email,
    required this.role,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
  });

  final String id;
  final String email;
  final UserRole role;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      role: UserRole.fromJson(json['role'] as String),
      isActive: json['is_active'] as bool,
      isVerified: json['is_verified'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role.toJson(),
        'is_active': isActive,
        'is_verified': isVerified,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Roles returned by Mage's API.
///
/// IMPORTANT: the backend serializes these values as uppercase strings:
/// CLIENT, PROVIDER, ADMIN.
enum UserRole {
  client,
  provider,
  admin;

  String toJson() => switch (this) {
        UserRole.client => 'CLIENT',
        UserRole.provider => 'PROVIDER',
        UserRole.admin => 'ADMIN',
      };

  factory UserRole.fromJson(String value) => switch (value.toUpperCase()) {
        'CLIENT' => UserRole.client,
        'PROVIDER' => UserRole.provider,
        'ADMIN' => UserRole.admin,
        _ => throw FormatException('Unknown user role returned by API: $value'),
      };
}
