/// One page of a list endpoint's response: the rows plus an opaque cursor to
/// the next page, or null when this is the last page.
///
/// Every list repository returns this. The matching backend envelope is
/// `{ "data": [...], "nextCursor": "<id>" | null }` — see
/// `docs/superpowers/specs/2026-07-23-list-pagination-design.md`.
class PaginatedResponse<T> {
  const PaginatedResponse({required this.data, required this.nextCursor});

  final List<T> data;
  final String? nextCursor;

  /// [parse] converts one raw JSON element into a `T`.
  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? element) parse,
  ) {
    final raw = (json['data'] as List?) ?? const [];
    return PaginatedResponse(
      data: raw.map(parse).toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }
}
