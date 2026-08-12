/// Pinning tests for the [TransactionStatus] wire vocabulary.
///
/// The union of everything the chain can put in a `status` field is:
///   * node — `pending`, `success`, `fail`, `invalid`, `reward-reverted`, and
///     since Supernova also `not-executable-in-block`
///   * proxy — `unknown`, returned when no observer can answer
///   * public API — `success`, `pending`, `invalid`, `fail`
/// plus the legacy aliases still accepted on ingest: `received`, `executed`,
/// `successful`, `failed`, `unsuccessful`.
///
/// `recalled` belongs to none of them — no node, proxy or API emits it — so it
/// must not count as a final state.
///
/// `not-executable-in-block` is final (the status will not change again) but
/// NOT completed: completion stops at success or failure, and a transaction in
/// this state carries no logs and no smart contract results.
import 'package:abidock_mvx/abidock_mvx.dart';
import 'package:test/test.dart';

/// One row of the status truth table.
class _Row {
  const _Row({
    required this.status,
    required this.pending,
    required this.executed,
    required this.failed,
    required this.invalid,
    required this.notExecutableInBlock,
    required this.completed,
    required this.terminal,
  });

  /// Raw status string exactly as the wire spells it.
  final String status;

  /// Expected `isPending`.
  final bool pending;

  /// Expected `isExecuted` (and `isSuccessful`).
  final bool executed;

  /// Expected `isFailed`.
  final bool failed;

  /// Expected `isInvalid`.
  final bool invalid;

  /// Expected `isNotExecutableInBlock`.
  final bool notExecutableInBlock;

  /// Expected `isCompleted`.
  final bool completed;

  /// Expected `isFinal`.
  final bool terminal;
}

const List<_Row> _vocabulary = <_Row>[
  _Row(
    status: 'pending',
    pending: true,
    executed: false,
    failed: false,
    invalid: false,
    notExecutableInBlock: false,
    completed: false,
    terminal: false,
  ),
  _Row(
    status: 'received',
    pending: true,
    executed: false,
    failed: false,
    invalid: false,
    notExecutableInBlock: false,
    completed: false,
    terminal: false,
  ),
  _Row(
    status: 'success',
    pending: false,
    executed: true,
    failed: false,
    invalid: false,
    notExecutableInBlock: false,
    completed: true,
    terminal: true,
  ),
  _Row(
    status: 'successful',
    pending: false,
    executed: true,
    failed: false,
    invalid: false,
    notExecutableInBlock: false,
    completed: true,
    terminal: true,
  ),
  _Row(
    status: 'executed',
    pending: false,
    executed: true,
    failed: false,
    invalid: false,
    notExecutableInBlock: false,
    completed: true,
    terminal: true,
  ),
  _Row(
    status: 'fail',
    pending: false,
    executed: false,
    failed: true,
    invalid: false,
    notExecutableInBlock: false,
    completed: true,
    terminal: true,
  ),
  _Row(
    status: 'failed',
    pending: false,
    executed: false,
    failed: true,
    invalid: false,
    notExecutableInBlock: false,
    completed: true,
    terminal: true,
  ),
  _Row(
    status: 'unsuccessful',
    pending: false,
    executed: false,
    failed: true,
    invalid: false,
    notExecutableInBlock: false,
    completed: true,
    terminal: true,
  ),
  _Row(
    status: 'invalid',
    pending: false,
    executed: false,
    failed: true,
    invalid: true,
    notExecutableInBlock: false,
    completed: true,
    terminal: true,
  ),
  _Row(
    status: 'reward-reverted',
    pending: false,
    executed: false,
    failed: false,
    invalid: false,
    notExecutableInBlock: false,
    completed: false,
    terminal: false,
  ),
  _Row(
    status: 'not-executable-in-block',
    pending: false,
    executed: false,
    failed: false,
    invalid: false,
    notExecutableInBlock: true,
    completed: false,
    terminal: true,
  ),
  _Row(
    status: 'unknown',
    pending: false,
    executed: false,
    failed: false,
    invalid: false,
    notExecutableInBlock: false,
    completed: false,
    terminal: false,
  ),
  _Row(
    status: 'recalled',
    pending: false,
    executed: false,
    failed: false,
    invalid: false,
    notExecutableInBlock: false,
    completed: false,
    terminal: false,
  ),
];

void main() {
  group('TransactionStatus wire vocabulary (pinning)', () {
    for (final _Row row in _vocabulary) {
      test('"${row.status}" classifies exactly as the chain defines it', () {
        final TransactionStatus status = TransactionStatus(row.status);

        expect(status.isPending, equals(row.pending), reason: 'isPending');
        expect(status.isExecuted, equals(row.executed), reason: 'isExecuted');
        expect(
          status.isSuccessful,
          equals(row.executed),
          reason: 'isSuccessful',
        );
        expect(status.isFailed, equals(row.failed), reason: 'isFailed');
        expect(status.isInvalid, equals(row.invalid), reason: 'isInvalid');
        expect(
          status.isNotExecutableInBlock,
          equals(row.notExecutableInBlock),
          reason: 'isNotExecutableInBlock',
        );
        expect(
          status.isCompleted,
          equals(row.completed),
          reason: 'isCompleted',
        );
        expect(status.isFinal, equals(row.terminal), reason: 'isFinal');
      });
    }
  });

  group('not-executable-in-block is final but not completed', () {
    test('isFinal is true so a watcher stops polling', () {
      expect(
        const TransactionStatus('not-executable-in-block').isFinal,
        isTrue,
      );
    });

    test('isCompleted is false: it is neither executed nor failed', () {
      expect(
        const TransactionStatus('not-executable-in-block').isCompleted,
        isFalse,
      );
    });

    test('is neither a success nor a failure', () {
      const TransactionStatus status = TransactionStatus(
        'not-executable-in-block',
      );
      expect(status.isSuccessful, isFalse);
      expect(status.isFailed, isFalse);
    });
  });

  group('recalled is not a chain status', () {
    test('does not count as final', () {
      expect(const TransactionStatus('recalled').isFinal, isFalse);
    });

    test('does not count as completed, successful or failed', () {
      const TransactionStatus status = TransactionStatus('recalled');
      expect(status.isCompleted, isFalse);
      expect(status.isSuccessful, isFalse);
      expect(status.isFailed, isFalse);
    });
  });

  group('status constants carry the exact wire strings', () {
    test('pending, received', () {
      expect(TransactionStatus.pending.status, equals('pending'));
      expect(TransactionStatus.received.status, equals('received'));
    });

    test('success family', () {
      expect(TransactionStatus.success.status, equals('success'));
      expect(TransactionStatus.successful.status, equals('successful'));
      expect(TransactionStatus.executed.status, equals('executed'));
    });

    test('failure family', () {
      expect(TransactionStatus.fail.status, equals('fail'));
      expect(TransactionStatus.failed.status, equals('failed'));
      expect(TransactionStatus.unsuccessful.status, equals('unsuccessful'));
      expect(TransactionStatus.invalid.status, equals('invalid'));
    });

    test('reward-reverted, unknown, not-executable-in-block', () {
      expect(
        TransactionStatus.rewardReverted.status,
        equals('reward-reverted'),
      );
      expect(TransactionStatus.unknown.status, equals('unknown'));
      expect(
        TransactionStatus.notExecutableInBlock.status,
        equals('not-executable-in-block'),
      );
    });
  });

  group('classification is case-insensitive', () {
    test('uppercase wire strings classify identically', () {
      expect(const TransactionStatus('SUCCESS').isSuccessful, isTrue);
      expect(const TransactionStatus('Invalid').isFailed, isTrue);
      expect(
        const TransactionStatus('NOT-EXECUTABLE-IN-BLOCK').isCompleted,
        isFalse,
      );
      expect(
        const TransactionStatus('NOT-EXECUTABLE-IN-BLOCK').isFinal,
        isTrue,
      );
    });
  });
}
