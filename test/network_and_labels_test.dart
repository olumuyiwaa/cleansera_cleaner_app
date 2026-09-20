import 'package:cleansera_cleaner/core/network/dio_client.dart';
import 'package:cleansera_cleaner/features/earnings/data/earnings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

CleanerPayoutEntry _payout(String? method) => CleanerPayoutEntry.fromJson({
      'id': 'p1',
      'totalCents': 1000,
      'status': 'PAID',
      'createdAt': '2026-09-01T10:00:00Z',
      'method': method,
    });

void main() {
  group('payout method label', () {
    test('the backend\'s manual cash value reads as Cash, not the raw enum', () {
      expect(_payout('MANUAL_CASH').methodLabel, 'Cash');
    });
    test('other methods', () {
      expect(_payout('STRIPE').methodLabel, 'Stripe');
      expect(_payout('MANUAL_TRANSFER').methodLabel, 'Bank transfer');
      expect(_payout(null).methodLabel, '—');
    });
  });

  group('unwrapEnvelope', () {
    test('unwraps { success, data }', () {
      expect(unwrapEnvelope({'success': true, 'data': {'a': 1}}), {'a': 1});
    });
    test('passes through an already-unwrapped map', () {
      expect(unwrapEnvelope({'a': 1}), {'a': 1});
    });
  });
}
