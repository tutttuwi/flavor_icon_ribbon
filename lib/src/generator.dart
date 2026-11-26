import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'ribbon.dart';

Never invalid(String message) => throw FormatException(message);

Map fields(dynamic value, Set<String> keys, String where) {
  if (value is! Map) invalid('Expected a mapping at $where.');
  for (final key in value.keys) {
    if (!keys.contains(key)) invalid('Unknown key at $where: $key');
  }
  return value;
}

String relativePath(dynamic value, String root) {
  if (value is! String ||
      value.isEmpty ||
      p.isAbsolute(value) ||
      p.split(value).contains('..')) {
    invalid('Expected a project-relative path: $value');
  }
  final path = p.normalize(p.join(root, value));
  var current = path;
  while (current != root) {
    if (FileSystemEntity.isLinkSync(current)) {
      invalid('Symbolic link: $current');
    }
    current = p.dirname(current);
  }
  return path;
}

img.Color color(dynamic value) {
  if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
    invalid('Expected a quoted #RRGGBB color, got $value.');
  }
  final rgb = int.parse(value.substring(1), radix: 16);
  return img.ColorRgb8(rgb >> 16, (rgb >> 8) & 255, rgb & 255);
}

const densities = [
  'ldpi',
  'mdpi',
  'tvdpi',
  'hdpi',
  'xhdpi',
  'xxhdpi',
  'xxxhdpi',
];

/// Only bitmap launcher resources have a well-defined replacement in v0.1.
List<File> androidTargets(String root, String name, Map config) {
  final res = relativePath(
    config['android_res'] ?? 'android/app/src/$name/res',
    root,
  );
  final icon = config['android_icon'] ?? 'ic_launcher';
  if (icon is! String || !RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(icon)) {
    invalid('Invalid Android resource name: $icon');
  }
  final files = <File>[];
  for (final dir in {res, p.join(root, 'android/app/src/main/res')}) {
    if (!Directory(dir).existsSync()) continue;
    for (final folder in Directory(dir).listSync(followLinks: false)) {
      if (!p.basename(folder.path).startsWith('mipmap')) continue;
      if (folder is Link) invalid('Linked resource folder: ${folder.path}');
      if (folder is! Directory) continue;
      for (final file in folder.listSync(followLinks: false)) {
        final stem = p.basenameWithoutExtension(file.path);
        if (stem != icon && stem != '${icon}_round') continue;
        if (file is! File ||
            p.extension(file.path) != '.png' ||
            stem != icon ||
            !densities.any((d) => p.basename(folder.path) == 'mipmap-$d')) {
          invalid(
            'Unsupported Android launcher variant: ${file.path}. Use a legacy PNG layout or omit android.',
          );
        }
        if (dir == res) {
          files.add(file);
        } else if (!File(
          p.join(res, p.basename(folder.path), p.basename(file.path)),
        ).existsSync()) {
          invalid('Missing flavor override for ${file.path}: $res');
        }
      }
    }
  }
  if (files.isEmpty) invalid('Missing Android launcher PNGs for $name: $res');
  return files;
}

List<File> iosTargets(String root, String name, Map config) {
  final dir = relativePath(
    config['ios_set'] ?? 'ios/Runner/Assets.xcassets/${name}AppIcon.appiconset',
    root,
  );
  if (!dir.endsWith('.appiconset')) {
    invalid('Expected a .appiconset directory: $dir');
  }
  final manifest = File(
    relativePath(p.relative(p.join(dir, 'Contents.json'), from: root), root),
  );
  final data = jsonDecode(manifest.readAsStringSync());
  if (data is! Map || data['images'] is! List) {
    invalid('Invalid icon catalog: $dir');
  }
  final names = <String>{};
  for (final entry in data['images']) {
    if (entry is! Map) invalid('Invalid catalog image: $dir');
    if (entry.containsKey('appearances')) {
      invalid('Appearance-specific iOS catalog: $dir');
    }
    final file = entry['filename'];
    if (file == null) continue;
    if (file is! String || file != p.basename(file) || !file.endsWith('.png')) {
      invalid('Unsupported catalog image: $file');
    }
    names.add(file);
  }
  if (names.isEmpty) invalid('No assigned iOS PNGs for $name: $dir');
  return [
    for (final f in names)
      File(relativePath(p.relative(p.join(dir, f), from: root), root)),
  ];
}

/// Validate and render all targets before updating any file.
int generate(
  File configFile, {
  required bool check,
  required void Function(String) log,
}) {
  final root = configFile.absolute.parent.resolveSymbolicLinksSync();
  final config = fields(loadYaml(configFile.readAsStringSync()), {
    'source',
    'platforms',
    'flavors',
  }, 'config');
  final source = File(relativePath(config['source'], root));
  final base = img.decodePng(source.readAsBytesSync());
  if (base == null || base.width != base.height) {
    invalid('Expected a square PNG: ${source.path}');
  }
  final platforms = config['platforms'] ?? ['android', 'ios'];
  if (platforms is! List ||
      platforms.isEmpty ||
      platforms.any((v) => v != 'android' && v != 'ios')) {
    invalid('Invalid platforms.');
  }
  final flavors = config['flavors'];
  if (flavors is! Map || flavors.isEmpty) {
    invalid('Define at least one flavor.');
  }
  final changed = <String, Uint8List>{};
  final used = <String>{source.path};
  for (final item in flavors.entries) {
    final name = item.key;
    if (name is! String || !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(name)) {
      invalid('Invalid flavor: $name');
    }
    final options = fields(item.value, {
      'label',
      'background',
      'foreground',
      'ios_background',
      'android_res',
      'android_icon',
      'ios_set',
    }, name);
    if (!options.containsKey('label')) {
      invalid('Set $name.label explicitly (use null for production).');
    }
    final label = options['label'];
    if (label != null &&
        (label is! String || !RegExp(r'^[A-Z]{1,3}$').hasMatch(label))) {
      invalid('Use 1–3 uppercase Latin letters for $name.label.');
    }
    final style = label == null
        ? null
        : RibbonStyle(
            label: label as String,
            background: color(options['background'] ?? '#F97316'),
            foreground: color(options['foreground'] ?? '#FFFFFF'),
          );
    final iosBackground = color(options['ios_background'] ?? '#FFFFFF');
    final targets = [
      if (platforms.contains('android'))
        ...androidTargets(root, name, options).map((file) => (file, false)),
      if (platforms.contains('ios'))
        ...iosTargets(root, name, options).map((file) => (file, true)),
    ];
    final cache = <(int, bool), Uint8List>{};
    for (final (target, isIos) in targets) {
      if (!used.add(target.path)) {
        invalid('Shared output or source collision: ${target.path}');
      }
      final bytes = target.readAsBytesSync();
      final old = img.decodePng(bytes);
      if (old == null || old.width != old.height) {
        invalid('Expected square PNG: ${target.path}');
      }
      final output = cache.putIfAbsent((old.width, isIos && base.hasAlpha), () {
        final image = style == null
            ? img.copyResize(
                base,
                width: old.width,
                height: old.height,
                interpolation: img.Interpolation.cubic,
              )
            : composeRibbonIcon(base, style, size: old.width);
        if (isIos && base.hasAlpha) {
          final opaque = img.Image(width: old.width, height: old.height);
          img.fill(opaque, color: iosBackground);
          img.compositeImage(opaque, image);
          return img.encodePng(opaque);
        }
        return img.encodePng(
          base.hasAlpha ? image : image.convert(numChannels: 3),
        );
      });
      if (!const ListEquality<int>().equals(bytes, output)) {
        changed[target.path] = output;
      }
    }
  }
  for (final entry in changed.entries) {
    log('${check ? "stale" : "update"} ${p.relative(entry.key, from: root)}');
    if (check) continue;
    final dir = Directory(p.dirname(entry.key)).createTempSync('.ribbon-');
    try {
      File(
        p.join(dir.path, 'icon.png'),
      ).writeAsBytesSync(entry.value, flush: true);
      File(p.join(dir.path, 'icon.png')).renameSync(entry.key);
    } finally {
      dir.deleteSync(recursive: true);
    }
  }
  return changed.length;
}
