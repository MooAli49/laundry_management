import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/realtime_sync_adapter.dart';

/// Concrete implementation of [RealtimeSyncAdapter] backed by Supabase Realtime Broadcast.
///
/// Subscribes to the ephemeral broadcast topic `laundry:sync` and listens for
/// `sync_available` events.
///
/// Invariants:
/// 1. Broadcast payload carries no business data and is completely ignored.
/// 2. Only an ephemeral `void` signal is emitted on [onSyncAvailable].
/// 3. Never performs Drift database writes.
/// 4. Never creates SyncOperation records.
/// 5. Duplicate subscriptions are prevented.
/// 6. Reconnect events emit a single coalesced wake-up signal to prevent sync storms.
class SupabaseRealtimeSyncAdapter implements RealtimeSyncAdapter {
  final SupabaseClient _client;
  final StreamController<void> _controller = StreamController<void>.broadcast();

  RealtimeChannel? _channel;
  bool _isSubscribed = false;
  bool _isDisposed = false;

  SupabaseRealtimeSyncAdapter({required SupabaseClient client})
    : _client = client;

  @override
  Stream<void> get onSyncAvailable => _controller.stream;

  /// Whether the channel is actively subscribed.
  bool get isSubscribed => _isSubscribed;

  @override
  Future<void> subscribe() async {
    if (_isDisposed || _isSubscribed || _channel != null) {
      return;
    }

    final channel = _client.channel('laundry:sync');
    _channel = channel;

    channel.onBroadcast(
      event: 'sync_available',
      callback: (payload) {
        if (_isDisposed) return;
        // Invariant: payload is strictly ignored/discarded.
        // Emit wake-up signal only.
        _emitSignal();
      },
    );

    channel.subscribe((status, [error]) {
      if (_isDisposed) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isSubscribed = true;
        // On initial subscribe or reconnect, emit wake-up signal to check for changes
        _emitSignal();
      } else if (status == RealtimeSubscribeStatus.closed ||
          status == RealtimeSubscribeStatus.channelError) {
        _isSubscribed = false;
      }
    });
  }

  void _emitSignal() {
    if (!_controller.isClosed && !_isDisposed) {
      _controller.add(null);
    }
  }

  @override
  Future<void> unsubscribe() async {
    _isSubscribed = false;
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      try {
        await ch.unsubscribe();
        await _client.removeChannel(ch);
      } catch (_) {
        // Safe disposal: ignore network/cleanup errors
      }
    }
  }

  /// Disposes the adapter and closes the signal stream.
  Future<void> dispose() async {
    _isDisposed = true;
    await unsubscribe();
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
