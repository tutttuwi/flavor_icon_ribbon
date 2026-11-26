# flavor_icon_ribbon

[English](README.md)

1枚の正方形 PNG から、DEV、STG、QA のランチャーアイコンを作ります。開発時に使う Dart の CLI で、既存の Android と iOS の PNG を、それぞれの本来のサイズのまま更新します。生成したアイコンはコミットでき、ローカルビルドと CI の両方で使えます。ジェネレータの実行に Flutter、Ruby、ImageMagick は不要です。

![48ピクセルの DEV、STG、PROD アイコン](example/preview.png)

## Flutter プロジェクトへの追加

Flutter アプリのディレクトリで、CLI を開発用の依存関係として追加します。

```sh
dart pub add dev:flavor_icon_ribbon
```

下の **設定** にある YAML を、アプリのルートに `flavor_icon_ribbon.yaml` として保存します。そのあとアイコンを生成します。

```sh
dart run flavor_icon_ribbon
dart run flavor_icon_ribbon --check
```

FVM で管理しているアプリでは `fvm dart` を使います。flavor と、そのアイコンファイルは先に作っておきます。デフォルトの配置は flutter_flavorizr に合わせています。ベースアイコンと Web 用アイコンは、flutter_launcher_icons を使い続けてかまいません。このツールは、他のジェネレータのあとに実行します。flutter-template から移す場合は、Makefile の両方のターゲットで `tool/generate_flavor_icons.dart` の呼び出しを置き換え、既存のベースアイコン生成はそのまま残します。

## 設定

パスは YAML ファイルのあるディレクトリから解決します。別のファイルを使うときは `--config path/to/config.yaml` を指定します。

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

ラベルは A–Z の大文字 1〜3 文字です。ラベルは必須で、リボンを付けない flavor も `null` を明示します。色は引用符付きの `#RRGGBB` です。リボンの既定はオレンジ、文字は白です。production の PNG もソースから作り直します。

カタログの置き方が違うプロジェクト向けに、パスと色を指定した例です。

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

- Android の既定は `android/app/src/<flavor>/res/mipmap-<density>/ic_launcher.png` です。既存の正方形 PNG を用意します。透過は維持します。CLI は、選んだリソースと標準の main リソースを見て、対応する adaptive XML、代替の round アイコン、未対応のリソース修飾子がないか確認します。別の source set や、独自の manifest エイリアスを使うビルドは、別途確認してください。
- iOS の既定は `ios/Runner/Assets.xcassets/<flavor>AppIcon.appiconset` です。更新するのは Contents.json が参照しているファイル名だけです。透過のあるソース画像は、不透明な iOS 出力にするため `ios_background`（既定は白）の上に合成します。Dark や Tinted などの appearance 別バリアントは別の画像が必要なので、検証エラーになります。
- 片方のプラットフォームだけ処理するときは、`platforms` を `ios` か `android` にします。このバージョンが扱うのは、従来の PNG ランチャー素材です。flavor の作成、manifest の変更、Icon Composer、adaptive の前景、テーマアイコンの生成は対象外です。
- 入力は、ファイルを書き換える前にすべて検証します。変更のある PNG は、同じディレクトリ内のリネームで置き換えます。置き換えの途中で中断した場合は、再実行すれば完了します。ローカルと CI で同じ画像エンコーダを使うため、利用側アプリの `pubspec.lock` はバージョン管理に入れてください。

## CI

依存関係の解決後に `dart run flavor_icon_ribbon --check` を実行します。終了コードは、**0** が最新、**1** が古い PNG、**2** が設定、ファイル、または未対応レイアウトのエラーです。check モードはアイコンファイルを書きません。

## 描画 API

`package:flavor_icon_ribbon/flavor_icon_ribbon.dart` を import し、`composeRibbonIcon(image, RibbonStyle(label: 'UAT', background: color), size: 48)` を呼びます。新しい画像を返します。プラットフォームごとの出力処理は CLI が行います。[`example/main.dart`](example/main.dart) はサンプル PNG を書き出します。

## 開発

開発環境、ディレクトリ構成、pull request の手順は [CONTRIBUTING.md](CONTRIBUTING.md) にあります。このリポジトリでは `dart pub get`、`dart analyze`、`dart test` を実行します。描画処理の元は tutttuwi/flutter-template です。

## ライセンス

[MIT](LICENSE)
