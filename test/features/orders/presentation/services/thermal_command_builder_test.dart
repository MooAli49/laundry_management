import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/features/orders/presentation/services/bluetooth_printer/printer_profile.dart';
import 'package:laundry_management/features/orders/presentation/services/bluetooth_printer/thermal_command_builder.dart';
import 'package:laundry_management/features/orders/presentation/services/bluetooth_printer/thermal_invoice_renderer.dart';

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

    test(
      'builds vertically split GS v 0 commands with seamless spacing and no cutter',
      () {
        final rows = List<List<bool>>.generate(
          140,
          (y) => List<bool>.generate(576, (x) => (x + y) % 2 == 0),
        );

        final blocks =
            ThermalCommandBuilder.buildVerticallySplitEscPosRasterCommands(
              rows: rows,
              width: 576,
              blockHeight: 64,
            );

        expect(blocks.length, 3);

        // Block 0: 64 rows, init + 0-dot line spacing + center + GS v 0 (16 bytes header)
        expect(blocks[0].sublist(0, 8), [
          0x1B, 0x40, // ESC @
          0x1B, 0x33, 0x00, // ESC 3 0
          0x1B, 0x61, 0x01, // ESC a 1
        ]);
        expect(blocks[0].sublist(8, 16), [
          0x1D, 0x76, 0x30, 0x00,
          72, 0, // xL=72, xH=0 (widthBytes=72)
          64, 0, // yL=64, yH=0 (height=64)
        ]);
        expect(blocks[0].length, 16 + (72 * 64)); // 4624 bytes

        // Block 1: 64 rows, only GS v 0 header (8 bytes)
        expect(blocks[1].sublist(0, 8), [0x1D, 0x76, 0x30, 0x00, 72, 0, 64, 0]);
        expect(blocks[1].length, 8 + (72 * 64)); // 4616 bytes

        // Block 2: remaining 12 rows, GS v 0 header (8 bytes) + payload + ESC d 5 (3 bytes)
        expect(blocks[2].sublist(0, 8), [
          0x1D, 0x76, 0x30, 0x00,
          72, 0,
          12, 0, // yL=12, yH=0 (height=12)
        ]);
        expect(blocks[2].sublist(blocks[2].length - 3), [
          0x1B,
          0x64,
          0x05,
        ]); // ESC d 5
        expect(blocks[2].length, 8 + (72 * 12) + 3); // 875 bytes

        // Verify no cutter in any block
        for (final block in blocks) {
          expect(
            block.contains(0x1D) &&
                block.contains(0x56) &&
                block.contains(0x41),
            isFalse,
          );
        }
      },
    );
  });

  group('Thermal Printing Accepted Baseline Verification', () {
    test('80mm paper printable dots is exactly 576 (72 bytes / 203 DPI)', () {
      expect(ThermalPaperWidth.w80.printablePixels, 576);
      expect((ThermalPaperWidth.w80.printablePixels + 7) ~/ 8, 72);
      expect(ThermalPaperWidth.w58.printablePixels, 384);
      expect((ThermalPaperWidth.w58.printablePixels + 7) ~/ 8, 48);
    });

    test('ThermalCommandBuilder thermalThreshold is 220', () {
      expect(ThermalCommandBuilder.thermalThreshold, 220);
    });

    test('ThermalInvoiceRenderer defaultTargetWidthPx is 576.0', () {
      expect(ThermalInvoiceRenderer.defaultTargetWidthPx, 576.0);
    });

    test(
      'known-good Test 5/6 baseline: 576x508 raster splits into 8 blocks totaling exactly 36651 bytes',
      () {
        // Height 508: 7 blocks of 64 rows + 1 block of 60 rows = 8 blocks
        final rows = List<List<bool>>.generate(
          508,
          (y) => List<bool>.generate(576, (x) => (x + y) % 2 == 0),
        );

        final blocks =
            ThermalCommandBuilder.buildVerticallySplitEscPosRasterCommands(
              rows: rows,
              width: 576,
              blockHeight: 64,
            );

        expect(blocks.length, 8);

        final totalBytes = blocks.fold<int>(0, (sum, b) => sum + b.length);
        // Block 0: 16 + (72 * 64) = 4624
        // Blocks 1-6: 6 * (8 + (72 * 64)) = 6 * 4616 = 27696
        // Block 7: 8 + (72 * 60) + 3 = 4331
        // Total: 4624 + 27696 + 4331 = 36651 bytes
        expect(totalBytes, 36651);
        expect(blocks[0].length, 4624);
        for (var i = 1; i <= 6; i++) {
          expect(blocks[i].length, 4616);
        }
        expect(blocks[7].length, 4331);
      },
    );
  });
}
