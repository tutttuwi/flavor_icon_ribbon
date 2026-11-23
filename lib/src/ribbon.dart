import 'dart:math' as math;

import 'package:image/image.dart';

import 'flavor_icon_label_font.dart';

/// flavor ごとのリボン意匠。
///

class RibbonStyle {
  RibbonStyle({
    required this.label,
    required this.background,
    Color? foreground,
  }) : foreground = foreground ?? ColorRgba8(255, 255, 255, 255);

  /// 帯に描く文字列。`flavor_icon_label_font.dart` にある大文字だけを描ける。
  final String label;

  /// 帯の塗り色。
  final Color background;

  /// 文字色。
  final Color foreground;
}

/// マスタアイコンの一辺（px）。リボン無し（prod）の縮小元。
/// リボン付きは出力先の解像度ごとに描く。
const masterIconSize = 1024;

/// リボンの寸法（すべて px）。距離は右下隅から対角線方向に測る。
class RibbonLayout {
  const RibbonLayout({
    required this.bandThickness,
    required this.bandCenterOffset,
    required this.labelHeight,
    required this.labelWidth,
    required this.labelCenterOffset,
  });

  /// 帯の太さ。
  final double bandThickness;

  /// 隅から帯の中心線までの距離。帯の外側は隅に接する（= 太さの半分）。
  final double bandCenterOffset;

  /// ラベルの高さと幅（ドット文字。整数 px）。
  final double labelHeight;
  final double labelWidth;

  /// 隅からラベルの中心までの距離。帯の中心より内側（アイコンの中心寄り）。
  final double labelCenterOffset;
}

/// 一辺 [size] のアイコンに [style] のリボンを描くときの寸法。
///
/// 帯を隅に付けると、帯の中心線で使える長さは短くなる（隅に近いほど弦が短い）。
/// そこで帯を太くし、ラベルを帯の内側寄りに置いて、ラベルの外側の端でも弦の長さが
/// 足りるようにする。
RibbonLayout ribbonLayout(RibbonStyle style, {int size = masterIconSize}) {
  final thickness = size * _bandHeight;
  final bandCenter = thickness / 2;
  final labelCenter = bandCenter + thickness * _labelShift;

  // ラベルの 1 ドットは整数 px にする（小さい出力でも線幅が 1px 以上になる）。
  // 目標の高さから始めて、隅側の端での弦の長さに収まる最大の倍率を探す。
  // 隅から距離 d の位置で正方形を -45° に切った弦の長さは 2d。
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

/// [base] の右下隅に [style] のリボンを合成した新しい画像を返す。
///
/// [base] は変更しない。返り値は一辺 [size] の正方形。
/// [base] の透過部分（角丸など）にはリボンがはみ出さないよう、合成後に元の
/// アルファをマスクとして再適用する。
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

  // ラベルは横向きに描いてから -45° 回転し、隅から labelCenterOffset の位置に
  // 中心を合わせて重ねる。回転後に描くと文字自体が斜めに歪むため。
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

/// 帯の太さ（アイコン一辺に対する比率）。帯の外側は右下の隅に接する。
const _bandHeight = 0.40;

/// ラベルの中心を帯の中心からどれだけ内側へずらすか（帯の太さに対する比率）。
const _labelShift = 0.25;

/// ラベルの高さ（帯の太さに対する比率。フォントの行の高さ基準）。
const _labelHeightRatio = 0.40;

/// 弦の長さのうちラベルに使う割合（両端の余白）。
const _labelWidthMargin = 0.85;

/// [image] を一辺 [size] の正方形へ正規化する（既にその寸法なら複製のみ）。
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

/// 右下隅から対角線方向に帯の太さまでの範囲を [style] の帯色で塗る。
///
/// 帯の外側は隅に接するので、形は右下の三角形になる。境界の 1px は距離に応じて
/// 不透明度を下げ、ギザギザを抑える。
void _fillBand(Image master, RibbonStyle style, RibbonLayout layout) {
  final size = master.width;
  final color = style.background;
  final reach = layout.bandThickness * math.sqrt2;
  final start = math.max(0, (size - reach).floor() - 1);
  for (var y = start; y < size; y++) {
    for (var x = start; x < size; x++) {
      // 隅 (size, size) から対角線方向に測った距離（ピクセル中心で評価）。
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

/// [layout] の整数倍で [style] のドット文字を横向きに描いた画像（透明背景）。
Image? _renderLabel(RibbonStyle style, RibbonLayout layout) {
  if (labelColumns(style.label) <= 0) return null;
  final scale = math.max(1, (layout.labelHeight / labelGlyphRows).round());
  return renderDotLabel(style.label, scale: scale, color: style.foreground);
}

/// [target] のアルファを [mask] のアルファで抑える（元画像の形からはみ出させない）。
Image _applyAlphaMask(Image target, Image mask) {
  for (final pixel in target) {
    final maskAlpha = mask.getPixel(pixel.x, pixel.y).a;
    if (maskAlpha < pixel.a) {
      pixel.a = maskAlpha;
    }
  }
  return target;
}
