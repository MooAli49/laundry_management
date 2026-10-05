import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Application Orientation Locking Tests', () {
    final List<MethodCall> methodCalls = [];

    setUp(() {
      methodCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall methodCall,
          ) async {
            methodCalls.add(methodCall);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('enforces landscapeLeft and landscapeRight exclusively', () async {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

      expect(methodCalls, isNotEmpty);
      final orientationCall = methodCalls.firstWhere(
        (call) => call.method == 'SystemChrome.setPreferredOrientations',
      );

      final List<dynamic> arguments =
          orientationCall.arguments as List<dynamic>;
      expect(arguments, contains('DeviceOrientation.landscapeLeft'));
      expect(arguments, contains('DeviceOrientation.landscapeRight'));
      expect(arguments, hasLength(2));
      expect(arguments, isNot(contains('DeviceOrientation.portraitUp')));
      expect(arguments, isNot(contains('DeviceOrientation.portraitDown')));
    });
  });
}
