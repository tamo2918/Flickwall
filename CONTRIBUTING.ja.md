# コントリビューション

[English](CONTRIBUTING.md) | 日本語

Flickwall の改善に協力していただきありがとうございます。

## 開発環境の準備

1. Xcode 26.2 以降をインストールします。
2. リポジトリをクローンします。
3. `./script/build_and_run.sh --verify` を実行します。
4. Xcode で作業したい場合は `Flickwall.xcodeproj` を開きます。

## Pull Request を開く前に

次のテストを実行してください。

```bash
xcodebuild test \
  -project Flickwall.xcodeproj \
  -scheme Flickwall \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  -only-testing:FlickwallTests
```

アプリが起動することも確認してください。

```bash
./script/build_and_run.sh --verify
```

## コードスタイル

- SwiftUI View と AppKit ブリッジ型は小さく、目的が明確な単位に保ちます。
- ユーザー向けの挙動は macOS ネイティブの操作感に合わせます。
- ファイルアクセスはサンドボックスに対応した安全な形で扱います。
- 明確な議論なしに、分析、トラッキング、ネットワーク挙動を追加しないでください。
- 生成されたビルド成果物、個人の Xcode ユーザーデータ、ローカル署名ファイルをコミットしないでください。

## Pull Request のガイドライン

- ユーザーから見える変更点を説明してください。
- UI が変わる場合は、可能であればスクリーンショットや録画を添付してください。
- macOS の権限、サンドボックス、署名に影響がある場合は明記してください。
- 機能追加やバグ修正の Pull Request に、無関係なリファクタリングを混ぜないでください。
