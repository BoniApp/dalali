/// Review submitted after a verified stay.
class ReviewModel {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String reviewerId;
  final String reviewerName;
  final bool stayVerified;

  // Property ratings (1-5)
  final double cleanliness;
  final double valueForMoney;
  final double safety;

  // Landlord ratings (1-5)
  final double communication;
  final double fairness;
  final double maintenance;

  final String? comment;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.reviewerId,
    required this.reviewerName,
    this.stayVerified = false,
    required this.cleanliness,
    required this.valueForMoney,
    required this.safety,
    required this.communication,
    required this.fairness,
    required this.maintenance,
    this.comment,
    required this.createdAt,
  });

  /// Overall property score (average of property dimensions)
  double get propertyScore => (cleanliness + valueForMoney + safety) / 3;

  /// Overall landlord score (average of landlord dimensions)
  double get landlordScore => (communication + fairness + maintenance) / 3;

  /// Combined overall score
  double get overallScore => (propertyScore + landlordScore) / 2;

  ReviewModel copyWith({
    String? id,
    String? propertyId,
    String? propertyTitle,
    String? reviewerId,
    String? reviewerName,
    bool? stayVerified,
    double? cleanliness,
    double? valueForMoney,
    double? safety,
    double? communication,
    double? fairness,
    double? maintenance,
    String? comment,
    DateTime? createdAt,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      propertyTitle: propertyTitle ?? this.propertyTitle,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      stayVerified: stayVerified ?? this.stayVerified,
      cleanliness: cleanliness ?? this.cleanliness,
      valueForMoney: valueForMoney ?? this.valueForMoney,
      safety: safety ?? this.safety,
      communication: communication ?? this.communication,
      fairness: fairness ?? this.fairness,
      maintenance: maintenance ?? this.maintenance,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
