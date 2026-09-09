import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/pagination.dart';
import '../../providers/data/models/provider_profile.dart';
import 'models/organization.dart';

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository(dio: ref.watch(apiClientProvider));
});

/// Data-access boundary for organization management.
///
/// The backend already enforces membership and owner/admin permissions. The
/// client therefore focuses on presenting those operations cleanly while
/// never attempting to replace backend authorization rules.
class OrganizationRepository {
  const OrganizationRepository({required this.dio});

  final Dio dio;

  Future<Organization> create({
    required String name,
    required String slug,
    String? description,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        ApiEndpoints.organizations,
        data: {
          'name': name,
          'slug': slug,
          'description': description,
        },
      );
      return Organization.fromJson(response.data!);
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Organization> get(String organizationId) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        ApiEndpoints.organization(organizationId),
      );
      return Organization.fromJson(response.data!);
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Organization> update(
    String organizationId, {
    String? name,
    String? description,
  }) async {
    try {
      final response = await dio.patch<Map<String, dynamic>>(
        ApiEndpoints.organizationUpdate(organizationId),
        data: {
          'name': ?name,
          'description': ?description,
        },
      );
      return Organization.fromJson(response.data!);
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<PaginatedResponse<OrganizationMember>> members(
    String organizationId, {
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        ApiEndpoints.organizationMembers(organizationId),
        queryParameters: {'skip': skip, 'limit': limit},
      );
      return PaginatedResponse.fromJson(
        response.data!,
        OrganizationMember.fromJson,
      );
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<OrganizationMember> addMember(
    String organizationId, {
    required String userId,
    MembershipRole role = MembershipRole.member,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        ApiEndpoints.addOrganizationMember(organizationId),
        data: {'user_id': userId, 'role': role.toJson()},
      );
      return OrganizationMember.fromJson(response.data!);
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<void> removeMember(String organizationId, String userId) async {
    try {
      await dio.delete<void>(
        ApiEndpoints.removeOrganizationMember(organizationId, userId),
      );
    } catch (error) {
      throw mapDioException(error);
    }
  }

  Future<PaginatedResponse<ProviderListItem>> providers(
    String organizationId, {
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        ApiEndpoints.organizationProviders(organizationId),
        queryParameters: {'skip': skip, 'limit': limit},
      );
      return PaginatedResponse.fromJson(
        response.data!,
        ProviderListItem.fromJson,
      );
    } catch (error) {
      throw mapDioException(error);
    }
  }
}
