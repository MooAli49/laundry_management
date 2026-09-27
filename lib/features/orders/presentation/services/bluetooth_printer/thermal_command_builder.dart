import 'dart:developer' as dev;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'printer_profile.dart';

enum DiagnosticRasterFormat { gsV0, gsL }

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

  // --------------------------------------------------------------------------
  // Public entry point
  // --------------------------------------------------------------------------

  /// Build the full print command payload from PNG [imageBytes] for [profile].
  ///
  /// Returns a list of raw bytes ready to be sent via [BluetoothPrinterService.writeBytes].
  static Future<List<int>> buildPrintCommand({
    required Uint8List imageBytes,
    required PrinterProfile profile,
  }) async {
    final stopwatch = Stopwatch()..start();
    dev.log(
      'PRINT COMMAND BUILD START protocol=${profile.protocol.name}',
      name: 'BluetoothPrinterService',
    );
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final width = image.width;
    final height = image.height;

    // Get raw RGBA pixel data
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw StateError(
        'Failed to get pixel data from rasterised invoice image',
      );
    }

    final pixels = byteData.buffer.asUint8List();

    // Convert RGBA to 1-bit monochrome bitmap (threshold: pixel luminance < 128 → black)
    final monoBytes = _rgbaToMonochrome(pixels, width, height);

    final protocol = profile.protocol == PrinterProtocol.auto
        ? PrinterProtocol.escPos
        : profile.protocol;
    dev.log(
      'PRINT COMMAND BUILD imageWidth=$width imageHeight=$height '
      'selectedProtocol=${protocol.name} autoResolvedTo=${profile.protocol == PrinterProtocol.auto ? 'escPos' : 'none'}',
      name: 'BluetoothPrinterService',
    );

    final command = switch (protocol) {
      PrinterProtocol.tspl => _buildTsplCommand(
        monoBytes,
        width,
        height,
        profile,
      ),
      PrinterProtocol.escPos ||
      PrinterProtocol.auto => _buildEscPosCommand(monoBytes, width, height),
    };
    final widthBytes = (width + 7) ~/ 8;
    final rasterPayloadLength = widthBytes * height;
    dev.log(
      'PRINT COMMAND BUILD SUCCESS commandType=${protocol == PrinterProtocol.tspl ? 'TSPL' : 'ESC/POS'} '
      'imageWidth=$width imageHeight=$height widthBytes=$widthBytes '
      'rasterPayloadLength=$rasterPayloadLength rows=$height '
      'totalCommandLength=${command.length} first32Hex=${_hex(command.take(32).toList())} '
      'firstRowHex=${_hex(command.skip(8).take(widthBytes).toList())} '
      'durationMs=${stopwatch.elapsedMilliseconds}',
      name: 'BluetoothPrinterService',
    );
    return command;
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
    final command = <int>[...header, ...rasterPayload, ...trailer];
    dev.log(
      'PRINT RASTER headerHex=${_hex(header)} '
      'rasterFirst32Hex=${_hex(rasterPayload.take(32).toList())} '
      'rasterFirstRowHex=${_hex(rasterPayload.take(widthBytes).toList())} '
      'rasterLastRowHex=${_hex(rasterPayload.skip(expectedRasterLength - widthBytes).toList())} '
      'widthPixels=$width heightPixels=$height widthBytes=$widthBytes '
      'rasterPayloadLength=${rasterPayload.length} '
      'expectedRasterLength=$expectedRasterLength '
      'actualRasterLength=${rasterPayload.length} rows=$height '
      'totalCommandLength=${command.length}',
      name: 'BluetoothPrinterService',
    );
    return command;
  }

  /// Builds a raw ESC/POS raster from known monochrome rows for diagnostics/tests.
  static List<int> buildEscPosRasterCommand({
    required List<List<bool>> rows,
    required int width,
    required int height,
    bool includeCut = true,
  }) {
    return _buildEscPosCommand(rows, width, height, includeCut: includeCut);
  }

  /// Builds a small deterministic ESC/POS raster for printer diagnostics.
  /// The bitmap contains a border, crosshair, and ASCII-like block pattern.
  static List<int> buildDiagnosticRasterCommand() {
    const width = 128;
    const height = 64;
    final lines = _buildDiagnosticRows(width, height);
    final command = _buildEscPosCommand(
      lines,
      width,
      height,
      includeCut: false,
    );
    dev.log(
      'PRINT DIAGNOSTIC RASTER imageWidth=$width imageHeight=$height '
      'widthBytes=${(width + 7) ~/ 8} rasterPayloadLength=${((width + 7) ~/ 8) * height} '
      'headerHex=${_hex(command.take(16).toList())} '
      'rasterFirstRowHex=${_hex(command.skip(16).take((width + 7) ~/ 8).toList())} '
      'totalCommandLength=${command.length} rows=$height',
      name: 'BluetoothPrinterService',
    );
    return command;
  }

  static List<int> buildDiagnosticGsLCommand() {
    const width = 128;
    const height = 64;
    final rows = _buildDiagnosticRows(width, height);
    final widthBytes = (width + 7) ~/ 8;
    final rasterPayload = <int>[];
    for (final row in rows) {
      rasterPayload.addAll(_packBitsLine(row, widthBytes));
    }

    final dataLength = 10 + rasterPayload.length;
    final dataCommand = <int>[
      0x1D,
      0x28,
      0x4C,
      dataLength & 0xFF,
      (dataLength >> 8) & 0xFF,
      0x30,
      0x00,
      0x30,
      0x00,
      widthBytes & 0xFF,
      (widthBytes >> 8) & 0xFF,
      height & 0xFF,
      (height >> 8) & 0xFF,
      ...rasterPayload,
    ];
    final printCommand = <int>[0x1D, 0x28, 0x4C, 0x02, 0x00, 0x31, 0x45, 0x00];
    final trailer = <int>[0x1B, 0x64, 0x05];
    final command = [...dataCommand, ...printCommand, ...trailer];
    dev.log(
      'DIAGNOSTIC FORMAT=GS_L commandLength=${command.length} '
      'headerHex=${_hex(dataCommand.take(13).toList())} '
      'payloadLength=${rasterPayload.length}',
      name: 'BluetoothPrinterService',
    );
    return command;
  }

  static List<List<bool>> _buildDiagnosticRows(int width, int height) {
    return List<List<bool>>.generate(height, (y) {
      return List<bool>.generate(width, (x) {
        final border = x == 0 || x == width - 1 || y == 0 || y == height - 1;
        final crosshair = x == width ~/ 2 || y == height ~/ 2;
        final blocks =
            (x >= 16 && x < 48 && y >= 16 && y < 32) ||
            (x >= 80 && x < 112 && y >= 32 && y < 48);
        return border || crosshair || blocks;
      });
    });
  }

  // --------------------------------------------------------------------------
  // TSPL – BITMAP command
  // --------------------------------------------------------------------------

  static List<int> _buildTsplCommand(
    List<List<bool>> monoLines,
    int width,
    int height,
    PrinterProfile profile,
  ) {
    final cmd = <int>[];
    final paperMm = profile.paperWidth.mm;

    void addStr(String s) => cmd.addAll(s.codeUnits);
    void addCrlf() => cmd.addAll([0x0D, 0x0A]);

    // Set label size (width, max-height in mm)
    addStr('SIZE $paperMm mm, 200 mm');
    addCrlf();
    addStr('GAP 0 mm, 0 mm');
    addCrlf();
    addStr('CLS');
    addCrlf();

    // BITMAP x,y,width_bytes,height,mode,data
    // mode: 0=overwrite, 1=OR, 2=XOR, 3=AND
    final bytesPerLine = (width + 7) ~/ 8;
    addStr('BITMAP 0,0,$bytesPerLine,$height,1,');

    // Pack bits
    for (int y = 0; y < monoLines.length; y++) {
      final lineBytes = _packBitsLine(monoLines[y], bytesPerLine);
      cmd.addAll(lineBytes);
    }
    addCrlf();

    // Print one label
    addStr('PRINT 1,1');
    addCrlf();

    return cmd;
  }

  // --------------------------------------------------------------------------
  // Pixel helpers
  // --------------------------------------------------------------------------

  /// Convert RGBA flat array into a list-of-boolean-lines (black=true).
  static List<List<bool>> _rgbaToMonochrome(
    Uint8List pixels,
    int width,
    int height,
  ) {
    final lines = <List<bool>>[];
    for (int y = 0; y < height; y++) {
      final line = <bool>[];
      for (int x = 0; x < width; x++) {
        final idx = (y * width + x) * 4;
        final r = pixels[idx];
        final g = pixels[idx + 1];
        final b = pixels[idx + 2];
        // Luminance (BT.601 approximation)
        final lum = (0.299 * r + 0.587 * g + 0.114 * b).round();
        // Black pixel if luminance < 128
        line.add(lum < 128);
      }
      lines.add(line);
    }
    return lines;
  }

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

  static String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
}
