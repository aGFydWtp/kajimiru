# Firebase セットアップ手順

このドキュメントでは、Kajimiruアプリにfirebaseを統合するための手順を説明します。

## 前提条件

- Xcode 16.4+
- Firebase プロジェクト（まだ作成していない場合）
- Google アカウント

---

## 1. Firebase プロジェクトの作成

1. [Firebase Console](https://console.firebase.google.com/) にアクセス
2. 「プロジェクトを追加」をクリック
3. プロジェクト名を入力（例: `kajimiru`）
4. Google Analytics の設定（任意）
5. 「プロジェクトを作成」をクリック

---

## 2. iOS アプリの登録

1. Firebase Console で作成したプロジェクトを開く
2. 「iOS アプリを追加」をクリック
3. **Bundle ID** を入力: `com.yourcompany.kajimiru`（実際のBundle IDに置き換え）
4. アプリのニックネーム（任意）: `Kajimiru`
5. App Store ID（任意）: 空欄でOK
6. 「アプリを登録」をクリック

---

## 3. GoogleService-Info.plist のダウンロードと配置

1. Firebase Console で `GoogleService-Info.plist` をダウンロード
2. Xcode でプロジェクトを開く
3. `kajimiru/` ディレクトリ（`kajimiruApp.swift` と同じ階層）に `GoogleService-Info.plist` をドラッグ&ドロップ
4. 「Copy items if needed」にチェックを入れる
5. 「Add to targets」で `kajimiru` を選択

### 🔒 セキュリティに関する重要な注意事項

**このリポジトリはパブリックです。以下のセキュリティ対策を必ず実施してください:**

#### ✅ 実施済みの対策

1. **`.gitignore` への追加**: `GoogleService-Info.plist` は既に `.gitignore` に追加されており、Gitにコミットされません
2. **テンプレートファイル**: `GoogleService-Info.plist.template` がリポジトリに含まれており、他の開発者がセットアップできます
3. **Firestore Security Rules**: `firestore.rules` に厳格なアクセス制御ルールが定義されています

#### 🛡️ 必須のセキュリティ設定

Firebase のAPIキーはクライアント側で使用されるため公開されても問題ありませんが、**必ず以下の対策を実施してください**:

1. **Firestore Security Rules の適用** (必須)
   - リポジトリの `firestore.rules` を Firebase Console にデプロイ
   - 認証されたユーザーのみがデータにアクセス可能
   - グループメンバーのみが自分のグループのデータを操作可能

2. **Firebase App Check の有効化** (推奨)
   - 不正なアプリからのアクセスを防止
   - Firebase Console > App Check から設定

3. **Bundle ID の制限** (推奨)
   - Firebase Console > プロジェクト設定 > アプリ
   - 登録したBundle IDからのみアクセスを許可

#### 📋 新しい開発者のセットアップ手順

他の開発者がこのプロジェクトをクローンした場合:

```bash
# 1. テンプレートをコピー
cp kajimiru/GoogleService-Info.plist.template kajimiru/GoogleService-Info.plist

# 2. Firebase Console から実際の値を取得して置き換え
# YOUR_API_KEY, YOUR_PROJECT_ID, YOUR_CLIENT_ID などを実際の値に置換

# 3. Xcode でプロジェクトをビルド
```

---

## 4. Firebase Authentication の設定

### 4.1 Google Sign-In を有効化

1. Firebase Console で「Authentication」を開く
2. 「始める」をクリック
3. 「Sign-in method」タブを開く
4. 「Google」を選択
5. 「有効にする」をONにする
6. プロジェクトのサポートメール を選択
7. 「保存」をクリック

### 4.2 Google Client ID の確認

1. `GoogleService-Info.plist` を開く
2. `CLIENT_ID` の値をコピー（`xxxxxxxxxxx.apps.googleusercontent.com` の形式）
3. この値は自動で使用されます（手動設定不要）

---

## 5. Xcode プロジェクト設定

### 5.1 Firebase SDK の追加

1. Xcode でプロジェクトを開く
2. プロジェクトナビゲーターで `kajimiru` プロジェクトを選択
3. 「Package Dependencies」タブを開く
4. 「+」ボタンをクリック
5. 以下のURLを入力: `https://github.com/firebase/firebase-ios-sdk.git`
6. 「Add Package」をクリック
7. 以下のライブラリを選択:
   - `FirebaseAuth`
   - `FirebaseFirestore`
8. ターゲットは `kajimiru` を選択
9. 「Add Package」をクリック

### 5.2 Google Sign-In SDK の追加

1. 「Package Dependencies」タブで再度「+」ボタンをクリック
2. 以下のURLを入力: `https://github.com/google/GoogleSignIn-iOS.git`
3. 「Add Package」をクリック
4. `GoogleSignIn` と `GoogleSignInSwift` を選択
5. ターゲットは `kajimiru` を選択
6. 「Add Package」をクリック

### 5.3 URL Scheme の設定

1. Xcode でプロジェクトを開く
2. プロジェクトナビゲーターで `kajimiru` プロジェクトを選択
3. 「kajimiru」ターゲットを選択
4. 「Info」タブを開く
5. 「URL Types」セクションを展開（なければ追加）
6. 「+」ボタンをクリックして新しい URL Type を追加
7. 「URL Schemes」に `GoogleService-Info.plist` の `REVERSED_CLIENT_ID` の値を入力
   - 例: `com.googleusercontent.apps.1234567890-xxxxx`

**REVERSED_CLIENT_ID の確認方法**:
1. `GoogleService-Info.plist` を開く
2. `REVERSED_CLIENT_ID` キーの値をコピー
3. 上記の URL Schemes に貼り付け

---

## 6. ビルドと実行

1. Xcode でプロジェクトをビルド: `Cmd + B`
2. シミュレーターまたは実機でアプリを実行: `Cmd + R`
3. サインイン画面が表示されることを確認
4. 「Googleでサインイン」ボタンをタップ
5. Googleアカウントでサインイン

---

## 7. Firestore の設定

### 7.1 Firestore Database の作成

1. Firebase Console で「Firestore Database」を開く
2. 「データベースの作成」をクリック
3. **ロケーション**を選択: `asia-northeast1`（東京）推奨
4. **セキュリティルールの設定**: 「本番環境モード」を選択
5. 「有効にする」をクリック

### 7.2 セキュリティルールの設定

**重要**: パブリックリポジトリのため、厳格なセキュリティルールの適用が必須です。

#### 方法1: Firebase CLI でデプロイ（推奨）

```bash
# Firebase CLI のインストール
npm install -g firebase-tools

# Firebase にログイン
firebase login

# プロジェクトの初期化
firebase init firestore

# セキュリティルールのデプロイ
firebase deploy --only firestore:rules
```

リポジトリの `firestore.rules` ファイルが自動的にデプロイされます。

#### 方法2: Firebase Console で手動設定

1. Firebase Console で「Firestore Database」を開く
2. 「ルール」タブを開く
3. リポジトリの `firestore.rules` ファイルの内容をコピー&ペースト
4. 「公開」をクリック

#### 🔒 セキュリティルールの説明

実装されているセキュリティ対策:

- **認証必須**: すべての操作で Firebase Authentication による認証が必須
- **グループメンバー制限**: グループのメンバーのみがデータにアクセス可能
- **管理者権限**: グループの管理者のみが特定の操作を実行可能
- **重み値の検証**: 家事の重みは `[1, 2, 3, 5, 8]` のみ許可
- **所有者制限**: ユーザーは自分のログのみ編集・削除可能

詳細は `firestore.rules` ファイルを参照してください。

---

## 8. 動作確認

### 8.1 認証のテスト

1. アプリを起動
2. サインイン画面で「Googleでサインイン」をタップ
3. Googleアカウントでサインイン
4. メイン画面に遷移することを確認
5. 設定画面でログイン中のメールアドレスが表示されることを確認
6. サインアウト機能をテスト

### 8.2 Firestore のテスト（Phase 2 実装後）

1. 家事を作成
2. Firebase Console で Firestore を開く
3. `groups/{groupId}/chores/{choreId}` にデータが保存されていることを確認

---

## トラブルシューティング

### エラー: "GoogleService-Info.plist が見つかりません"

**解決策**:
- `GoogleService-Info.plist` が `kajimiru/` ディレクトリに配置されていることを確認
- Xcode のプロジェクトナビゲーターに表示されていることを確認
- ターゲットメンバーシップで `kajimiru` が選択されていることを確認

### エラー: "Google Sign-In が失敗します"

**解決策**:
- URL Scheme が正しく設定されているか確認（`REVERSED_CLIENT_ID`）
- Bundle ID が Firebase Console に登録されているものと一致しているか確認
- `GoogleService-Info.plist` が最新のものか確認

### エラー: "Firestore へのアクセスが拒否されます"

**解決策**:
- Firebase Console でセキュリティルールが正しく設定されているか確認
- ユーザーが認証されているか確認
- グループメンバーとして登録されているか確認

---

## 次のステップ

- [ ] Phase 2: Firestore リポジトリの実装
- [ ] データの永続化テスト
- [ ] リアルタイム同期の実装
- [ ] オフライン対応の有効化

---

## 参考リンク

- [Firebase iOS SDK Documentation](https://firebase.google.com/docs/ios/setup)
- [Google Sign-In for iOS](https://developers.google.com/identity/sign-in/ios)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
