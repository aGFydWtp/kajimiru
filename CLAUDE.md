# CLAUDE.md

このファイルは、このリポジトリで作業する際にClaude Code (claude.ai/code) へのガイダンスを提供します。

## プロジェクト概要

Kajimiruは、家族、ルームメイト、チームで家事を追跡・共有するためのiOSアプリです。ユーザーはグループを作成し、難易度の重み（1, 2, 3, 5, 8）を持つ家事を定義し、完了したタスクを記録し、週次・月次の分析を通じて作業負荷の分布を可視化します。

## アーキテクチャ

本プロジェクトは**二重構造アーキテクチャ**に従っています:

1. **KajimiruKit** (Swift Package): ドメインロジック、モデル、サービス、リポジトリプロトコル
   - `Sources/KajimiruKit/` に配置
   - コアモデルの定義: `Chore`, `ChoreLog`, `Group`, `User`, `Reminder`
   - サービス: `ChoreService`, `ChoreLogService`, `GroupService`, `ChoreAnalyticsService`, `ReminderScheduler`
   - データ永続化を抽象化するリポジトリプロトコル
   - テスト用のインメモリ実装は `Support/InMemoryRepositories.swift` にあり

2. **kajimiru** (Xcode iOS App): SwiftUIクライアントアプリケーション
   - `kajimiru/` に配置
   - 状態管理にThe Composable Architecture (TCA) を使用予定
   - 現在は基本的なUIコンポーネントとビューモデルを含む

### 主要なアーキテクチャ上の決定

- **重みの保存**: 家事の重みが変更された場合でも、`ChoreLog`レコードは完了時の重みを記録し、分析における過去データの破壊を防ぐ
- **リポジトリパターン**: すべてのデータアクセスはプロトコルベースのリポジトリを経由し、Firebase、インメモリ、その他のバックエンド間の容易な切り替えを可能にする
- **Sendableコンプライアンス**: すべてのモデルとサービスはSwiftの`Sendable`プロトコルに準拠し、安全な並行アクセスを実現

## 開発コマンド

### ビルドとテスト

```bash
# Swift packageをビルド
swift build

# KajimiruKitのすべてのテストを実行
swift test

# 特定のテストを実行
swift test --filter ChoreServiceTests

# XcodeでiOSアプリをビルド
xcodebuild -scheme kajimiru -destination 'platform=iOS Simulator,name=iPhone 15' build

# Xcodeで開く
open kajimiru.xcodeproj
```

## データモデル

### コアとなる関係性

- `Group`は複数の`Chore`エントリと複数の`User`メンバーを含む
- 各`Chore`は1つの`Group`に属し、固定の`weight`を持つ（許可値: 1, 2, 3, 5, 8）
- `ChoreLog`は`User`による`Chore`の完了を記録し、記録時点の`weight`を保存
- `Reminder`エントリは特定の`Chore`レコードに紐付けられ、通知をスケジュール

### 重みシステム

家事の難易度はフィボナッチ風の重み（`1, 2, 3, 5, 8`）を使用します。これらの値は`Chore.isValidWeight()`を介してモデルイニシャライザで検証されます。分析は件数ではなく、ユーザーごとの`totalWeight`で集計されます。

## 分析と集計

`ChoreAnalyticsService`は週次・月次ビュー用の`WorkloadSnapshot`オブジェクトを生成します:
- 実施者と記録された重みで`ChoreLog`エントリを集計
- ユーザーごとに`completedCount`と`totalWeight`を含む`ContributorSummary`を返す
- スナップショットは間隔の開始日でソート

## テスト戦略

- `Tests/KajimiruKitTests/Services/`内のすべてのサービスのユニットテスト
- サービスはインメモリリポジトリ実装を使用してテスト
- 現在、パッケージレイヤーにUIテストは存在しない

## MVPスコープ

現在の実装はフェーズ1に焦点を当てています:
- 認証とグループ作成（UI未実装）
- `ChoreService`を介した家事のCRUD操作
- Firebase/Firestore統合（計画中、未実装）

フェーズ2（計画中）: クイック記録UI、リマインダー、家事ログ履歴
フェーズ3（計画中）: ロールベース権限、CSVエクスポート、WidgetKitサポート

## Firebase統合計画

Firebaseリポジトリを実装する際:
- `RepositoryProtocols.swift`のプロトコルに準拠
- `Group`, `Chore`, `ChoreLog`, `Reminder`コレクションにFirestoreを使用
- ユーザー管理にFirebase Authを実装
- ローカルキャッシュを伴うオフライン同期戦略を検討

## プラットフォーム要件

- Swift 6.1+
- iOS 16.0+
- Xcode 16.4+
