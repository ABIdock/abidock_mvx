/// Pinning test for the canonical native-EGLD identifier used inside
/// `MultiESDTNFTTransfer` payloads.
///
/// This test exists because `egldIdentifierForMultiTransfer` was already
/// silently regressed from `'EGLD-000000'` (correct) to the bare `'EGLD'`
/// (wrong) during agent edits. The wrong value causes the chain to reject
/// any multi-transfer that bundles native EGLD with ESDT tokens.
///
/// If you have a "good reason" to change this constant — stop. The reason
/// is almost certainly wrong. `EGLD-000000` is the on-wire representation the
/// protocol defines for native EGLD inside a multi-transfer payload.
import 'package:abidock_mvx/src/core/transaction/factories/transfer_transactions_factory.dart';
import 'package:test/test.dart';

void main() {
  group('egldIdentifierForMultiTransfer canonical value (pinning)', () {
    test('is exactly "EGLD-000000"', () {
      expect(egldIdentifierForMultiTransfer, equals('EGLD-000000'));
    });

    test('is not the regressed bare "EGLD" form', () {
      expect(egldIdentifierForMultiTransfer, isNot(equals('EGLD')));
    });

    test('TokenTransfer.egld produces the canonical sentinel', () {
      final TokenTransfer transfer = TokenTransfer.egld(BigInt.one);
      expect(transfer.tokenIdentifier, equals('EGLD-000000'));
      expect(transfer.isEgld, isTrue);
    });
  });
}
