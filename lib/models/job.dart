import 'package:equatable/equatable.dart';

enum JobStatus {
  pending,
  confirmed,
  assigned,
  enRoute,
  inProgress,
  completed,
  cancelled,
  noShow,
  unknown,
}

JobStatus jobStatusFromString(String? v) {
  switch (v?.toUpperCase()) {
    case 'PENDING':
      return JobStatus.pending;
    case 'CONFIRMED':
      return JobStatus.confirmed;
    case 'ASSIGNED':
      return JobStatus.assigned;
    case 'EN_ROUTE':
    case 'ENROUTE':
      return JobStatus.enRoute;
    case 'IN_PROGRESS':
    case 'INPROGRESS':
      return JobStatus.inProgress;
    case 'COMPLETED':
      return JobStatus.completed;
    case 'CANCELLED':
    case 'CANCELED':
      return JobStatus.cancelled;
    case 'NO_SHOW':
      return JobStatus.noShow;
    default:
      return JobStatus.unknown;
  }
}

class JobAddress extends Equatable {
  const JobAddress({
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.label,
  });

  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? label;

  String get fullAddress {
    final parts = [
      if (label != null && label!.isNotEmpty) label,
      line1,
      if (line2 != null && line2!.isNotEmpty) line2,
      '$city, $state${postalCode != null ? ' $postalCode' : ''}',
    ];
    return parts.join(', ');
  }

  factory JobAddress.fromJson(Map<String, dynamic> json) {
    return JobAddress(
      line1: json['line1'] as String? ?? '',
      line2: json['line2'] as String?,
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      postalCode: json['postalCode'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      label: json['label'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [line1, line2, city, state, postalCode, latitude, longitude, label];
}

class JobCustomer extends Equatable {
  const JobCustomer({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.email,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? email;

  String get fullName => '$firstName $lastName'.trim();

  factory JobCustomer.fromJson(Map<String, dynamic> json) {
    return JobCustomer(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, firstName, lastName, phone, email];
}

class JobService extends Equatable {
  const JobService({
    required this.id,
    required this.name,
    this.estimatedMinutes,
  });

  final String id;
  final String name;
  final int? estimatedMinutes;

  factory JobService.fromJson(Map<String, dynamic> json) {
    return JobService(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Service',
      estimatedMinutes: json['estimatedMinutes'] as int?,
    );
  }

  @override
  List<Object?> get props => [id, name, estimatedMinutes];
}

class Job extends Equatable {
  const Job({
    required this.id,
    required this.status,
    required this.scheduledStart,
    this.scheduledEnd,
    this.customer,
    this.service,
    this.address,
    this.notes,
    this.totalCents,
    this.checkedInAt,
    this.completedAt,
    this.checklistCompleted = false,
  });

  final String id;
  final JobStatus status;
  final DateTime scheduledStart;
  final DateTime? scheduledEnd;
  final JobCustomer? customer;
  final JobService? service;
  final JobAddress? address;
  final String? notes;
  final int? totalCents;
  final DateTime? checkedInAt;
  final DateTime? completedAt;
  final bool checklistCompleted;

  bool get canCheckIn =>
      status == JobStatus.assigned ||
      status == JobStatus.confirmed ||
      status == JobStatus.enRoute;

  bool get canStart =>
      status == JobStatus.assigned ||
      status == JobStatus.enRoute ||
      status == JobStatus.confirmed;

  bool get canComplete => status == JobStatus.inProgress;

  bool get isActive =>
      status == JobStatus.inProgress || status == JobStatus.enRoute;

  factory Job.fromJson(Map<String, dynamic> json) {
    DateTime parseDt(dynamic v) {
      if (v is String) return DateTime.parse(v).toLocal();
      return DateTime.now();
    }

    JobAddress? addr;
    if (json['address'] is Map<String, dynamic>) {
      addr = JobAddress.fromJson(json['address'] as Map<String, dynamic>);
    } else if (json['customerAddress'] is Map<String, dynamic>) {
      addr =
          JobAddress.fromJson(json['customerAddress'] as Map<String, dynamic>);
    }

    // The backend serializes a raw Prisma Booking, not a bespoke DTO, so
    // the price field is `quotedPriceCents` — not `totalCents`/`priceCents`.
    // Those two are kept as a fallback only in case a future endpoint does
    // shape the response differently.
    final totalCents = json['quotedPriceCents'] as int? ??
        json['totalCents'] as int? ??
        json['priceCents'] as int?;

    // checkedInAt/checkedOutAt live on BookingAssignment, not Booking itself.
    // /cleaner/bookings/my and /cleaner/bookings/:id both scope the
    // `assignments` include to `where: { cleanerId: <this cleaner> }`, so
    // when present it's a single-element list for this cleaner's own
    // assignment.
    final assignments = json['assignments'] as List<dynamic>?;
    final myAssignment = (assignments != null && assignments.isNotEmpty)
        ? assignments.first as Map<String, dynamic>
        : null;
    final checkedInAt = myAssignment?['checkedInAt'] as String? ??
        json['checkedInAt'] as String?;

    // Booking has no completedAt column at all — JobChecklist does, but
    // only once a checklist exists and was marked done. Falling back to
    // updatedAt for a COMPLETED booking gives a reasonable timestamp
    // instead of always showing nothing.
    final checklist = json['checklist'] as Map<String, dynamic>?;
    final completedAt = checklist?['completedAt'] as String? ??
        json['completedAt'] as String? ??
        (jobStatusFromString(json['status'] as String?) == JobStatus.completed
            ? json['updatedAt'] as String?
            : null);

    return Job(
      id: json['id'] as String,
      status: jobStatusFromString(json['status'] as String?),
      scheduledStart: parseDt(json['scheduledStart'] ?? json['startAt']),
      scheduledEnd: json['scheduledEnd'] != null || json['endAt'] != null
          ? parseDt(json['scheduledEnd'] ?? json['endAt'])
          : null,
      customer: json['customer'] is Map<String, dynamic>
          ? JobCustomer.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      service: json['service'] is Map<String, dynamic>
          ? JobService.fromJson(json['service'] as Map<String, dynamic>)
          : null,
      address: addr,
      notes: json['notes'] as String? ?? json['specialInstructions'] as String?,
      totalCents: totalCents,
      checkedInAt: checkedInAt != null
          ? DateTime.tryParse(checkedInAt)?.toLocal()
          : null,
      completedAt: completedAt != null
          ? DateTime.tryParse(completedAt)?.toLocal()
          : null,
      checklistCompleted: json['checklistCompleted'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        status,
        scheduledStart,
        scheduledEnd,
        customer,
        service,
        address,
        notes,
        totalCents,
        checkedInAt,
        completedAt,
        checklistCompleted,
      ];
}
