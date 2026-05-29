import 'package:flutter_test/flutter_test.dart';
import 'package:omodscan_mobile/services/connection_manager.dart';

void main() {
  test('returns immediately on first success without reconnecting', () async {
    var reads = 0;
    var reconnects = 0;
    final result = await runReadWithRetry<int>(
      attempts: 3,
      reconnectDelay: Duration.zero,
      read: () async {
        reads++;
        return 7;
      },
      reconnect: () async => reconnects++,
    );

    expect(result, 7);
    expect(reads, 1);
    expect(reconnects, 0);
  });

  test('retries with reconnect and succeeds before exhausting attempts', () async {
    var reads = 0;
    var reconnects = 0;
    final result = await runReadWithRetry<int>(
      attempts: 3,
      reconnectDelay: Duration.zero,
      read: () async {
        reads++;
        if (reads < 3) throw StateError('drop');
        return 42;
      },
      reconnect: () async => reconnects++,
    );

    expect(result, 42);
    expect(reads, 3);
    // Reconnect runs between each failed attempt (after attempts 1 and 2).
    expect(reconnects, 2);
  });

  test('rethrows after exhausting all attempts', () async {
    var reads = 0;
    var reconnects = 0;
    await expectLater(
      runReadWithRetry<int>(
        attempts: 2,
        reconnectDelay: Duration.zero,
        read: () async {
          reads++;
          throw StateError('always');
        },
        reconnect: () async => reconnects++,
      ),
      throwsStateError,
    );

    expect(reads, 2);
    expect(reconnects, 1);
  });

  test('treats attempts below one as a single attempt', () async {
    var reads = 0;
    await expectLater(
      runReadWithRetry<int>(
        attempts: 0,
        reconnectDelay: Duration.zero,
        read: () async {
          reads++;
          throw StateError('x');
        },
        reconnect: () async {},
      ),
      throwsStateError,
    );

    expect(reads, 1);
  });

  test('ignores reconnect failures and keeps retrying', () async {
    var reads = 0;
    final result = await runReadWithRetry<int>(
      attempts: 2,
      reconnectDelay: Duration.zero,
      read: () async {
        reads++;
        if (reads < 2) throw StateError('drop');
        return 5;
      },
      reconnect: () async => throw StateError('reconnect failed'),
    );

    expect(result, 5);
    expect(reads, 2);
  });
}
