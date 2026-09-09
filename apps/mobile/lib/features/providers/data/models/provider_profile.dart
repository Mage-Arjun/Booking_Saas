import 'package:flutter/foundation.dart';

@immutable
class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.userId,
    required this.organizationId,
    required this.displayName,
    required this.bio,
    required this.category,
    required this.location,
    required this.timezone,
    required this.isActive,
    required this.bookingBufferBeforeMinutes,
    required this.bookingBufferAfterMinutes,
    required this.minimumNoticeHours,
    required this.maxAdvanceDays,
    required this.cancellationNoticeHours,
    required this.allowSameDayCancellation,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String organizationId;
  final String displayName;
  final String? bio;
  final String? category;
  final Map<String, dynamic>? location;
  final String timezone;
  final bool isActive;
  final int bookingBufferBeforeMinutes;
  final int bookingBufferAfterMinutes;
  final int minimumNoticeHours;
  final int maxAdvanceDays;
  final int cancellationNoticeHours;
  final bool allowSameDayCancellation;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProviderProfile.fromJson(Map<String, dynamic> json) => ProviderProfile(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        organizationId: json['organization_id'] as String,
        displayName: json['display_name'] as String,
        bio: json['bio'] as String?,
        category: json['category'] as String?,
        location: (json['location'] as Map?)?.cast<String, dynamic>(),
        timezone: json['timezone'] as String,
        isActive: json['is_active'] as bool,
        bookingBufferBeforeMinutes:
            json['booking_buffer_before_minutes'] as int,
        bookingBufferAfterMinutes:
            json['booking_buffer_after_minutes'] as int,
        minimumNoticeHours: json['minimum_notice_hours'] as int,
        maxAdvanceDays: json['max_advance_days'] as int,
        cancellationNoticeHours: json['cancellation_notice_hours'] as int,
        allowSameDayCancellation: json['allow_same_day_cancellation'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

@immutable
class ProviderListItem {
  const ProviderListItem({
    required this.id,
    required this.displayName,
    required this.category,
    required this.location,
    required this.timezone,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final String? category;
  final Map<String, dynamic>? location;
  final String timezone;
  final DateTime createdAt;

  factory ProviderListItem.fromJson(Map<String, dynamic> json) =>
      ProviderListItem(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        category: json['category'] as String?,
        location: (json['location'] as Map?)?.cast<String, dynamic>(),
        timezone: json['timezone'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
