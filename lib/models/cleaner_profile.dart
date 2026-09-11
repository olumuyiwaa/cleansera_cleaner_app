import 'package:equatable/equatable.dart';
import 'user.dart';

enum CleanerStatus { pending, active, suspended, offboarded, unknown }

CleanerStatus cleanerStatusFromString(String? v) {
  switch (v?.toUpperCase()) {
    case 'PENDING':
      return CleanerStatus.pending;
    case 'ACTIVE':
      return CleanerStatus.active;
    case 'SUSPENDED':
      return CleanerStatus.suspended;
    case 'OFFBOARDED':
      return CleanerStatus.offboarded;
    default:
      return CleanerStatus.unknown;
  }
}

class CleanerProfile extends Equatable {
  const CleanerProfile({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.status,
    this.hireDate,
    this.user,
    this.businessName,
    this.serviceAreaIds = const [],
  });

  final String id;
  final String businessId;
  final String userId;
  final CleanerStatus status;
  final DateTime? hireDate;
  final User? user;
  final String? businessName;
  final List<String> serviceAreaIds;

  bool get isActive => status == CleanerStatus.active;

  factory CleanerProfile.fromJson(Map<String, dynamic> json) {
    return CleanerProfile(
      id: json['id'] as String,
      businessId: json['businessId'] as String,
      userId: json['userId'] as String,
      status: cleanerStatusFromString(json['status'] as String?),
      hireDate: json['hireDate'] != null
          ? DateTime.tryParse(json['hireDate'] as String)
          : null,
      user: json['user'] is Map<String, dynamic>
          ? User.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      businessName: json['business'] is Map
          ? (json['business'] as Map)['name'] as String?
          : json['businessName'] as String?,
      serviceAreaIds: (json['serviceAreaIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'businessId': businessId,
        'userId': userId,
        'status': status.name.toUpperCase(),
        'hireDate': hireDate?.toIso8601String(),
        'user': user?.toJson(),
        'businessName': businessName,
        'serviceAreaIds': serviceAreaIds,
      };

  @override
  List<Object?> get props =>
      [id, businessId, userId, status, hireDate, user, businessName];
}
