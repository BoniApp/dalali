class InquiryModel {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String seekerId;
  final String seekerName;
  final String seekerPhone;
  final String landlordId;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  InquiryModel({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.seekerId,
    required this.seekerName,
    required this.seekerPhone,
    required this.landlordId,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });
}
