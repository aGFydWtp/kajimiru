# MVP仕様

家事の記録と、家庭内の家事比率を見る。

## ユーザー(User)
- アプリを使う人、一人ずつに振られるID
```
    public let id: UUID
```

## 家庭(Group)
```
    public let id: UUID
    public var name: String
    public var icon: String?
    public var members: [Member]
    public var createdAt: Date
    public var createdBy: UUID
    public var updatedAt: Date
    public var updatedBy: UUID
```

## 家族(Member)
- groupに所属して家事をやる人
- ユーザーとは関係ないモデルとして用意
    - 家族全員がユーザーとして参加しているとは限らない
    - userId で紐づけることもできるが、途中でユーザーがやめたりしてもMemberは残る
    - userId を自身に紐づけられる。
        - 家事の記録のときにデフォルトで選択されている状態にするため
        - 参加時または管理画面で設定できれば良い。
    - 削除は論理削除。家事を選ぶときに非表示になる。
        - 消してしまうと家事記録の表示で問題になるため。
```
    public let id: UUID
    public let userId: UUID?
    public let displayName: String
    public var avatarURL: URL?
    public var createdAt: Date
    public var createdBy: UUID
    public var updatedAt: Date
    public var updatedBy: UUID
    public var deletedAt: Date
    public var deletedBy: UUID
```

## 家事(Chore)
- group というのが基本単位。１家族。
- 普通の使い方であれば１つの家族が1つのgroupで管理される。
- 誰かがアプリを使い始めたら、そこに家族を招待してデータが同期されること
- weight は家事の重み。(ユーザー表示場は大変度という名称)。1が一番簡単な家事。
    - いちばん簡単な家事を基準にその何倍かを1,2,3,5,8から選べる
```
    public static let allowedWeights: Set<Int> = [1, 2, 3, 5, 8]
    public static let defaultWeight: Int = 1

    public let id: UUID
    public var groupId: UUID
    public var title: String
    public var weight: Int
    public var notes: String?
    public var createdAt: Date
    public var createdBy: UUID
    public var updatedAt: Date
    public var updatedBy: UUID
```

## 家事の記録(ChoreLog)
- 誰がいつどの家事をやったかを記録する。
- ユーザーが入力するのは、やった家事とやった人の２つ。メモは任意。
- weight は変わる可能性があるので記録した時点のweightを保持できるようにフィールドを持っている。
- 他人がやった家事を別の人が記録できて良い。
```
    public let id: UUID
    public var choreId: UUID
    public var groupId: UUID
    public var performerId: UUID
    public let weight: Int
    public var memo: String?
    public var createdAt: Date
    public var createdBy: UUID
    public var updatedAt: Date
    public var updatedBy: UUID
```

## 家事比率
- 週次、月次で家事記録を集計してwight を加味した家事比率が見れる

## 画面設計
フッターにタブがありそれぞれのメニューを選べる。
-  ダッシュボード: 担当比率サマリーを週次／月次で表示。
- 家事一覧
    - 追加・削除・変更
- 設定: メンバー管理
フッターのすぐ上、右側にFloatingActionButtonを設置して家事の登録画面に遷移。

## 将来実装予定だがMVPではやらないこと
- オンボーディング・サインイン
    - とりあえずGroupはデフォルトで適当なID,名前は自宅で、Memberも「たろう」「はなこ」が登録されている状態。
    - Userも1つあって、自分
- 家事の分類
    - タグ付けかカテゴリー分けを導入して探しやすくする
- Groupに家族を招待する機能
    - とりあえず、自分一人が使う。家族は自分で複数人登録して、自分だけが記録していく。
    - なのでデータもiPhone内に。複数人で使うときはFirebaseを使用。
- 家事のリマインド。
    - 定期的にやる家事があれば次に発生しそうな時期がわかるのでリマインドをする
- 家事をやったときの通知
    - 誰かが家事をしたらgroup(参加している家族全員)に通知を飛ばす
- 削除したmemberを復活させる
