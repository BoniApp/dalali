enum MoveStatus { planning, active, completed, cancelled }

/// Represents a user's move — their current home listed while they search.
class MoveListingModel {
  final String id;
  final String userId;
  final String userName;
  final String? currentPropertyId;
  final String currentPropertyTitle;
  final String currentLocation;
  final DateTime moveDate;
  final MoveStatus status;
  final String? newPropertyId;
  final double? budgetMin;
  final double? budgetMax;
  final String? preferredLocation;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MoveListingModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.currentPropertyId,
    required this.currentPropertyTitle,
    required this.currentLocation,
    required this.moveDate,
    this.status = MoveStatus.planning,
    this.newPropertyId,
    this.budgetMin,
    this.budgetMax,
    this.preferredLocation,
    required this.createdAt,
    this.updatedAt,
  });

  MoveListingModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? currentPropertyId,
    String? currentPropertyTitle,
    String? currentLocation,
    DateTime? moveDate,
    MoveStatus? status,
    String? newPropertyId,
    double? budgetMin,
    double? budgetMax,
    String? preferredLocation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MoveListingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      currentPropertyId: currentPropertyId ?? this.currentPropertyId,
      currentPropertyTitle: currentPropertyTitle ?? this.currentPropertyTitle,
      currentLocation: currentLocation ?? this.currentLocation,
      moveDate: moveDate ?? this.moveDate,
      status: status ?? this.status,
      newPropertyId: newPropertyId ?? this.newPropertyId,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      preferredLocation: preferredLocation ?? this.preferredLocation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
