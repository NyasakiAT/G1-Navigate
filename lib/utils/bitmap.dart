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

  // Draw background (black)
  final backgroundPaint = ui.Paint()..color = const ui.Color(0xFF000000);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, canvasWidth.toDouble(), canvasHeight.toDouble()), backgroundPaint);

  // Draw icon
  final iconData = await _loadManeuverIcon(maneuver);
  if (iconData != null) {
    final ui.Image image = await decodeImage(iconData);
    final iconSize = 80.0;
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

  Uint8List invertedBitmap = Uint8List(bmpBytes.length);
  for (int i = 0; i < bmpBytes.length; i++) {
    invertedBitmap[i] = 255 - bmpBytes[i];
  }

  return invertedBitmap;
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
  final bytesPerRow = width ~/ 8;
  final output = Uint8List(bytesPerRow * height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final index = (y * width + x) * 4;
      final r = rgba[index];
      final g = rgba[index + 1];
      final b = rgba[index + 2];

      final brightness = (r + g + b) / 3;
      final bit = brightness > 128 ? 1 : 0;

      final invertedY = (height - 1 - y);
      final outRowStart = invertedY * bytesPerRow;
      final byteIndex = outRowStart + (x ~/ 8);
      final bitOffset = 7 - (x % 8);
      output[byteIndex] |= (bit << bitOffset);
    }
  }
  return output;
}

/// Build a 1-bit BMP file with a monochrome palette
Uint8List _build1BitBmp(int width, int height, Uint8List bmpData) {
  final headerSize = 62;
  final bytesPerRow = width ~/ 8;
  final imageSize = bytesPerRow * height;
  final fileSize = headerSize + imageSize;

  final file = BytesBuilder();

  file.addByte(0x42); // 'B'
  file.addByte(0x4D); // 'M'
  file.add(_int32le(fileSize));
  file.add(_int16le(0)); // reserved
  file.add(_int16le(0)); // reserved
  file.add(_int32le(headerSize)); // offset to pixels

  file.add(_int32le(40)); // biSize
  file.add(_int32le(width));
  file.add(_int32le(height));
  file.add(_int16le(1));
  file.add(_int16le(1));
  file.add(_int32le(0));
  file.add(_int32le(imageSize));
  file.add(_int32le(0));
  file.add(_int32le(0));
  file.add(_int32le(2));
  file.add(_int32le(2));

  file.add([0x00, 0x00, 0x00, 0x00]);
  file.add([0xFF, 0xFF, 0xFF, 0x00]);

  file.add(bmpData);

  return file.toBytes();
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
