import 'package:equatable/equatable.dart';

/// One recurring weekly availability window, e.g. Monday 09:00–17:00.
/// dayOfWeek follows DateTime's convention: 1 = Monday ... 7 = Sunday.
class AvailabilitySlot extends Equatable {
  const AvailabilitySlot({
    this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  final String? id;
  final int dayOfWeek;
  final String startTime; // "HH:mm"
  final String endTime; // "HH:mm"

  AvailabilitySlot copyWith({
    int? dayOfWeek,
    String? startTime,
    String? endTime,
  }) {
    return AvailabilitySlot(
      id: id,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      id: json['id'] as String?,
      dayOfWeek: json['dayOfWeek'] as int? ?? 1,
      startTime: json['startTime'] as String? ?? '09:00',
      endTime: json['endTime'] as String? ?? '17:00',
    );
  }

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
      };

  @override
  List<Object?> get props => [id, dayOfWeek, startTime, endTime];
}

const List<String> weekdayLabels = [
  '', // unused — dayOfWeek is 1-indexed
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
