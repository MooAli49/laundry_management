import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/data/datasources/remote/supabase_realtime_sync_adapter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeRealtimeChannel extends RealtimeChannel {
  void Function(Map<String, dynamic> payload)? broadcastCallback;
  void Function(RealtimeSubscribeStatus status, Object? error)? subscribeCallback;
  int subscribeCount = 0;
  int unsubscribeCount = 0;

  FakeRealtimeChannel()
      : super('laundry:sync', RealtimeClient('ws://localhost'));

  @override
  RealtimeChannel onBroadcast({
    required String event,
    required void Function(Map<String, dynamic> payload) callback,
  }) {
    broadcastCallback = callback;
    return this;
  }

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) {
    subscribeCount++;
    subscribeCallback = callback;
    callback?.call(RealtimeSubscribeStatus.subscribed, null);
    return this;
  }

  @override
  Future<String> unsubscribe([Duration? timeout]) async {
    unsubscribeCount++;
    subscribeCallback?.call(RealtimeSubscribeStatus.closed, null);
    return 'ok';
  }

  void simulateBroadcast([Map<String, dynamic> payload = const {'type': 'sync_available'}]) {
    broadcastCallback?.call(payload);
  }

  void simulateReconnect() {
    subscribeCallback?.call(RealtimeSubscribeStatus.subscribed, null);
  }
}

class FakeSupabaseClient extends SupabaseClient {
  final FakeRealtimeChannel fakeChannel;
  int removeChannelCount = 0;

  FakeSupabaseClient(this.fakeChannel)
      : super('https://dummy.supabase.co', 'dummy-anon-key');

  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) {
    return fakeChannel;
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async {
    removeChannelCount++;
    return 'ok';
  }
}

void main() {
  late FakeRealtimeChannel fakeChannel;
  late FakeSupabaseClient fakeClient;
  late SupabaseRealtimeSyncAdapter adapter;

  setUp(() {
    fakeChannel = FakeRealtimeChannel();
    fakeClient = FakeSupabaseClient(fakeChannel);
    adapter = SupabaseRealtimeSyncAdapter(client: fakeClient);
  });

  tearDown(() async {
    await adapter.dispose();
  });

  group('SupabaseRealtimeSyncAdapter Unit Tests', () {
    // -------------------------------------------------------------------------
    // Scenario G: Realtime Signal-Only Semantics
    // -------------------------------------------------------------------------
    test(
      'Scenario G: Realtime signal-only: payload content is discarded, only void is emitted',
      () async {
        final signals = <void>[];
        final subscription = adapter.onSyncAvailable.listen((signal) {
          signals.add(signal);
        });

        await adapter.subscribe();
        // One signal emitted upon initial subscribed status
        expect(signals.length, equals(1));

        // Simulate incoming Broadcast event with arbitrary payload
        fakeChannel.simulateBroadcast({
          'type': 'sync_available',
          'some_extra': 'ignored',
        });
        await Future<void>.delayed(Duration.zero);

        expect(signals.length, equals(2));

        await subscription.cancel();
      },
    );

    // -------------------------------------------------------------------------
    // Scenario H: Realtime Reconnect & Duplicate Prevention
    // -------------------------------------------------------------------------
    test(
      'Scenario H: Reconnect emits wake-up signal; duplicate subscribe calls are prevented',
      () async {
        await adapter.subscribe();
        expect(fakeChannel.subscribeCount, equals(1));
        expect(adapter.isSubscribed, isTrue);

        // Calling subscribe again must be a no-op (no duplicate channels)
        await adapter.subscribe();
        expect(fakeChannel.subscribeCount, equals(1));

        final signals = <void>[];
        final subscription = adapter.onSyncAvailable.listen((signal) {
          signals.add(signal);
        });

        // Simulate connection drop and reconnect
        fakeChannel.simulateReconnect();
        await Future<void>.delayed(Duration.zero);

        // Reconnect emitted a signal to ensure no missed updates
        expect(signals.length, equals(1));

        await subscription.cancel();
      },
    );

    // -------------------------------------------------------------------------
    // Unsubscribe and Disposal
    // -------------------------------------------------------------------------
    test(
      'Unsubscribe cleans up channel; dispose closes stream',
      () async {
        await adapter.subscribe();
        expect(adapter.isSubscribed, isTrue);

        await adapter.unsubscribe();
        expect(adapter.isSubscribed, isFalse);
        expect(fakeChannel.unsubscribeCount, equals(1));
        expect(fakeClient.removeChannelCount, equals(1));

        await adapter.dispose();
        // Calling subscribe after dispose is rejected
        await adapter.subscribe();
        expect(adapter.isSubscribed, isFalse);
      },
    );
  });
}
