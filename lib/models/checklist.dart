import 'package:equatable/equatable.dart';

class ChecklistItem extends Equatable {
  const ChecklistItem({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.completedAt,
    this.order = 0,
    this.isRequired = true,
  });

  final String id;
  final String title;
  final String? description;
  final bool isCompleted;
  final DateTime? completedAt;
  final int order;
  final bool isRequired;

  ChecklistItem copyWith({
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return ChecklistItem(
      id: id,
      title: title,
      description: description,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      order: order,
      isRequired: isRequired,
    );
  }

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      id: json['id'] as String,
      // Backend stores items as { id, label, done } — title/name and
      // isCompleted/completed are accepted too in case a future endpoint
      // uses richer field names.
      title: json['label'] as String? ??
          json['title'] as String? ??
          json['name'] as String? ??
          '',
      description: json['description'] as String?,
      isCompleted: json['done'] as bool? ??
          json['isCompleted'] as bool? ??
          json['completed'] as bool? ??
          false,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      order: json['order'] as int? ?? json['sortOrder'] as int? ?? 0,
      isRequired: json['isRequired'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props =>
      [id, title, description, isCompleted, completedAt, order, isRequired];
}

class JobChecklist extends Equatable {
  const JobChecklist({
    required this.id,
    required this.bookingId,
    required this.items,
    this.title,
  });

  final String id;
  final String bookingId;
  final List<ChecklistItem> items;
  final String? title;

  int get completedCount => items.where((i) => i.isCompleted).length;
  int get totalCount => items.length;
  double get progress => totalCount == 0 ? 0 : completedCount / totalCount;
  bool get isFullyCompleted =>
      items.where((i) => i.isRequired).every((i) => i.isCompleted);

  factory JobChecklist.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ??
        json['tasks'] as List<dynamic>? ??
        [];
    final items = rawItems
        .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return JobChecklist(
      id: json['id'] as String? ?? json['bookingId'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? '',
      items: items,
      title: json['title'] as String? ?? json['name'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, bookingId, items, title];
}
