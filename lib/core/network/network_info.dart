import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Centralized network connectivity abstraction.
///
/// Provides connectivity indications without leaking third-party
/// networking details (such as [ConnectivityResult]) into domain or feature code.
abstract class NetworkInfo {
  /// Returns `true` if an active network connection is currently detected.
  Future<bool> get isConnected;

  /// Emits updates whenever the network connectivity state changes.
  Stream<bool> get onConnectivityChanged;
}

/// Default implementation of [NetworkInfo] backed by [Connectivity].
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity _connectivity;

  NetworkInfoImpl({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> get isConnected async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _hasConnection(results);
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged
        .map(_hasConnection)
        .transform(
          StreamTransformer<bool, bool>.fromHandlers(
            handleError: (error, stackTrace, sink) {
              sink.add(false);
            },
          ),
        )
        .distinct();
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.isNotEmpty &&
        results.any((result) => result != ConnectivityResult.none);
  }
}
