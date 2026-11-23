import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:flavor_icon_ribbon/src/generator.dart';

void main() {
  late Directory root;
  late File config, android, ios;
  File file(String path) =>
      File('${root.path}/$path')..createSync(recursive: true);
  void png(File target, int size, int red) {
    final image = img.Image(width: size, height: size);
    img.fill(image, color: img.ColorRgb8(red, 10, 100));
    target.writeAsBytesSync(img.encodePng(image));
  }

  int run({bool check = false}) => generate(config, check: check, log: (_) {});
  const catalog = 'ios/Runner/Assets.xcassets/AppIcon-qa.appiconset';
  setUp(() {
    root = Directory.systemTemp.createTempSync('flavor-icons-test');
    png(file('logo.png'), 80, 150);
    android = file('android/app/src/qa/res/mipmap-mdpi/ic_launcher.png');
    ios = file('$catalog/Icon.png');
    png(android, 48, 0);
    png(ios, 60, 0);
    file('$catalog/Contents.json').writeAsStringSync(
      jsonEncode({
        'images': [
          {'filename': 'Icon.png'},
        ],
      }),
    );
    config = file('flavor_icon_ribbon.yaml')
      ..writeAsStringSync(
        'source: logo.png\nflavors:\n  qa:\n    label: QA\n    ios_set: $catalog\n',
      );
  });
  tearDown(() => root.deleteSync(recursive: true));
  test('checks without writing, generates, and is idempotent', () {
    final before = android.readAsBytesSync();
    expect(run(check: true), 2);
    expect(android.readAsBytesSync(), before);
    expect(run(), 2);
    expect(run(check: true), 0);
    expect(run(), 0);
    final result = img.decodePng(android.readAsBytesSync())!;
    expect(result.width, 48);
    expect(result.getPixel(47, 47).r, 249);
    expect(result.getPixel(0, 0).r, 150);
  });
  test('iOS flattens transparency while Android preserves it', () {
    final base = img.Image(width: 80, height: 80, numChannels: 4);
    file('logo.png').writeAsBytesSync(img.encodePng(base));
    run();
    final apple = img.decodePng(ios.readAsBytesSync())!;
    expect(apple.hasAlpha, isFalse);
    expect(apple.getPixel(0, 0).r, 255);
    expect(img.decodePng(android.readAsBytesSync())!.getPixel(0, 0).a, 0);
  });
  test('a missing density override cannot silently fall back to main', () {
    png(file('android/app/src/main/res/mipmap-hdpi/ic_launcher.png'), 72, 0);
    expect(run, throwsFormatException);
  });
  test('missing flavor or platform stops before all writes', () {
    ios.deleteSync();
    final before = android.readAsBytesSync();
    expect(run, throwsA(isA<FileSystemException>()));
    expect(android.readAsBytesSync(), before);
  });
  test('skips unassigned catalog artwork', () {
    final extra = file('$catalog/design.png');
    png(extra, 72, 90);
    final original = extra.readAsBytesSync();
    expect(run(), 2);
    expect(extra.readAsBytesSync(), original);
  });
  test('rejects adaptive icons inherited from main', () {
    file('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml');
    expect(run, throwsFormatException);
  });
  test('rejects appearance assets before touching Android', () {
    final before = android.readAsBytesSync();
    file('$catalog/Contents.json').writeAsStringSync(
      '{"images":[{"filename":"Icon.png","appearances":[]}]}',
    );
    expect(run, throwsFormatException);
    expect(android.readAsBytesSync(), before);
  });
  test('explicit null label keeps production artwork', () {
    config.writeAsStringSync(
      config.readAsStringSync().replaceFirst('label: QA', 'label: null'),
    );
    run();
    expect(img.decodePng(android.readAsBytesSync())!.getPixel(47, 47).r, 150);
  });
  test('rejects shared outputs before writing', () {
    config.writeAsStringSync(
      'source: logo.png\nplatforms: [ios]\nflavors:\n  a: {label: QA, ios_set: $catalog}\n  b: {label: UAT, ios_set: $catalog}',
    );
    expect(run, throwsFormatException);
  });
  test('unsupported text and traversal fail validation', () {
    final original = config.readAsStringSync();
    config.writeAsStringSync(original.replaceFirst('QA', '日本語'));
    expect(run, throwsFormatException);
    config.writeAsStringSync(original.replaceFirst('logo.png', '../logo.png'));
    expect(run, throwsFormatException);
  });
}
