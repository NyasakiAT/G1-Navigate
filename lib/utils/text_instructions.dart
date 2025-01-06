import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import './navigation_icons.dart';

Future<String> generateNavigationText(String maneuver, double distance) async {
  String cleaned_maneuver = maneuver.replaceAll("-", "_");

  String maneuver_text = NavigationIcons.getIcon(cleaned_maneuver);

  return maneuver_text + "\n${distance.toStringAsFixed(0)} m";
}
