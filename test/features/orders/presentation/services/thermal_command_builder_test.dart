import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/features/orders/presentation/services/bluetooth_printer/thermal_command_builder.dart';

void main() {
  group('ThermalCommandBuilder ESC/POS raster', () {
    test('builds the expected GS v 0 header and 128x64 payload', () {
      final rows = List<List<bool>>.generate(
        64,
        (y) => List<bool>.generate(
          128,
          (x) => x == 0 || x == 127 || y == 0 || y == 63 || x == 64 || y == 32,
        ),
      );

      final command = ThermalCommandBuilder.buildEscPosRasterCommand(
        rows: rows,
        width: 128,
        height: 64,
        includeCut: false,
      );

      expect(command.sublist(8, 16), [
        0x1D,
        0x76,
        0x30,
        0x00,
        0x10,
        0x00,
        0x40,
        0x00,
      ]);
      expect(command.length, 16 + (16 * 64) + 3);
      expect(command.sublist(16, 16 + (16 * 64)).length, 1024);
      expect(command.sublist(16, 32), List<int>.filled(16, 0xFF));
      expect(command.sublist(32, 48), [
        0x80,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x80,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x01,
      ]);
    });

    test('packs first pixel into MSB and eighth pixel into LSB', () {
      final command = ThermalCommandBuilder.buildEscPosRasterCommand(
        rows: [
          [true, false, false, false, false, false, false, false],
          [false, false, false, false, false, false, false, true],
        ],
        width: 8,
        height: 2,
        includeCut: false,
      );

      expect(command.sublist(16, 18), [0x80, 0x01]);
    });

    test('builds GS ( L graphics data and print commands', () {
      final command = ThermalCommandBuilder.buildDiagnosticGsLCommand();

      expect(command.sublist(0, 13), [
        0x1D,
        0x28,
        0x4C,
        0x0A,
        0x04,
        0x30,
        0x00,
        0x30,
        0x00,
        0x10,
        0x00,
        0x40,
        0x00,
      ]);
      expect(command.sublist(13, 13 + 1024).length, 1024);
      expect(command.sublist(13 + 1024, 13 + 1024 + 8), [
        0x1D,
        0x28,
        0x4C,
        0x02,
        0x00,
        0x31,
        0x45,
        0x00,
      ]);
      expect(command.length, 13 + 1024 + 8 + 3);
      expect(command.sublist(13, 29), List<int>.filled(16, 0xFF));
    });
  });
}
