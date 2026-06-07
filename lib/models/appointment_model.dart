enum AppointmentStatus { pending, confirmed, completed, cancelled }

class AppointmentModel {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String seekerId;
  final String seekerName;
  final String seekerPhone;
  final String landlordId;
  final DateTime scheduledDate;
  final String notes;
  final AppointmentStatus status;
  final DateTime createdAt;

  AppointmentModel({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.seekerId,
    required this.seekerName,
    required this.seekerPhone,
    required this.landlordId,
    required this.scheduledDate,
    this.notes = '',
    this.status = AppointmentStatus.pending,
    required this.createdAt,
  });
}
