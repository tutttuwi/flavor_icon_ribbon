import 'dart:math' as math;

import 'package:image/image.dart';

import 'flavor_icon_label_font.dart';

/// Colors and label for one environment ribbon.
class RibbonStyle {
  /// Creates a ribbon style.
  ///
  /// [label] is 1–3 letters from `A` to `Z`. [foreground] is white when omitted.
  RibbonStyle({
    required this.label,
    required this.background,
    Color? foreground,
  }) : foreground = foreground ?? ColorRgba8(255, 255, 255, 255);

  /// Text drawn on the band.
  ///
  /// Only the uppercase letters in `flavor_icon_label_font.dart` can be drawn.
  final String label;

  /// Fill color of the band.
  final Color background;

  /// Color of the label.
  final Color foreground;
}

/// Side length of the master icon, in pixels.
///
/// Unbadged flavors are scaled down from this size. Badged flavors are drawn
/// at each output resolution.
const masterIconSize = 1024;

/// Ribbon measurements, in pixels. Distances run along the diagonal from the
/// bottom-right corner.
class RibbonLayout {
  const RibbonLayout({
    required this.bandThickness,
    required this.bandCenterOffset,
    required this.labelHeight,
    required this.labelWidth,
    required this.labelCenterOffset,
  });

  /// Thickness of the band.
  final double bandThickness;

  /// Distance from the corner to the center line of the band.
  ///
  /// The outer edge of the band touches the corner, so this is half the
  /// thickness.
  final double bandCenterOffset;

  /// Label height and width, in integer pixels of the dot font.
  final double labelHeight;
  final double labelWidth;

  /// Distance from the corner to the center of the label.
  ///
  /// This sits inward of the band center, toward the middle of the icon.
  final double labelCenterOffset;
}

/// Layout for drawing [style] on an icon of side [size].
///
/// Placing the band against the corner shortens the usable length along its
/// center line, because the chord is shorter closer to the corner. The band
/// is therefore drawn thick, and the label sits toward the inner edge, so the
/// outer end of the label still fits on the chord.
RibbonLayout ribbonLayout(RibbonStyle style, {int size = masterIconSize}) {
  final thickness = size * _bandHeight;
  final bandCenter = thickness / 2;
  final labelCenter = bandCenter + thickness * _labelShift;

  // Each label dot is an integer number of pixels, so a small output still has
  // a stroke at least 1 px wide. Start from the target height and search
  // downward for the largest scale that fits the chord at the outer end.
  // A square cut at -45° has a chord of length 2d at distance d from the corner.
  final columns = labelColumns(style.label);
  var scale = math.max(
    1,
    (thickness * _labelHeightRatio / labelGlyphRows).floor(),
  );
  while (scale > 1) {
    final height = labelGlyphRows * scale.toDouble();
    final maxWidth = 2 * (labelCenter - height / 2) * _labelWidthMargin;
    if (columns * scale <= maxWidth) break;
    scale--;
  }
  return RibbonLayout(
    bandThickness: thickness,
    bandCenterOffset: bandCenter,
    labelHeight: (labelGlyphRows * scale).toDouble(),
    labelWidth: (columns * scale).toDouble(),
    labelCenterOffset: labelCenter,
  );
}

/// Returns a new square image with [style] drawn on the bottom-right of [base].
///
/// [base] is left unchanged. The result has side length [size], which defaults
/// to 1024. A non-positive [size], or a [RibbonStyle.label] that is
/// not 1–3 letters `A`–`Z`, throws [ArgumentError].
///
/// Sizes below 48 are drawn at 48 pixels and then downscaled, so the label
/// stroke is at least one pixel before scaling. After compositing, the original
/// alpha is reapplied as a mask, which keeps the ribbon inside transparent
/// regions such as rounded corners.
Image composeRibbonIcon(
  Image base,
  RibbonStyle style, {
  int size = masterIconSize,
}) {
  if (size <= 0) throw ArgumentError.value(size, 'size');
  if (!RegExp(r'^[A-Z]{1,3}$').hasMatch(style.label)) {
    throw ArgumentError.value(
      style.label,
      'label',
      'Use 1–3 uppercase letters.',
    );
  }
  // At very small catalog sizes even a one-pixel-wide stroke would clip.
  if (size < 48) {
    return copyResize(
      composeRibbonIcon(base, style, size: 48),
      width: size,
      height: size,
      interpolation: Interpolation.average,
    );
  }
  final master = _toSquare(base, size);
  final layout = ribbonLayout(style, size: size);

  _fillBand(master, style, layout);

  // Draw the label upright, rotate it by -45°, then center it
  // labelCenterOffset from the corner. Drawing after rotation would shear
  // the glyphs.
  final label = _renderLabel(style, layout);
  if (label != null) {
    final rotated = copyRotate(
      label,
      angle: -45,
      interpolation: Interpolation.linear,
    );
    final center = size - layout.labelCenterOffset / math.sqrt2;
    compositeImage(
      master,
      rotated,
      dstX: (center - rotated.width / 2).round(),
      dstY: (center - rotated.height / 2).round(),
    );
  }

  return _applyAlphaMask(master, _toSquare(base, size));
}

/// Band thickness as a fraction of the icon side. The outer edge meets the
/// bottom-right corner.
const _bandHeight = 0.40;

/// How far the label center moves inward from the band center, as a fraction
/// of the band thickness.
const _labelShift = 0.25;

/// Label height as a fraction of the band thickness. This is the target for
/// the font's row height.
const _labelHeightRatio = 0.40;

/// Fraction of the chord length used by the label. The rest is margin at both
/// ends.
const _labelWidthMargin = 0.85;

/// Normalizes [image] to a square of side [size].
///
/// An image that is already that size is only copied.
Image _toSquare(Image image, int size) {
  if (image.width == size && image.height == size) {
    return image.convert(numChannels: 4);
  }
  return copyResize(
    image.convert(numChannels: 4),
    width: size,
    height: size,
    interpolation: Interpolation.cubic,
  );
}

/// Fills the diagonal band of [style], from the bottom-right corner out to the
/// band thickness.
///
/// The outer edge meets the corner, so the shape is the bottom-right triangle.
/// The boundary pixel's opacity follows the remaining distance, which softens
/// the stair-step edge.
void _fillBand(Image master, RibbonStyle style, RibbonLayout layout) {
  final size = master.width;
  final color = style.background;
  final reach = layout.bandThickness * math.sqrt2;
  final start = math.max(0, (size - reach).floor() - 1);
  for (var y = start; y < size; y++) {
    for (var x = start; x < size; x++) {
      // Distance along the diagonal from the corner (size, size), measured at
      // the pixel center.
      final distance = ((size - x - 0.5) + (size - y - 0.5)) / math.sqrt2;
      final coverage = (layout.bandThickness - distance + 0.5).clamp(0.0, 1.0);
      if (coverage <= 0) continue;
      final pixel = master.getPixel(x, y);
      pixel
        ..r = pixel.r + (color.r - pixel.r) * coverage
        ..g = pixel.g + (color.g - pixel.g) * coverage
        ..b = pixel.b + (color.b - pixel.b) * coverage
        ..a = pixel.a + (color.a - pixel.a) * coverage;
    }
  }
}

/// Horizontal dot-font image of [style], scaled by the integer size in
/// [layout]. The background is transparent.
Image? _renderLabel(RibbonStyle style, RibbonLayout layout) {
  if (labelColumns(style.label) <= 0) return null;
  final scale = math.max(1, (layout.labelHeight / labelGlyphRows).round());
  return renderDotLabel(style.label, scale: scale, color: style.foreground);
}

/// Caps [target]'s alpha by [mask]'s alpha so the ribbon stays inside the
/// original image shape.
Image _applyAlphaMask(Image target, Image mask) {
  for (final pixel in target) {
    final maskAlpha = mask.getPixel(pixel.x, pixel.y).a;
    if (maskAlpha < pixel.a) {
      pixel.a = maskAlpha;
    }
  }
  return target;
}
