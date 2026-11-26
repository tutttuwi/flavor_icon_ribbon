# Contributing

Thanks for helping with flavor_icon_ribbon. The package is [MIT licensed](LICENSE). How to use it is in [README.md](README.md). This file is how to change the package.

## Requirements

Apps that run the CLI need a Dart SDK matching `environment.sdk` in `pubspec.yaml` (`>=3.8.0 <4.0.0`). Flutter, Ruby, and ImageMagick are not used.

Cloning this repository and running the tests needs the current stable Dart SDK. `pubspec.lock` pins `package:test` 1.33, which requires Dart 3.11 or newer.

From the repository root:

```sh
dart pub get
dart analyze
dart test
```

`dart analyze` must be clean. `analysis_options.yaml` includes `package:lints/recommended.yaml`. Brace every `if`, `for`, and `while` body, including a body that is a single statement.

## Layout

| Path | Role |
| --- | --- |
| `bin/flavor_icon_ribbon.dart` | CLI. Parses flags and maps failures to exit codes. |
| `lib/flavor_icon_ribbon.dart` | Public library. Exports `RibbonStyle` and `composeRibbonIcon` only. |
| `lib/src/ribbon.dart` | Ribbon geometry and compositing. |
| `lib/src/flavor_icon_label_font.dart` | 5×7 dot glyphs for `A`–`Z`. |
| `lib/src/generator.dart` | YAML loading, Android and iOS target discovery, PNG encoding, and file replacement. |
| `test/generator_test.dart` | Behavioral tests. Each case builds a temp project. There are no checked-in fixtures. |
| `example/` | Sample YAML and a small drawing-API program. It is not a Flutter app. |

`lib/src/` is implementation. Tests may import it. Apps should not. A new public symbol needs an export from `lib/flavor_icon_ribbon.dart`, a dartdoc comment, a README mention, and a changelog bullet.

## Behavior to keep

- Validate the config and every target before replacing any PNG. A failure leaves existing icons unchanged.
- Replace a PNG by writing into a same-directory temporary directory, then renaming that file into place.
- `--check` never writes icons. Exit codes stay **0** (up to date), **1** (stale PNGs), and **2** (configuration, file, or unsupported layout).
- The same inputs produce the same PNG bytes. A second run with no config change reports zero updates.
- Android output keeps source alpha. iOS output from a transparent source is flattened over `ios_background` (white by default).
- A label is 1–3 characters `A`–`Z`, or an explicit `null` for an unbadged flavor. `null` resizes the source and draws no ribbon.
- YAML paths stay inside the config file's directory. Absolute paths, `..`, and symbolic links are rejected.
- Unknown YAML keys are errors. Only PNGs named by a standard density mipmap, or named in an iOS `Contents.json`, are updated.

`test/generator_test.dart` covers these rules. Extend that file when you change validation, encoding, or replacement. Use the temp-directory setup already in `main`.

To look at a ribbon:

```sh
dart run example/main.dart
```

That writes `icon-dev.png` in the current directory. The file is gitignored.

## Where a change goes

- **Ribbon shape or compositing.** Edit `lib/src/ribbon.dart`. `composeRibbonIcon` must not mutate its input image. Sizes under 48 px are drawn at 48 px and then downscaled, so a one-pixel stroke is not clipped away before scaling.
- **Label alphabet.** Glyphs for `A`–`Z` already live in `lib/src/flavor_icon_label_font.dart`. Widening the alphabet means a new 5×7 glyph (rows of `#` and `.`) and the same change to every `^[A-Z]{1,3}$` check, in the library and in the CLI validator. Keep strokes at an integer pixel size. Do not rasterize a font.
- **YAML keys, path rules, or Android/iOS discovery.** Edit `lib/src/generator.dart`. Render every flavor into memory first. Write files only after that loop finishes.
- **Flags or exit codes.** Edit `bin/flavor_icon_ribbon.dart` and the CI section of the README together.

This version handles classic PNG launcher assets. Creating flavors, editing manifests, Icon Composer, adaptive foreground layers, and themed icons are outside the package.

## Changelog

Put user-visible changes under a new `## Unreleased` heading at the top of `CHANGELOG.md`. Match the existing bullets: one line describing what changed for someone running the CLI or calling the library. Leave `version` in `pubspec.yaml` alone. The maintainer bumps it when publishing.

This repository commits `pubspec.lock`. Include a lockfile diff only when you change dependencies.

## Publishing

Maintainers publish to pub.dev. Move the `## Unreleased` bullets under the new version heading in `CHANGELOG.md`, set that version in `pubspec.yaml`, then from a clean tree run:

```sh
dart pub publish --dry-run
dart pub publish
```

## Pull requests

Open a pull request against `main` on [tutttuwi/flavor_icon_ribbon](https://github.com/tutttuwi/flavor_icon_ribbon). Keep each request to one concern. In the description, state the behavior that changed and that `dart analyze` and `dart test` passed. Pull requests run [`.github/workflows/ci.yml`](.github/workflows/ci.yml), which checks formatting, analysis, and tests. Report a vulnerability through the process in [SECURITY.md](SECURITY.md) instead of a public issue.
