/// Admin role hierarchy for RBAC.
enum AdminRole { superAdmin, financeAdmin, listingsModerator, supportAgent, fraudAnalyst }

/// Immutable admin action log entry.
class AdminLogModel {
  final String id;
  final String adminId;
  final String adminName;
  final AdminRole adminRole;
  final String action;
  final String targetCollection;
  final String? targetId;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final DateTime createdAt;

  const AdminLogModel({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
    required this.action,
    required this.targetCollection,
    this.targetId,
    this.before,
    this.after,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'adminId': adminId,
    'adminName': adminName,
    'adminRole': adminRole.name,
    'action': action,
    'targetCollection': targetCollection,
    'targetId': targetId,
    'before': before,
    'after': after,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AdminLogModel.fromJson(Map<String, dynamic> json, String id) {
    return AdminLogModel(
      id: id,
      adminId: json['adminId'] ?? '',
      adminName: json['adminName'] ?? '',
      adminRole: AdminRole.values.firstWhere(
        (e) => e.name == json['adminRole'],
        orElse: () => AdminRole.supportAgent,
      ),
      action: json['action'] ?? '',
      targetCollection: json['targetCollection'] ?? '',
      targetId: json['targetId'],
      before: json['before'] as Map<String, dynamic>?,
      after: json['after'] as Map<String, dynamic>?,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Fraud report submitted by system or users.
class FraudReportModel {
  final String id;
  final String userId;
  final String? propertyId;
  final String reason;
  final String severity; // low, medium, high, critical
  final bool resolved;
  final String? resolvedBy;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const FraudReportModel({
    required this.id,
    required this.userId,
    this.propertyId,
    required this.reason,
    required this.severity,
    this.resolved = false,
    this.resolvedBy,
    required this.createdAt,
    this.resolvedAt,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'propertyId': propertyId,
    'reason': reason,
    'severity': severity,
    'resolved': resolved,
    'resolvedBy': resolvedBy,
    'createdAt': createdAt.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
  };

  factory FraudReportModel.fromJson(Map<String, dynamic> json, String id) {
    return FraudReportModel(
      id: id,
      userId: json['userId'] ?? '',
      propertyId: json['propertyId'],
      reason: json['reason'] ?? '',
      severity: json['severity'] ?? 'low',
      resolved: json['resolved'] ?? false,
      resolvedBy: json['resolvedBy'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      resolvedAt: json['resolvedAt'] != null ? DateTime.tryParse(json['resolvedAt']) : null,
    );
  }
}

/// Dispute case between parties.
class DisputeModel {
  final String id;
  final String reporterId;
  final String? respondentId;
  final String? propertyId;
  final String subject;
  final String description;
  final String status; // open, under_review, resolved, closed
  final String? resolution;
  final String? resolvedBy;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const DisputeModel({
    required this.id,
    required this.reporterId,
    this.respondentId,
    this.propertyId,
    required this.subject,
    required this.description,
    this.status = 'open',
    this.resolution,
    this.resolvedBy,
    required this.createdAt,
    this.resolvedAt,
  });

  Map<String, dynamic> toJson() => {
    'reporterId': reporterId,
    'respondentId': respondentId,
    'propertyId': propertyId,
    'subject': subject,
    'description': description,
    'status': status,
    'resolution': resolution,
    'resolvedBy': resolvedBy,
    'createdAt': createdAt.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
  };

  factory DisputeModel.fromJson(Map<String, dynamic> json, String id) {
    return DisputeModel(
      id: id,
      reporterId: json['reporterId'] ?? '',
      respondentId: json['respondentId'],
      propertyId: json['propertyId'],
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'open',
      resolution: json['resolution'],
      resolvedBy: json['resolvedBy'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      resolvedAt: json['resolvedAt'] != null ? DateTime.tryParse(json['resolvedAt']) : null,
    );
  }
}

/// Helper: checks if a role can perform an action.
class AdminPermissions {
  static bool canManageWallets(AdminRole role) =>
      role == AdminRole.superAdmin || role == AdminRole.financeAdmin;

  static bool canManageTransactions(AdminRole role) =>
      role == AdminRole.superAdmin || role == AdminRole.financeAdmin;

  static bool canManageListings(AdminRole role) =>
      role == AdminRole.superAdmin || role == AdminRole.listingsModerator;

  static bool canManageUsers(AdminRole role) =>
      role == AdminRole.superAdmin || role == AdminRole.supportAgent;

  static bool canManageWithdrawals(AdminRole role) =>
      role == AdminRole.superAdmin || role == AdminRole.financeAdmin;

  static bool canViewFraud(AdminRole role) =>
      role == AdminRole.superAdmin || role == AdminRole.fraudAnalyst;

  static bool canViewAnalytics(AdminRole role) => true; // All admins can view

  static bool canManageSettings(AdminRole role) =>
      role == AdminRole.superAdmin;

  static bool canManageDisputes(AdminRole role) =>
      role == AdminRole.superAdmin || role == AdminRole.supportAgent;

  static bool canManageAdmins(AdminRole role) =>
      role == AdminRole.superAdmin;

  static bool canManageInfluencers(AdminRole role) =>
      role == AdminRole.superAdmin ||
      role == AdminRole.financeAdmin ||
      role == AdminRole.supportAgent ||
      role == AdminRole.fraudAnalyst;

  static bool canBroadcast(AdminRole role) =>
      role == AdminRole.superAdmin || role == AdminRole.supportAgent;
}
