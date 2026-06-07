enum MovePhase { beforeMove, movingDay, afterMove }

class ChecklistItem {
  final String id;
  final String title;
  final bool completed;
  final DateTime? completedAt;

  const ChecklistItem({
    required this.id,
    required this.title,
    this.completed = false,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'completed': completed,
    'completedAt': completedAt?.toIso8601String(),
  };

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    completed: json['completed'] ?? false,
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
  );

  ChecklistItem copyWith({bool? completed, DateTime? completedAt}) => ChecklistItem(
    id: id,
    title: title,
    completed: completed ?? this.completed,
    completedAt: completedAt ?? this.completedAt,
  );
}

class MoveChecklistModel {
  final String id;
  final String userId;
  final String? moveId;
  final String? tenancyId;
  final List<ChecklistItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MoveChecklistModel({
    required this.id,
    required this.userId,
    this.moveId,
    this.tenancyId,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'moveId': moveId,
    'tenancyId': tenancyId,
    'items': items.map((i) => i.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory MoveChecklistModel.fromJson(Map<String, dynamic> json, String id) =>
      MoveChecklistModel(
        id: id,
        userId: json['userId'] ?? '',
        moveId: json['moveId'],
        tenancyId: json['tenancyId'],
        items: (json['items'] as List<dynamic>?)
            ?.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
            .toList() ?? [],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );

  MoveChecklistModel copyWith({
    List<ChecklistItem>? items,
    DateTime? updatedAt,
  }) => MoveChecklistModel(
    id: id,
    userId: userId,
    moveId: moveId,
    tenancyId: tenancyId,
    items: items ?? this.items,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  double get progress => items.isEmpty ? 0 : items.where((i) => i.completed).length / items.length;
  int get completedCount => items.where((i) => i.completed).length;
  int get totalCount => items.length;
}
