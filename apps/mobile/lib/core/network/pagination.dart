/// Generic representation of Mage's paginated API response.
///
/// The backend consistently returns:
///
///     total, items, skip, limit
///
/// Keeping this contract generic allows organizations, members, and providers
/// to share the same pagination model without duplicating parsing logic.
class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.total,
    required this.items,
    required this.skip,
    required this.limit,
  });

  final int total;
  final List<T> items;
  final int skip;
  final int limit;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final rawItems = json['items'];
    return PaginatedResponse(
      total: json['total'] as int,
      items: (rawItems as List<dynamic>)
          .map((item) => itemFromJson(item as Map<String, dynamic>))
          .toList(),
      skip: json['skip'] as int,
      limit: json['limit'] as int,
    );
  }
}
