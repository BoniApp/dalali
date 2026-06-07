class FavoriteModel {
  final String id;
  final String userId;
  final String propertyId;
  final DateTime createdAt;

  FavoriteModel({
    required this.id,
    required this.userId,
    required this.propertyId,
    required this.createdAt,
  });
}
