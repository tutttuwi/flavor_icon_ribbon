# flavor_icon_ribbon

Generate DEV, STG or QA launcher icons from one square PNG. This development-time Dart CLI updates existing Android and iOS PNGs at their native sizes. Generated icons can be committed and used by local builds and CI. Flutter, Ruby and ImageMagick are not required to run the generator.

![DEV, STG and PROD icons at 48 pixels](example/preview.png)

## Add to a Flutter project

From the Flutter app directory, add the CLI as a development dependency:

```sh
dart pub add dev:flavor_icon_ribbon
```

Save the YAML under **Configuration** below as `flavor_icon_ribbon.yaml` at the app root. Then generate the icons:

```sh
dart run flavor_icon_ribbon
dart run flavor_icon_ribbon --check
```

Use `fvm dart` in FVM-managed apps. Create the flavors and their icon files first. The default layout matches flutter_flavorizr. You may keep using flutter_launcher_icons for base and web icons. Run this tool after other generators. When migrating flutter-template, replace the invocation of `tool/generate_flavor_icons.dart` in both Makefile targets and keep the existing base-icon step.

## Configuration

Paths resolve from the YAML file's directory. Select another file with `--config path/to/config.yaml`.

```yaml
source: assets/img/icon.png
platforms: [android, ios]
flavors:
  dev:
    label: DEV
    background: '#F97316'
  stg:
    label: STG
    background: '#2563EB'
  prod:
    label: null
```

Use 1–3 uppercase letters A–Z. The label is required, including an explicit null for an unbadged flavor. Colors accept quoted #RRGGBB. The default ribbon is orange with white lettering. Production PNGs are also regenerated from the source.

Custom paths and colors, for a project using a different catalog convention:

```yaml
source: assets/logo.png
platforms: [ios, android]
flavors:
  qa:
    label: QA
    foreground: '#FFFFFF'
    background: '#6839B8'
    ios_background: '#FFFFFF'
    ios_set: ios/Runner/Assets.xcassets/AppIcon-qa.appiconset
    android_res: android/app/src/qa/res
    android_icon: ic_launcher
```

- Android defaults to `android/app/src/<flavor>/res/mipmap-<density>/ic_launcher.png`. Supply existing square PNGs. Transparency is preserved. The CLI checks the selected resources and standard main resources for matching adaptive XML, alternate round icons and unsupported resource qualifiers. Builds using other source sets or custom manifest aliases need separate verification.
- iOS defaults to `ios/Runner/Assets.xcassets/<flavor>AppIcon.appiconset`. Only filenames referenced in Contents.json are updated. Transparent source artwork is composited over ios_background (white by default) for opaque iOS output. Separate appearance variants (Dark/Tinted) require separate artwork and cause a validation error.
- To process just one platform, set platforms to [ios] or [android]. This version works with classic PNG launcher assets. Flavor creation, manifest changes, Icon Composer, adaptive foregrounds and themed icon generation are outside its scope.
- All inputs are validated before modification. A changed PNG is replaced with a same-directory rename. If interrupted during replacement, rerun to finish. Keep the consuming app's pubspec.lock in version control so local and CI builds use the same image encoder.

## CI

After dependency resolution, run `dart run flavor_icon_ribbon --check`. Exit codes: **0** up to date, **1** stale PNGs, **2** configuration, file or unsupported-layout error. Check mode writes no icon files.

## Drawing API

Import `package:flavor_icon_ribbon/flavor_icon_ribbon.dart` and call `composeRibbonIcon(image, RibbonStyle(label: 'UAT', background: color), size: 48)`. It returns a new image. The CLI performs platform-specific output handling. [`example/main.dart`](example/main.dart) writes a sample PNG.

## Development

Run `dart pub get`, `dart analyze` and `dart test`. The renderer originated in tutttuwi/flutter-template.
