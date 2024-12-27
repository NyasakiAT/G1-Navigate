import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

Future<Uint8List> generateNavigationBMP(String maneuver, double distance) async {
  const canvasWidth = 576;
  const canvasHeight = 136;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  final headerSize = 14 + 40 + 8;

  // Draw background (black)
  final backgroundPaint = ui.Paint()..color = const ui.Color(0xFF000000);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()), backgroundPaint);

  // Draw icon
  final iconData = await _loadManeuverIcon(maneuver);
  if (iconData != null) {
    final ui.Image image = await decodeImage(iconData);
    final iconSize = 50.0;
    final iconRect = ui.Rect.fromCenter(
      center: ui.Offset(canvasWidth / 2, canvasHeight / 3),
      width: iconSize,
      height: iconSize,
    );
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      iconRect,
      ui.Paint(),
    );
  }

  // Draw distance text in white
  final textStyle = ui.TextStyle(color: ui.Color(0xFFFFFFFF), fontSize: 24);
  final paragraphStyle = ui.ParagraphStyle(textAlign: ui.TextAlign.center);
  final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
    ..pushStyle(textStyle)
    ..addText("${distance.toStringAsFixed(1)} m");
  final paragraph = paragraphBuilder.build()
    ..layout(ui.ParagraphConstraints(width: canvasWidth.toDouble()));
  canvas.drawParagraph(paragraph, ui.Offset(0, canvasHeight * 0.7));

  // Convert to an image
  final picture = recorder.endRecording();
  final image = await picture.toImage(canvasWidth, canvasHeight);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final rgbaData = byteData!.buffer.asUint8List();

  // Convert RGBA to 1-bit monochrome (0=black, 1=white)
  final bmpData = _convertRgbaTo1Bit(rgbaData, canvasWidth, canvasHeight);

  // Build the BMP headers and combine
  final bmpBytes = _build1BitBmp(canvasWidth, canvasHeight, bmpData);

  // Copy over the header & palette as-is
  Uint8List output = Uint8List.fromList(bmpBytes);

  // Invert *only* the pixel data after headerSize
  for (int i = headerSize; i < output.length; i++) {
    output[i] = 255 - output[i];
  }

  return output;
}

// Load and decode image
Future<ui.Image> decodeImage(Uint8List imageData) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(imageData, completer.complete);
  return completer.future;
}

Future<Uint8List?> _loadManeuverIcon(String maneuver) async {
  final iconPath = 'assets/icons/$maneuver.png';
  try {
    final data = await rootBundle.load(iconPath);
    return data.buffer.asUint8List();
  } catch (e) {
    print("Error loading icon: $e");
    return null;
  }
}

/// Convert RGBA to 1-bit (threshold at ~50% brightness)
Uint8List _convertRgbaTo1Bit(Uint8List rgba, int width, int height) {
  // padded row size in bytes
  final rowSize = ((1 * width + 31) ~/ 32) * 4;  // how many bytes per row
  final output = Uint8List(rowSize * height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final rgbaIndex = (y * width + x) * 4;
      final r = rgba[rgbaIndex + 0];
      final g = rgba[rgbaIndex + 1];
      final b = rgba[rgbaIndex + 2];
      final brightness = (r + g + b) / 3;
      final bit = brightness > 128 ? 1 : 0;

      // Where to write
      final invertedY = (height - 1 - y);
      final rowStart = invertedY * rowSize;
      final byteIndex = rowStart + (x ~/ 8);
      final bitOffset = 7 - (x % 8);
      output[byteIndex] |= (bit << bitOffset);
    }
  }
  return output;
}

/// Build a 1-bit BMP file with a monochrome palette
Uint8List _build1BitBmp(int width, int height, Uint8List bmpData) {
  final fileHeaderSize = 14;
  final infoHeaderSize = 40;
  final paletteSize = 8;    // 2 colors * 4 bytes each
  final headerSize = fileHeaderSize + infoHeaderSize + paletteSize;

  final fileSize = headerSize + bmpData.length;

  // --- File header (14 bytes) ---
  final fileHeader = Uint8List(fileHeaderSize);
  fileHeader[0] = 0x42; // 'B'
  fileHeader[1] = 0x4D; // 'M'
  fileHeader[2] = fileSize & 0xFF;
  fileHeader[3] = (fileSize >> 8) & 0xFF;
  fileHeader[4] = (fileSize >> 16) & 0xFF;
  fileHeader[5] = (fileSize >> 24) & 0xFF;
  fileHeader[10] = headerSize; // offset to pixel data (14+40+8=62)

  // --- Info header (40 bytes) ---
  final infoHeader = Uint8List(infoHeaderSize);
  infoHeader[0] = infoHeaderSize;         // header size
  infoHeader[4] = width & 0xFF;           // width
  infoHeader[5] = (width >> 8) & 0xFF;
  infoHeader[6] = (width >> 16) & 0xFF;
  infoHeader[7] = (width >> 24) & 0xFF;
  infoHeader[8] = height & 0xFF;          // height
  infoHeader[9] = (height >> 8) & 0xFF;
  infoHeader[10] = (height >> 16) & 0xFF;
  infoHeader[11] = (height >> 24) & 0xFF;
  infoHeader[12] = 1; // planes
  infoHeader[14] = 1; // bits per pixel (1-bit)

  // (You may also want to set compression = 0, sizeImage, XPelsPerMeter,
  // YPelsPerMeter, clrUsed, etc. but minimal is enough for many viewers)

  // --- Palette (8 bytes) ---
  final palette = Uint8List.fromList([
    0x00, 0x00, 0x00, 0x00, // color #0 = black
    0xFF, 0xFF, 0xFF, 0x00, // color #1 = white
  ]);

  // Combine
  final bmpBytes = Uint8List(fileSize);
  bmpBytes.setRange(0, fileHeaderSize, fileHeader);
  bmpBytes.setRange(fileHeaderSize, fileHeaderSize + infoHeaderSize, infoHeader);
  bmpBytes.setRange(
    fileHeaderSize + infoHeaderSize,
    fileHeaderSize + infoHeaderSize + paletteSize,
    palette,
  );
  bmpBytes.setRange(headerSize, fileSize, bmpData);

  return bmpBytes;
}

Uint8List _int32le(int value) {
  final b = Uint8List(4);
  final bd = b.buffer.asByteData();
  bd.setInt32(0, value, Endian.little);
  return b;
}

Uint8List _int16le(int value) {
  final b = Uint8List(2);
  final bd = b.buffer.asByteData();
  bd.setInt16(0, value, Endian.little);
  return b;
}
