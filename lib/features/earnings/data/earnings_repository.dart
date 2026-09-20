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
    this.method,
    this.reference,
  });

  final String id;
  final int totalCents;
  final String status; // PENDING | PAID | CANCELED
  final DateTime createdAt;
  final DateTime? paidAt;
  /// e.g. STRIPE, MANUAL_TRANSFER, MANUAL_CASH, CASH, BANK_TRANSFER
  final String? method;
  final String? reference;

  factory CleanerPayoutEntry.fromJson(Map<String, dynamic> json) {
    return CleanerPayoutEntry(
      id: json['id'] as String,
      totalCents: (json['totalCents'] as num).toInt(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      paidAt:
      json['paidAt'] != null ? DateTime.parse(json['paidAt'] as String) : null,
      method: json['method'] as String?,
      reference: json['reference'] as String?,
    );
  }

  String get methodLabel {
    switch (method) {
      case 'STRIPE':
        return 'Stripe';
      case 'MANUAL_TRANSFER':
      case 'BANK_TRANSFER':
        return 'Bank transfer';
      case 'CASH':
      case 'MANUAL_CASH':
        return 'Cash';
      case null:
      case '':
        return '—';
      default:
        return method!;
    }
  }
}

/// Real payroll figures from the business's payout ledger.
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

/// Stripe Connect status for this cleaner's payout account.
/// Connecting is OPTIONAL — businesses can pay by bank transfer / cash.
class StripeConnectStatus {
  const StripeConnectStatus({
    required this.connected,
    required this.chargesEnabled,
    required this.payoutsEnabled,
    required this.detailsSubmitted,
    this.optional = true,
    this.message,
  });

  final bool connected;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final bool detailsSubmitted;
  /// Always true on CleanSera — Connect never blocks receiving pay.
  final bool optional;
  final String? message;

  static const empty = StripeConnectStatus(
    connected: false,
    chargesEnabled: false,
    payoutsEnabled: false,
    detailsSubmitted: false,
    optional: true,
  );

  factory StripeConnectStatus.fromJson(Map<String, dynamic> json) {
    return StripeConnectStatus(
      connected: json['connected'] as bool? ?? false,
      chargesEnabled: json['chargesEnabled'] as bool? ?? false,
      payoutsEnabled: json['payoutsEnabled'] as bool? ?? false,
      detailsSubmitted: json['detailsSubmitted'] as bool? ?? false,
      optional: json['optional'] as bool? ?? true,
      message: json['message'] as String?,
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

  Future<StripeConnectStatus> fetchStripeStatus() async {
    final res = await _dio.get(ApiConstants.cleanerStripeStatus);
    return StripeConnectStatus.fromJson(unwrapEnvelope(res.data));
  }

  /// Starts (or resumes) Stripe Connect onboarding. Optional — never required
  /// to view earnings or get paid manually by the business.
  Future<String> fetchStripeOnboardingLink() async {
    final res = await _dio.post(ApiConstants.cleanerStripeOnboardingLink);
    final data = unwrapEnvelope(res.data);
    return data['url'] as String;
  }
}

final earningsRepositoryProvider = Provider<EarningsRepository>((ref) {
  return EarningsRepository(ref.watch(dioProvider));
});