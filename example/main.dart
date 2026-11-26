import 'dart:io';

import 'package:flavor_icon_ribbon/flavor_icon_ribbon.dart';
import 'package:image/image.dart';

// Draws a DEV ribbon on a generated square icon.
//
// From the package root:
//
// dart run example/main.dart
void main() {
  final base = Image(width: 192, height: 192, numChannels: 4);
  fill(base, color: ColorRgb8(37, 99, 235));
  final icon = composeRibbonIcon(
    base,
    RibbonStyle(
      label: 'DEV',
      background: ColorRgb8(249, 115, 22),
      foreground: ColorRgb8(255, 255, 255),
    ),
    size: 192,
  );
  final output = File('icon-dev.png');
  output.writeAsBytesSync(encodePng(icon));
  stdout.writeln('Wrote ${output.path} (${icon.width}x${icon.height})');
}
