import 'package:flutter/foundation.dart';

@immutable
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        description: json['description'] as String?,
        ownerId: json['owner_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

enum MembershipRole {
  owner,
  admin,
  member;

  String toJson() => switch (this) {
        MembershipRole.owner => 'OWNER',
        MembershipRole.admin => 'ADMIN',
        MembershipRole.member => 'MEMBER',
      };

  factory MembershipRole.fromJson(String value) => switch (value.toUpperCase()) {
        'OWNER' => MembershipRole.owner,
        'ADMIN' => MembershipRole.admin,
        'MEMBER' => MembershipRole.member,
        _ => throw FormatException('Unknown membership role: $value'),
      };
}

@immutable
class OrganizationMember {
  const OrganizationMember({
    required this.id,
    required this.organizationId,
    required this.userId,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String organizationId;
  final String userId;
  final MembershipRole role;
  final DateTime createdAt;

  factory OrganizationMember.fromJson(Map<String, dynamic> json) =>
      OrganizationMember(
        id: json['id'] as String,
        organizationId: json['organization_id'] as String,
        userId: json['user_id'] as String,
        role: MembershipRole.fromJson(json['role'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
