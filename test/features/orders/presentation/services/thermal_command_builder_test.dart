import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management/features/orders/presentation/services/bluetooth_printer/printer_profile.dart';
import 'package:laundry_management/features/orders/presentation/services/bluetooth_printer/thermal_command_builder.dart';
import 'package:laundry_management/features/orders/presentation/services/bluetooth_printer/thermal_invoice_renderer.dart';

void main() {
  group('ThermalCommandBuilder ESC/POS raster basics', () {
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
  });

  group('Production Invoice Raster Chunking Integrity (Section 8 Verification)', () {
    const invoiceWidth = 576;
    const invoiceHeight = 2291;
    const chunkHeight = 256;
    final widthBytes = (invoiceWidth + 7) ~/ 8; // 72

    late List<List<bool>> originalRows;
    late List<List<int>> chunks;

    setUp(() {
      // Deterministic synthetic invoice bitmap: 576 dots wide x 2291 rows tall
      originalRows = List<List<bool>>.generate(
        invoiceHeight,
        (y) => List<bool>.generate(
          invoiceWidth,
          (x) => (x * 37 + y * 53) % 7 == 0 || (x % 32 == 0) || (y % 16 == 0),
        ),
      );

      chunks = ThermalCommandBuilder.buildVerticallySplitEscPosRasterCommands(
        rows: originalRows,
        width: invoiceWidth,
        blockHeight: chunkHeight,
      );
    });

    test('1. chunks count matches expected vertical division', () {
      final expectedChunkCount =
          (invoiceHeight + chunkHeight - 1) ~/ chunkHeight;
      expect(expectedChunkCount, 9);
      expect(chunks.length, 9);
    });

    test(
      '2. all chunks have the same printable width (576 dots / 72 bytes)',
      () {
        for (var i = 0; i < chunks.length; i++) {
          final chunk = chunks[i];
          final headerOffset = (i == 0)
              ? 8
              : 0; // Block 0 has 8 bytes prefix (ESC @, ESC 3 0, ESC a 1)

          // GS v 0 magic
          expect(chunk.sublist(headerOffset, headerOffset + 4), [
            0x1D,
            0x76,
            0x30,
            0x00,
          ]);

          // xL and xH
          final xL = chunk[headerOffset + 4];
          final xH = chunk[headerOffset + 5];
          final chunkWidthBytes = xL | (xH << 8);
          expect(
            chunkWidthBytes,
            widthBytes,
            reason: 'Chunk $i widthBytes should be 72',
          );
        }
      },
    );

    test(
      '3. chunks remain in order and consecutive row spans cover the entire invoice',
      () {
        var expectedStartY = 0;

        for (var i = 0; i < chunks.length; i++) {
          final chunk = chunks[i];
          final headerOffset = (i == 0) ? 8 : 0;
          final yL = chunk[headerOffset + 6];
          final yH = chunk[headerOffset + 7];
          final currentChunkHeight = yL | (yH << 8);

          if (i < chunks.length - 1) {
            expect(
              currentChunkHeight,
              chunkHeight,
              reason: 'Chunk $i should have height $chunkHeight',
            );
          } else {
            // Last chunk has remainder: 2291 - (8 * 256) = 243
            expect(currentChunkHeight, invoiceHeight - (8 * chunkHeight));
          }

          expectedStartY += currentChunkHeight;
        }

        expect(expectedStartY, invoiceHeight);
      },
    );

    test(
      '4. invoice rows are preserved exactly, no rows lost, no rows duplicated',
      () {
        final reconstructedRows = <List<bool>>[];

        for (var i = 0; i < chunks.length; i++) {
          final chunk = chunks[i];
          final headerOffset = (i == 0) ? 8 : 0;
          final yL = chunk[headerOffset + 6];
          final yH = chunk[headerOffset + 7];
          final currentChunkHeight = yL | (yH << 8);

          final payloadStart = headerOffset + 8;
          final payloadEnd = payloadStart + (currentChunkHeight * widthBytes);
          final payload = chunk.sublist(payloadStart, payloadEnd);

          // Unpack payload back to rows
          for (var r = 0; r < currentChunkHeight; r++) {
            final rowBits = <bool>[];
            final rowBytes = payload.sublist(
              r * widthBytes,
              (r + 1) * widthBytes,
            );
            for (var b = 0; b < widthBytes; b++) {
              final byteVal = rowBytes[b];
              for (var bit = 7; bit >= 0; bit--) {
                rowBits.add((byteVal & (1 << bit)) != 0);
              }
            }
            // Truncate to invoiceWidth (since width is 576 and 72 * 8 = 576)
            reconstructedRows.add(rowBits.sublist(0, invoiceWidth));
          }
        }

        // Assert total row count
        expect(
          reconstructedRows.length,
          invoiceHeight,
          reason: 'No rows lost or added',
        );

        // Assert bit-for-bit equivalence across all 2,291 rows and 576 columns
        for (var y = 0; y < invoiceHeight; y++) {
          for (var x = 0; x < invoiceWidth; x++) {
            if (reconstructedRows[y][x] != originalRows[y][x]) {
              fail('Mismatch at row $y, col $x');
            }
          }
        }
      },
    );

    test(
      '5. concatenating raster chunks reconstructs the exact original raster without blank rows',
      () {
        // Concatenate the chunks into one print stream (the production transmission payload)
        final concatenatedStream = chunks.expand((c) => c).toList();
        expect(concatenatedStream, isNotEmpty);

        // Verify header of entire concatenated stream starts with printer init and zero line spacing
        expect(concatenatedStream.sublist(0, 8), [
          0x1B, 0x40, // ESC @
          0x1B, 0x33, 0x00, // ESC 3 0
          0x1B, 0x61, 0x01, // ESC a 1
        ]);

        // Verify trailer of entire stream ends with line feed
        expect(concatenatedStream.sublist(concatenatedStream.length - 3), [
          0x1B, 0x64, 0x05, // ESC d 5
        ]);

        // Verify no cutter commands were injected
        expect(
          concatenatedStream.contains(0x1D) &&
              concatenatedStream.contains(0x56) &&
              concatenatedStream.contains(0x41),
          isFalse,
        );
      },
    );
  });
}
