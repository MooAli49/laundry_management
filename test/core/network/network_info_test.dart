import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/core/network/network_info.dart';

class FakeConnectivity implements Connectivity {
  List<ConnectivityResult> resultsToReturn = [ConnectivityResult.none];
  bool shouldThrow = false;
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    if (shouldThrow) {
      throw Exception('Platform failure');
    }
    return resultsToReturn;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  void emit(List<ConnectivityResult> results) {
    _controller.add(results);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('NetworkInfo Tests', () {
    late FakeConnectivity fakeConnectivity;
    late NetworkInfo networkInfo;

    setUp(() {
      fakeConnectivity = FakeConnectivity();
      networkInfo = NetworkInfoImpl(connectivity: fakeConnectivity);
    });

    tearDown(() {
      fakeConnectivity.dispose();
    });

    group('isConnected', () {
      test('returns true when connected to WiFi', () async {
        fakeConnectivity.resultsToReturn = [ConnectivityResult.wifi];
        expect(await networkInfo.isConnected, isTrue);
      });

      test('returns true when connected to Mobile network', () async {
        fakeConnectivity.resultsToReturn = [ConnectivityResult.mobile];
        expect(await networkInfo.isConnected, isTrue);
      });

      test('returns true when connected to Ethernet', () async {
        fakeConnectivity.resultsToReturn = [ConnectivityResult.ethernet];
        expect(await networkInfo.isConnected, isTrue);
      });

      test('returns true when connected to VPN', () async {
        fakeConnectivity.resultsToReturn = [ConnectivityResult.vpn];
        expect(await networkInfo.isConnected, isTrue);
      });

      test(
        'returns true when multiple results contain at least one non-none result',
        () async {
          fakeConnectivity.resultsToReturn = [
            ConnectivityResult.none,
            ConnectivityResult.wifi,
          ];
          expect(await networkInfo.isConnected, isTrue);
        },
      );

      test('returns false when result is ConnectivityResult.none', () async {
        fakeConnectivity.resultsToReturn = [ConnectivityResult.none];
        expect(await networkInfo.isConnected, isFalse);
      });

      test('returns false when results list is empty', () async {
        fakeConnectivity.resultsToReturn = [];
        expect(await networkInfo.isConnected, isFalse);
      });

      test(
        'returns false when connectivity check throws an exception',
        () async {
          fakeConnectivity.shouldThrow = true;
          expect(await networkInfo.isConnected, isFalse);
        },
      );
    });

    group('onConnectivityChanged stream', () {
      test('emits true on connection and false on disconnection', () async {
        final emissions = <bool>[];
        final subscription = networkInfo.onConnectivityChanged.listen(
          emissions.add,
        );

        fakeConnectivity.emit([ConnectivityResult.wifi]);
        await Future<void>.delayed(Duration.zero);

        fakeConnectivity.emit([ConnectivityResult.none]);
        await Future<void>.delayed(Duration.zero);

        fakeConnectivity.emit([ConnectivityResult.mobile]);
        await Future<void>.delayed(Duration.zero);

        await subscription.cancel();

        expect(emissions, [true, false, true]);
      });

      test('filters consecutive duplicate states using distinct()', () async {
        final emissions = <bool>[];
        final subscription = networkInfo.onConnectivityChanged.listen(
          emissions.add,
        );

        fakeConnectivity.emit([ConnectivityResult.wifi]);
        await Future<void>.delayed(Duration.zero);

        // Still connected (mobile), boolean state does not change
        fakeConnectivity.emit([ConnectivityResult.mobile]);
        await Future<void>.delayed(Duration.zero);

        // Disconnect
        fakeConnectivity.emit([ConnectivityResult.none]);
        await Future<void>.delayed(Duration.zero);

        // Consecutive disconnect event
        fakeConnectivity.emit([ConnectivityResult.none]);
        await Future<void>.delayed(Duration.zero);

        await subscription.cancel();

        expect(emissions, [true, false]);
      });

      test('handles stream errors gracefully returning false', () async {
        final emissions = <bool>[];
        final subscription = networkInfo.onConnectivityChanged.listen(
          emissions.add,
        );

        fakeConnectivity.emitError(Exception('Stream error'));
        await Future<void>.delayed(Duration.zero);

        await subscription.cancel();

        expect(emissions, [false]);
      });
    });
  });
}
