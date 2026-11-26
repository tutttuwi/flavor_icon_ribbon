# flavor_icon_ribbon example

Sample CLI config and a small program that calls the drawing API.

## CLI

`flavor_icon_ribbon.yaml` in this directory is a Flutter app config. Copy it to the app root, point `source` at an existing square PNG, and create the flavor launcher files first. Then:

```sh
dart run flavor_icon_ribbon
dart run flavor_icon_ribbon --check
```

## Drawing API

`main.dart` builds a 192px square in memory, draws a DEV ribbon, and writes `icon-dev.png` in the current directory.

```sh
dart run example/main.dart
```

```dart
final icon = composeRibbonIcon(
  base,
  RibbonStyle(
    label: 'DEV',
    background: ColorRgb8(249, 115, 22),
    foreground: ColorRgb8(255, 255, 255),
  ),
  size: 192,
);
```
