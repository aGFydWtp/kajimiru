# Firebase Functions セキュリティ実装

このドキュメントでは、招待コード機能のセキュリティ強化のために実装されたFirebase Cloud Functionsについて説明します。

## 概要

招待コードの検証とメンバー追加処理を、クライアント側のFirestoreアクセスからサーバーサイドのCloud Functionsに移行しました。これにより、以下のセキュリティが強化されました:

1. **招待コードの保護**: `groupInvites`コレクションへのアクセスを作成者のみに制限
2. **シングルユース強制**: 招待コードは使用後に自動削除され、再利用不可
3. **認証の検証**: Firebase Authenticationを使用した厳密な認証チェック
4. **Admin SDK使用**: Firestore Rulesを回避した安全なデータアクセス

## アーキテクチャ

```
Client (iOS App)
    ↓
InviteService.swift (Swift wrapper)
    ↓
Firebase Cloud Functions (Node.js/TypeScript)
    ↓
Firebase Admin SDK
    ↓
Firestore Database
```

## Cloud Functions

### 1. getGroupMembersByInviteCode

招待コードを使用してグループメンバー情報を取得します。

**エンドポイント**: `getGroupMembersByInviteCode`

**入力**:
```typescript
{
  code: string  // 招待コード (例: "ABCD-1234")
}
```

**出力**:
```typescript
{
  userConnectedMembers: [    // Firebase認証済みメンバー
    { id: string, name: string }
  ],
  nonConnectedMembers: [     // 未認証メンバー
    { id: string, name: string }
  ]
}
```

**処理フロー**:
1. Firebase認証チェック
2. 招待コードで`groupInvites`を検索
3. 招待コードの有効性を検証:
   - `isActive`がtrue
   - `expiresAt`が未来（または未設定）
   - `currentUses < maxUses`（または未設定）
4. グループIDを取得
5. グループの全メンバーを取得（`deletedAt == null`）
6. `firebaseUid`の有無でメンバーを分類

**エラー**:
- `unauthenticated`: 認証されていない
- `invalid-argument`: 招待コードが不正
- `not-found`: 招待コードが見つからない
- `failed-precondition`: 招待コードが無効、期限切れ、または使用回数上限

### 2. addGroupMemberByInviteCode

招待コードを使用して新規メンバーを作成、または既存メンバーを認証アカウントにリンクします。

**エンドポイント**: `addGroupMemberByInviteCode`

**入力**:
```typescript
{
  code: string,
  newMember: {
    id: string | null,      // null = 新規作成, UUID = 既存メンバーとリンク
    name: string,           // 表示名
    userId: string,         // ユーザーUUID
    firebaseUid: string     // Firebase Auth UID
  }
}
```

**出力**:
```typescript
{
  success: boolean,
  memberId: string,    // 作成/更新されたメンバーのID
  groupId: string      // グループID
}
```

**処理フロー**:
1. Firebase認証チェック
2. `firebaseUid`がリクエスト元の認証UIDと一致するか確認
3. 招待コードの検証（getGroupMembersと同様）
4. グループIDを取得
5. 既にメンバーでないか確認（`firebaseUid`で検索）
6. **トランザクション開始**:
   - **既存メンバーとリンクの場合**:
     - メンバードキュメントを取得
     - `firebaseUid`が未設定であることを確認
     - `userId`と`firebaseUid`を更新
   - **新規メンバー作成の場合**:
     - 新しいメンバードキュメントを作成
     - `userId`をドキュメントIDとして使用
   - **招待コードを削除**（シングルユース強制）
7. **トランザクション完了**

**エラー**:
- `unauthenticated`: 認証されていない
- `invalid-argument`: リクエストデータが不正
- `permission-denied`: `firebaseUid`が認証情報と不一致
- `not-found`: 招待コードまたはメンバーが見つからない
- `already-exists`: 既にグループメンバー
- `failed-precondition`: 招待コードが無効、またはメンバーが既に認証済み

## Firestore Rules

### groupInvites コレクション

```javascript
match /groupInvites/{inviteId} {
  // 作成者のみがアクセス可能
  allow read: if isAuthenticated() &&
                 resource.data.createdByFirebaseUid == request.auth.uid;

  allow create: if isAuthenticated() &&
                   request.resource.data.createdByFirebaseUid == request.auth.uid;

  allow update: if isAuthenticated() &&
                   resource.data.createdByFirebaseUid == request.auth.uid;

  allow delete: if isAuthenticated() &&
                   resource.data.createdByFirebaseUid == request.auth.uid;
}
```

**重要**: Cloud Functionsは Firebase Admin SDK を使用するため、これらのルールをバイパスできます。一般ユーザーは作成者のみがアクセス可能です。

## Swift クライアント実装

### InviteService.swift

`InviteService`クラスは、Cloud Functionsへのインターフェースを提供します。

```swift
@MainActor
class InviteService: ObservableObject {
    func getGroupMembers(byInviteCode code: String) async throws -> GetMembersResponse

    func addMember(
        withInviteCode code: String,
        existingMemberId: UUID?,
        memberName: String,
        userId: UUID,
        firebaseUid: String
    ) async throws -> AddMemberResponse
}
```

### エラーハンドリング

```swift
enum InviteError: LocalizedError {
    case unauthenticated
    case inviteNotFound
    case alreadyMember
    case invalidInvite(String)
    case invalidArgument(String)
    case permissionDenied
    case invalidResponse
    case unknown(String)
}
```

## 使用フロー

### 1. 招待コード入力

```swift
// InviteCodeInputView.swift
// ユーザーが招待コードを入力
// 既存のvalidateInviteCode()を使用して招待の存在を確認
```

### 2. メンバー一覧取得

```swift
// MemberLinkingView.swift
let response = try await inviteService.getGroupMembers(byInviteCode: code)
linkedMembers = response.userConnectedMembers
unlinkedMembers = response.nonConnectedMembers
```

### 3. メンバー追加/リンク

```swift
// MemberLinkingView.swift - 既存メンバーとリンク
let response = try await inviteService.addMember(
    withInviteCode: code,
    existingMemberId: selectedMemberUUID,  // 既存メンバーのID
    memberName: memberName,
    userId: newUserId,
    firebaseUid: firebaseAuthUid
)

// または新規メンバー作成
let response = try await inviteService.addMember(
    withInviteCode: code,
    existingMemberId: nil,  // nil = 新規作成
    memberName: userName,
    userId: newUserId,
    firebaseUid: firebaseAuthUid
)

// グループIDを使用してアプリ状態を更新
try await appState.setActiveGroup(UUID(uuidString: response.groupId)!)
```

## デプロイ

### 前提条件

```bash
# Node.js 20がインストールされていること
node --version  # v20.x.x

# Firebase CLIがインストールされていること
firebase --version
```

### ローカルテスト（エミュレータ）

```bash
# Functionsエミュレータを起動
firebase emulators:start

# または特定のエミュレータのみ
firebase emulators:start --only functions,firestore
```

エミュレータUI: http://localhost:4002

### 本番環境へのデプロイ

```bash
# Functionsをデプロイ
cd functions
npm run build
cd ..
firebase deploy --only functions

# Firestore Rulesも更新
firebase deploy --only firestore:rules
```

### デプロイ後の確認

```bash
# Functionsのログを確認
firebase functions:log

# 特定のFunctionのログ
firebase functions:log --only getGroupMembersByInviteCode
```

## セキュリティのベストプラクティス

1. **認証の必須化**: すべてのCloud Functionsでリクエスト元の認証を確認
2. **UID検証**: `firebaseUid`がリクエスト元の`request.auth.uid`と一致することを確認
3. **トランザクション**: 複数の操作を原子的に実行
4. **シングルユース**: 招待コードを使用後に削除して再利用を防止
5. **期限チェック**: `expiresAt`と`maxUses`をサーバーサイドで検証
6. **エラーメッセージ**: クライアントに詳細すぎる情報を返さない

## トラブルシューティング

### 招待コードが見つからない

- Firestoreで`groupInvites`コレクションに該当ドキュメントが存在するか確認
- `code`フィールドが正確に一致しているか確認（大文字小文字区別）

### 権限エラー

- Firebase Authenticationで正しくログインしているか確認
- `createdByFirebaseUid`フィールドが正しく設定されているか確認

### Functionがデプロイされない

```bash
# ビルドエラーを確認
cd functions
npm run build

# eslintエラーを確認
npm run lint
```

### エミュレータでテストできない

```bash
# Firebaseプロジェクトが正しく設定されているか確認
firebase use

# エミュレータの設定を確認
cat firebase.json
```

## 今後の改善案

1. **App Checkの有効化**: ボット攻撃を防ぐため
2. **Rate Limiting**: 同一IPからの過度なリクエストを制限
3. **Analytics**: 招待コードの使用状況をトラッキング
4. **通知**: メンバー追加時にグループ管理者に通知
5. **監査ログ**: メンバー追加のログを記録

## 参考リンク

- [Firebase Cloud Functions ドキュメント](https://firebase.google.com/docs/functions)
- [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup)
- [Firestore セキュリティルール](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase App Check](https://firebase.google.com/docs/app-check)
