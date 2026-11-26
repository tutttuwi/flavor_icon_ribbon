import 'package:image/image.dart';

/// 5×7 dot glyphs for ribbon labels.
///
/// A bundled bitmap font is fixed at 48 px and collapses when scaled down.
/// These glyphs store only the letters used on labels, at an integer pixel
/// thickness, and are drawn at an integer multiple of the output size. Even
/// mdpi (48 px) keeps a stroke of at least 1 px.
///
/// To support another letter, add a 5×7 glyph to [_glyphs].
const labelGlyphColumns = 5;
const labelGlyphRows = 7;

/// Dots of space between glyphs.
const _glyphGap = 1;

const _glyphs = <String, List<String>>{
  'D': ['####.', '#...#', '#...#', '#...#', '#...#', '#...#', '####.'],
  'E': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
  'G': ['.###.', '#...#', '#....', '#.###', '#...#', '#...#', '.###.'],
  'S': ['.####', '#....', '#....', '.###.', '....#', '....#', '####.'],
  'T': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
  'V': ['#...#', '#...#', '#...#', '#...#', '#...#', '.#.#.', '..#..'],
  'A': ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
  'B': ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'],
  'C': ['.###.', '#...#', '#....', '#....', '#....', '#...#', '.###.'],
  'F': ['#####', '#....', '#....', '####.', '#....', '#....', '#....'],
  'H': ['#...#', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
  'I': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '#####'],
  'J': ['..###', '...#.', '...#.', '...#.', '#..#.', '#..#.', '.##..'],
  'K': ['#...#', '#..#.', '#.#..', '##...', '#.#..', '#..#.', '#...#'],
  'L': ['#....', '#....', '#....', '#....', '#....', '#....', '#####'],
  'M': ['#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'],
  'N': ['#...#', '##..#', '##..#', '#.#.#', '#..##', '#..##', '#...#'],
  'O': ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
  'P': ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....'],
  'Q': ['.###.', '#...#', '#...#', '#...#', '#.#.#', '#..#.', '.##.#'],
  'R': ['####.', '#...#', '#...#', '####.', '#.#..', '#..#.', '#...#'],
  'U': ['#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
  'W': ['#...#', '#...#', '#...#', '#.#.#', '#.#.#', '##.##', '#...#'],
  'X': ['#...#', '#...#', '.#.#.', '..#..', '.#.#.', '#...#', '#...#'],
  'Y': ['#...#', '#...#', '.#.#.', '..#..', '..#..', '..#..', '..#..'],
  'Z': ['#####', '....#', '...#.', '..#..', '.#...', '#....', '#####'],
};

/// Width, in dots, needed to draw [text].
///
/// Throws [ArgumentError] when [text] contains a character with no glyph.
int labelColumns(String text) {
  if (text.isEmpty) return 0;
  for (final char in text.split('')) {
    if (!_glyphs.containsKey(char)) {
      throw ArgumentError.value(
        text,
        'text',
        'No glyph for "$char" in flavor_icon_label_font.dart',
      );
    }
  }
  return text.length * labelGlyphColumns + (text.length - 1) * _glyphGap;
}

/// Horizontal image of [text] at [scale] pixels per dot, on a transparent
/// background.
///
/// Returns `null` when [text] is empty.
Image? renderDotLabel(String text, {required int scale, required Color color}) {
  final columns = labelColumns(text);
  if (columns == 0) return null;

  final image = Image(
    width: columns * scale,
    height: labelGlyphRows * scale,
    numChannels: 4,
  );
  // Paint transparent pixels in the label color at alpha 0. Leaving them black
  // makes rotation interpolation darken the glyph edges.
  fill(
    image,
    color: ColorRgba8(color.r.toInt(), color.g.toInt(), color.b.toInt(), 0),
  );
  var left = 0;
  for (final char in text.split('')) {
    final rows = _glyphs[char]!;
    for (var row = 0; row < labelGlyphRows; row++) {
      for (var col = 0; col < labelGlyphColumns; col++) {
        if (rows[row][col] != '#') continue;
        fillRect(
          image,
          x1: (left + col) * scale,
          y1: row * scale,
          x2: (left + col + 1) * scale - 1,
          y2: (row + 1) * scale - 1,
          color: color,
        );
      }
    }
    left += labelGlyphColumns + _glyphGap;
  }
  return image;
}
