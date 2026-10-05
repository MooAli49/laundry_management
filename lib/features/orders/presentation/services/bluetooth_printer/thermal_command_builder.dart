import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'printer_profile.dart';

// ---------------------------------------------------------------------------
// Isolate helpers — must be top-level for compute() to serialize them.
// ---------------------------------------------------------------------------

/// Arguments bundle passed across the isolate boundary to [_buildBlocksInIsolate].
class _MonochromeArgs {
  const _MonochromeArgs({
    required this.pixels,
    required this.width,
    required this.height,
    required this.protocol,
    required this.blockHeight,
    required this.paperWidthMm,
    required this.threshold,
  });

  final Uint8List pixels;
  final int width;
  final int height;
  final PrinterProtocol protocol;
  final int blockHeight;
  final int paperWidthMm;
  final int threshold;
}

List<List<bool>> _rgbaToMonochrome(
  Uint8List pixels,
  int width,
  int height,
  int threshold,
) {
  final lines = <List<bool>>[];
  for (int y = 0; y < height; y++) {
    final line = <bool>[];
    for (int x = 0; x < width; x++) {
      final idx = (y * width + x) * 4;
      final r = pixels[idx];
      final g = pixels[idx + 1];
      final b = pixels[idx + 2];
      // BT.601 luma approximation
      final lum = (0.299 * r + 0.587 * g + 0.114 * b).round();
      line.add(lum < threshold);
    }
    lines.add(line);
  }
  return lines;
}

/// Top-level function executed in a background isolate by [compute].
///
/// Converts raw RGBA pixel data to a 1-bit monochrome representation and then
/// builds the protocol-specific printer command blocks.
List<List<int>> _buildBlocksInIsolate(_MonochromeArgs args) {
  final width = args.width;
  final height = args.height;
  final lines = _rgbaToMonochrome(args.pixels, width, height, args.threshold);

  switch (args.protocol) {
    case PrinterProtocol.tspl:
      // Build a minimal TSPL BITMAP command entirely in the isolate.
      return [
        _buildTsplCommandInIsolate(lines, width, height, args.paperWidthMm),
      ];
    case PrinterProtocol.escPos:
    case PrinterProtocol.auto:
      return ThermalCommandBuilder.buildVerticallySplitEscPosRasterCommands(
        rows: lines,
        width: width,
        blockHeight: args.blockHeight,
      );
  }
}

/// Minimal TSPL BITMAP command builder for use inside the background isolate.
List<int> _buildTsplCommandInIsolate(
  List<List<bool>> lines,
  int width,
  int height,
  int paperWidthMm,
) {
  final cmd = <int>[];
  void addStr(String s) => cmd.addAll(s.codeUnits);
  void addCrlf() => cmd.addAll([0x0D, 0x0A]);
  addStr('SIZE $paperWidthMm mm, 200 mm');
  addCrlf();
  addStr('GAP 0 mm, 0 mm');
  addCrlf();
  addStr('CLS');
  addCrlf();
  final bytesPerLine = (width + 7) ~/ 8;
  addStr('BITMAP 0,0,$bytesPerLine,$height,1,');
  for (int y = 0; y < lines.length; y++) {
    final result = List<int>.filled(bytesPerLine, 0);
    final row = lines[y];
    for (int i = 0; i < row.length; i++) {
      if (row[i]) {
        final byteIdx = i ~/ 8;
        final bitIdx = 7 - (i % 8);
        result[byteIdx] |= (1 << bitIdx);
      }
    }
    cmd.addAll(result);
  }
  addCrlf();
  addStr('PRINT 1,1');
  addCrlf();
  return cmd;
}

// ---------------------------------------------------------------------------

/// Builds the binary command sequences that wrap a raster image for
/// transmission to a thermal printer.
///
/// Two protocols are supported:
///
/// [PrinterProtocol.escPos] / [PrinterProtocol.auto]
///   Outputs ESC/POS GS v 0 (raster bit-image) commands.
///   Supported by the vast majority of thermal receipt printers.
///
/// [PrinterProtocol.tspl]
///   Outputs a TSPL label command sequence with a raster image.
///   Required for TSC label printers.
///
/// The caller provides raw PNG [imageBytes].  This class decodes the image
/// and generates the corresponding binary payload.
///
/// NOTE: For maximum Arabic fidelity the image is produced by
/// [ThermalInvoiceRenderer] which rasterises the Flutter widget tree
/// (including Arabic text) to a PNG before this step.
class ThermalCommandBuilder {
  ThermalCommandBuilder._();

  static const thermalThreshold = 220;

  // --------------------------------------------------------------------------
  // Public entry point
  // --------------------------------------------------------------------------

  /// Build the print command blocks from PNG [imageBytes] for [profile].
  ///
  /// For ESC/POS receipts, splits the image vertically into fixed-height blocks
  /// (default 256 rows).
  /// This prevents the printer firmware's raster decoder buffer from overflowing.
  static Future<List<List<int>>> buildPrintCommandBlocks({
    required Uint8List imageBytes,
    required PrinterProfile profile,
    int blockHeight = 256,
  }) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final width = image.width;
    final height = image.height;

    // Get raw RGBA pixel data (main isolate — GPU readback only, fast).
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw StateError(
        'Failed to get pixel data from rasterised invoice image',
      );
    }

    final pixels = byteData.buffer.asUint8List();

    // Resolve protocol before entering the isolate so we don't need to
    // pass a non-primitive type across the isolate boundary.
    final protocol = profile.protocol == PrinterProtocol.auto
        ? PrinterProtocol.escPos
        : profile.protocol;

    // Offload CPU-heavy RGBA→monochrome conversion + block packing to a
    // background isolate so the UI thread stays responsive.
    return compute(
      _buildBlocksInIsolate,
      _MonochromeArgs(
        pixels: pixels,
        width: width,
        height: height,
        protocol: protocol,
        blockHeight: blockHeight,
        paperWidthMm: profile.paperWidth.mm,
        threshold: thermalThreshold,
      ),
    );
  }

  /// Build the full print command payload from PNG [imageBytes] for [profile].
  ///
  /// Returns a concatenated list of raw bytes.
  static Future<List<int>> buildPrintCommand({
    required Uint8List imageBytes,
    required PrinterProfile profile,
    int blockHeight = 256,
  }) async {
    final blocks = await buildPrintCommandBlocks(
      imageBytes: imageBytes,
      profile: profile,
      blockHeight: blockHeight,
    );
    return blocks.expand((b) => b).toList();
  }

  // --------------------------------------------------------------------------
  // ESC/POS – GS v 0 Raster Bit Image
  // --------------------------------------------------------------------------

  static List<int> _buildEscPosCommand(
    List<List<bool>> monoLines,
    int width,
    int height, {
    bool includeCut = true,
  }) {
    final widthBytes = (width + 7) ~/ 8;
    if (monoLines.length != height ||
        monoLines.any((line) => line.length != width)) {
      throw ArgumentError('Raster rows do not match image dimensions');
    }

    final header = <int>[
      0x1B, 0x40, // ESC @
      0x1B, 0x33, 0x00, // ESC 3 0
      0x1B, 0x61, 0x01, // ESC a 1
      0x1D, 0x76, 0x30, 0x00, // GS v 0, mode 0
      widthBytes & 0xFF,
      (widthBytes >> 8) & 0xFF,
      height & 0xFF,
      (height >> 8) & 0xFF,
    ];

    final rasterPayload = <int>[];
    for (final line in monoLines) {
      rasterPayload.addAll(_packBitsLine(line, widthBytes));
    }

    final expectedRasterLength = widthBytes * height;
    if (rasterPayload.length != expectedRasterLength) {
      throw StateError(
        'Raster payload length ${rasterPayload.length} != '
        'expected $expectedRasterLength',
      );
    }

    final trailer = <int>[0x1B, 0x64, 0x05]; // ESC d 5
    if (includeCut) {
      trailer.addAll([0x1D, 0x56, 0x41]); // GS V A
    }
    return <int>[...header, ...rasterPayload, ...trailer];
  }

  /// Builds a raw ESC/POS raster from known monochrome rows.
  static List<int> buildEscPosRasterCommand({
    required List<List<bool>> rows,
    required int width,
    required int height,
    bool includeCut = true,
  }) {
    return _buildEscPosCommand(rows, width, height, includeCut: includeCut);
  }

  /// Builds a sequence of individual GS v 0 commands split vertically into fixed-height blocks.
  ///
  /// Each block contains at most [blockHeight] rows (default 256 rows).
  ///
  /// - The first block begins with ESC @ (init), ESC 3 0 (0-dot line spacing), and ESC a 1 (center).
  /// - Each block contains its own GS v 0 header (`1D 76 30 00 [xL] [xH] [yL] [yH]`) and packed raster rows.
  /// - The final block appends ESC d 5 (feed lines) without cutter.
  static List<List<int>> buildVerticallySplitEscPosRasterCommands({
    required List<List<bool>> rows,
    required int width,
    int blockHeight = 256,
  }) {
    final totalRows = rows.length;
    if (totalRows == 0) return const [];
    final widthBytes = (width + 7) ~/ 8;
    final blockCount = (totalRows + blockHeight - 1) ~/ blockHeight;
    final commands = <List<int>>[];

    for (var b = 0; b < blockCount; b++) {
      final startY = b * blockHeight;
      final endY = (startY + blockHeight).clamp(0, totalRows);
      final currentBlockHeight = endY - startY;
      final blockRows = rows.sublist(startY, endY);

      final cmd = <int>[];
      // Only the first block initializes printer & sets 0-dot line spacing
      if (b == 0) {
        cmd.addAll([
          0x1B, 0x40, // ESC @
          0x1B,
          0x33,
          0x00, // ESC 3 0 (0-dot line spacing ensures seamless stitching)
          0x1B, 0x61, 0x01, // ESC a 1 (Center)
        ]);
      }

      // GS v 0 header for this block
      cmd.addAll([
        0x1D, 0x76, 0x30, 0x00, // GS v 0, mode 0
        widthBytes & 0xFF,
        (widthBytes >> 8) & 0xFF,
        currentBlockHeight & 0xFF,
        (currentBlockHeight >> 8) & 0xFF,
      ]);

      // Raster payload for this block
      for (final line in blockRows) {
        cmd.addAll(_packBitsLine(line, widthBytes));
      }

      // Only the last block feeds paper (no cutter)
      if (b == blockCount - 1) {
        cmd.addAll([0x1B, 0x64, 0x05]); // ESC d 5
      }

      commands.add(cmd);
    }

    return commands;
  }

  // --------------------------------------------------------------------------
  // Pixel helpers
  // --------------------------------------------------------------------------

  /// Pack a boolean list into [bytesPerLine] bytes, MSB first.
  static List<int> _packBitsLine(List<bool> bits, int bytesPerLine) {
    final result = List<int>.filled(bytesPerLine, 0);
    for (int i = 0; i < bits.length; i++) {
      if (bits[i]) {
        final byteIdx = i ~/ 8;
        final bitIdx = 7 - (i % 8); // MSB first
        result[byteIdx] |= (1 << bitIdx);
      }
    }
    return result;
  }
}
