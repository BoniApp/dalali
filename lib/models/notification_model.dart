enum NotificationType {
  inquiry,
  appointment,
  propertyApproved,
  propertyRejected,
  tenancyApplication,
  tenancyApproved,
  maintenanceUpdate,
  rentDue,
  paymentReceived,
  withdrawalProcessed,
  system,
}

class NotificationModel {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final String? targetId;
  final String? targetCollection;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.targetId,
    this.targetCollection,
    this.isRead = false,
    required this.createdAt,
  });

  NotificationModel copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? body,
    String? targetId,
    String? targetCollection,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      targetId: targetId ?? this.targetId,
      targetCollection: targetCollection ?? this.targetCollection,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
