import 'dart:io';

import 'package:args/args.dart';
import 'package:flavor_icon_ribbon/src/generator.dart';

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption(
      'config',
      abbr: 'c',
      defaultsTo: 'flavor_icon_ribbon.yaml',
      help: 'YAML file in the project root.',
    )
    ..addFlag(
      'check',
      negatable: false,
      help: 'Report stale images without writing.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');
  try {
    final options = parser.parse(args);
    if (options['help'] as bool) {
      stdout.writeln(parser.usage);
      return;
    }
    if (options.rest.isNotEmpty) {
      throw const FormatException('Unexpected positional arguments.');
    }
    final check = options['check'] as bool;
    final count = generate(
      File(options['config'] as String),
      check: check,
      log: stdout.writeln,
    );
    stdout.writeln(
      count == 0
          ? 'Icons are up to date.'
          : '$count image(s) ${check ? "stale" : "updated"}.',
    );
    if (check && count > 0) exitCode = 1;
  } on Exception catch (error) {
    stderr.writeln(error);
    exitCode = 2;
  }
}
