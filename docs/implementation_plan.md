# Kajimiru 実装計画（MVP）

本ドキュメントは、プロダクト仕様書に基づき iOS アプリ「Kajimiru」の MVP を実装するための実行計画を整理したものです。ドメインレイヤーの実装を Swift Package として切り出し、クライアントアプリから再利用できる基盤を整備します。

## 1. アーキテクチャ方針
- **クライアント**: SwiftUI + The Composable Architecture を用いて、グループ／家事／記録／分析の各 Feature をモジュール化する。
- **ドメイン共通ロジック**: Swift Package `KajimiruKit` に集約。モデル、リポジトリプロトコル、サービス、分析処理を提供。
- **インフラ**: MVP では Firebase (Auth, Firestore, Functions) を採用する前提で API を抽象化。ローカルテストでは in-memory 実装を利用。

## 2. 機能フェーズ
### フェーズ 1: 認証・グループ・家事マスター
- サインイン／グループ作成 UI の実装。
- `KajimiruKit` の `ChoreService` を利用した家事 CRUD。
- Firestore リポジトリ実装（後続タスクで追加）。

### フェーズ 2: 家事記録・履歴
- クイック記録 UI、履歴一覧。
- `ChoreLogService` による実績登録・編集・削除。
- 実績未入力リマインドのためのスケジュール設定 UI。

### フェーズ 3: 分析・ダッシュボード
- `ChoreAnalyticsService` を活用した週次／月次チャートの表示。
- CSV エクスポートとフィルタリング UI。
- 偏り検知ロジックを活用したアラート表示。

## 3. テクニカルタスク
- `KajimiruKit` のテストを充実させ、ドメインロジックの信頼性を担保。
- SwiftUI アプリ側で `KajimiruKit` を依存として取り込み、Feature ごとに TCA Reducer を構成。
- Firebase リポジトリ実装時には、`RepositoryProtocols` に準拠したクラスを追加し、同期・キャッシュ戦略を検討。
- Fastlane + GitHub Actions を使った CI/CD パイプライン整備（ビルド・テスト・配信）。

## 4. 今後のスコープ拡張
- 権限ロールごとの UI 制御、CSV エクスポート、WidgetKit 対応。
- オフライン同期（ローカルデータベース + 差分同期）。
- Iteration 3 以降で通知テンプレートや偏り検知アルゴリズムの高度化。

この計画に沿って、クライアント層・インフラ層を段階的に実装し、仕様書に定義された価値提供を実現します。
