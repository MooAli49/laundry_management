import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Domain Layer Purity Architecture Test', () {
    test('lib/domain/ has zero imports from Flutter, Drift, SQLite, Dio, or Core Failures', () {
      final domainDir = Directory('lib/domain');
      expect(domainDir.existsSync(), isTrue);

      final domainFiles = domainDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final prohibitedPatterns = [
        'package:flutter/',
        'package:drift/',
        'package:drift/native.dart',
        'package:sqlite3',
        'package:dio',
        'package:laundry_management/core/errors/failures.dart',
        'package:laundry_management/core/errors/app_exception.dart',
        'package:laundry_management/data/',
      ];

      final violations = <String>[];

      for (final file in domainFiles) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trim().startsWith('import ') || line.trim().startsWith('export ')) {
            for (final pattern in prohibitedPatterns) {
              if (line.contains(pattern)) {
                violations.add('${file.path}:${i + 1} contains prohibited import: $line');
              }
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Domain layer must remain 100% pure Dart without infrastructure dependencies:\n${violations.join('\n')}',
      );
    });
  });
}
