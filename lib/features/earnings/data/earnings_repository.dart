import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

class CleanerEarningEntry {
  const CleanerEarningEntry({
    required this.id,
    required this.bookingId,
    required this.amountCents,
    required this.status,
    required this.earnedAt,
  });

  final String id;
  final String bookingId;
  final int amountCents;
  final String status; // PENDING | IN_PAYOUT | PAID | VOIDED
  final DateTime earnedAt;

  factory CleanerEarningEntry.fromJson(Map<String, dynamic> json) {
    return CleanerEarningEntry(
      id: json['id'] as String,
      bookingId: json['bookingId'] as String,
      amountCents: (json['amountCents'] as num).toInt(),
      status: json['status'] as String,
      earnedAt: DateTime.parse(json['earnedAt'] as String),
    );
  }
}

class CleanerPayoutEntry {
  const CleanerPayoutEntry({
    required this.id,
    required this.totalCents,
    required this.status,
    required this.createdAt,
    this.paidAt,
  });

  final String id;
  final int totalCents;
  final String status; // PENDING | PAID | CANCELED
  final DateTime createdAt;
  final DateTime? paidAt;

  factory CleanerPayoutEntry.fromJson(Map<String, dynamic> json) {
    return CleanerPayoutEntry(
      id: json['id'] as String,
      totalCents: (json['totalCents'] as num).toInt(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt'] as String) : null,
    );
  }
}

/// Real payroll figures from the business's payout ledger — not an estimate
/// computed from job prices. A cleaner only sees a number here once their
/// business has set a pay rate for them (CleanerCompensation on the
/// backend); until then pendingCents/lifetimePaidCents both read zero.
class EarningsSummary {
  const EarningsSummary({
    required this.pendingCents,
    required this.lifetimePaidCents,
    required this.recentEarnings,
    required this.recentPayouts,
  });

  final int pendingCents;
  final int lifetimePaidCents;
  final List<CleanerEarningEntry> recentEarnings;
  final List<CleanerPayoutEntry> recentPayouts;

  static const empty = EarningsSummary(
    pendingCents: 0,
    lifetimePaidCents: 0,
    recentEarnings: [],
    recentPayouts: [],
  );

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    return EarningsSummary(
      pendingCents: (json['pendingCents'] as num?)?.toInt() ?? 0,
      lifetimePaidCents: (json['lifetimePaidCents'] as num?)?.toInt() ?? 0,
      recentEarnings: (json['recentEarnings'] as List<dynamic>? ?? [])
          .map((e) => CleanerEarningEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentPayouts: (json['recentPayouts'] as List<dynamic>? ?? [])
          .map((e) => CleanerPayoutEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class EarningsRepository {
  EarningsRepository(this._dio);

  final Dio _dio;

  Future<EarningsSummary> fetchSummary() async {
    final res = await _dio.get(ApiConstants.cleanerEarnings);
    return EarningsSummary.fromJson(unwrapEnvelope(res.data));
  }
}

final earningsRepositoryProvider = Provider<EarningsRepository>((ref) {
  return EarningsRepository(ref.watch(dioProvider));
});
