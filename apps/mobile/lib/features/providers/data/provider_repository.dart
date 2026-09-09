import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/pagination.dart';
import 'models/provider_profile.dart';

final providerRepositoryProvider = Provider<ProviderRepository>((ref) {
  return ProviderRepository(dio: ref.watch(apiClientProvider));
});

/// Data-access boundary for provider profiles and marketplace discovery.
class ProviderRepository {
  const ProviderRepository({required this.dio});

  final Dio dio;

  Future<PaginatedResponse<ProviderListItem>> list({
    int skip = 0,
    int limit = 20,
    String? category,
    String? organizationId,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        ApiEndpoints.providers,
        queryParameters: {
          'skip': skip,
          'limit': limit,
          if (category != null && category.isNotEmpty) 'category': category,
          'organization_id': ?organizationId,
        },
      );
      return PaginatedResponse.fromJson(
        response.data!,
        ProviderListItem.fromJson,
      );
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<ProviderProfile> get(String providerId) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        ApiEndpoints.provider(providerId),
      );
      return ProviderProfile.fromJson(response.data!);
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<ProviderProfile> create({
    required String organizationId,
    required String displayName,
    String? bio,
    String? category,
    Map<String, dynamic>? location,
    String timezone = 'UTC',
    int bookingBufferBeforeMinutes = 0,
    int bookingBufferAfterMinutes = 0,
    int minimumNoticeHours = 1,
    int maxAdvanceDays = 30,
    int cancellationNoticeHours = 24,
    bool allowSameDayCancellation = false,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        ApiEndpoints.providerProfile,
        data: {
          'organization_id': organizationId,
          'display_name': displayName,
          'bio': bio,
          'category': category,
          'location': location,
          'timezone': timezone,
          'booking_buffer_before_minutes': bookingBufferBeforeMinutes,
          'booking_buffer_after_minutes': bookingBufferAfterMinutes,
          'minimum_notice_hours': minimumNoticeHours,
          'max_advance_days': maxAdvanceDays,
          'cancellation_notice_hours': cancellationNoticeHours,
          'allow_same_day_cancellation': allowSameDayCancellation,
        },
      );
      return ProviderProfile.fromJson(response.data!);
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<ProviderProfile> update(
    String providerId, {
    String? displayName,
    String? bio,
    String? category,
    Map<String, dynamic>? location,
    String? timezone,
    bool? isActive,
    int? bookingBufferBeforeMinutes,
    int? bookingBufferAfterMinutes,
    int? minimumNoticeHours,
    int? maxAdvanceDays,
    int? cancellationNoticeHours,
    bool? allowSameDayCancellation,
  }) async {
    try {
      final response = await dio.patch<Map<String, dynamic>>(
        ApiEndpoints.providerUpdate(providerId),
        data: {
          'display_name': ?displayName,
          'bio': ?bio,
          'category': ?category,
          'location': ?location,
          'timezone': ?timezone,
          'is_active': ?isActive,
          'booking_buffer_before_minutes': ?bookingBufferBeforeMinutes,
          'booking_buffer_after_minutes': ?bookingBufferAfterMinutes,
          'minimum_notice_hours': ?minimumNoticeHours,
          'max_advance_days': ?maxAdvanceDays,
          'cancellation_notice_hours': ?cancellationNoticeHours,
          'allow_same_day_cancellation': ?allowSameDayCancellation,
        },
      );
      return ProviderProfile.fromJson(response.data!);
    } catch (error) {
      throw mapDioException(error);
    }
  }
}
