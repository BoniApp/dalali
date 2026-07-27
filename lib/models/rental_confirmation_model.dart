/// Rental confirmation ("mark as rented") — migration 030.
///
/// A landlord/agent marks an available listing as rented by a seeker
/// (row created `pending` via the `mark_listing_rented` RPC); the
/// seeker confirms (→ property `occupied` + tenancy created) or
/// disputes, via `respond_rental_confirmation`. The marker can cancel
/// a pending mark. All writes are RPC-only; clients just read rows.
library;

enum RentalConfirmationStatus { pending, confirmed, disputed, cancelled }

class RentalConfirmationModel {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String seekerId;
  final String seekerName;
  final String seekerPhone;
  final String markedBy;
  final String markedByName;
  final String markedByRole;
  final RentalConfirmationStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const RentalConfirmationModel({
    required this.id,
    required this.propertyId,
    this.propertyTitle = '',
    required this.seekerId,
    this.seekerName = '',
    this.seekerPhone = '',
    required this.markedBy,
    this.markedByName = '',
    this.markedByRole = '',
    this.status = RentalConfirmationStatus.pending,
    required this.createdAt,
    this.resolvedAt,
  });

  factory RentalConfirmationModel.fromJson(Map<String, dynamic> json) {
    return RentalConfirmationModel(
      id: json['id'] ?? '',
      propertyId: json['property_id'] ?? '',
      propertyTitle: json['property_title'] ?? '',
      seekerId: json['seeker_id'] ?? '',
      seekerName: json['seeker_name'] ?? '',
      seekerPhone: json['seeker_phone'] ?? '',
      markedBy: json['marked_by'] ?? '',
      markedByName: json['marked_by_name'] ?? '',
      markedByRole: json['marked_by_role'] ?? '',
      status: RentalConfirmationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RentalConfirmationStatus.pending,
      ),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'])
          : null,
    );
  }
}

/// A seeker eligible to be picked in the mark-as-rented sheet, as
/// returned by the `list_rentable_seekers` RPC (agency-fee payers ∪
/// tenancy applicants; [source] is 'paid', 'applied', or 'applied+paid').
class RentableSeeker {
  final String userId;
  final String fullName;
  final String phone;
  final String source;

  const RentableSeeker({
    required this.userId,
    this.fullName = '',
    this.phone = '',
    this.source = '',
  });

  bool get paid => source.contains('paid');
  bool get applied => source.contains('applied');

  factory RentableSeeker.fromJson(Map<String, dynamic> json) {
    return RentableSeeker(
      userId: json['user_id'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      source: json['source'] ?? '',
    );
  }
}
