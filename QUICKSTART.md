# 🚀 5分でわかる新機能クイックテスト

## 準備（1分）

```bash
# 1. テスト用ディレクトリ作成
mkdir -p ~/bmc-test/{work,home,temp}

# 2. ブックマーク追加
cd ~/bmc-test/work && bmc add work
cd ~/bmc-test/home && bmc add home
cd ~/bmc-test/temp && bmc add temp

# 3. 確認
bmc list
```

---

## 🔍 新機能1: 検証・診断（2分）

### ステップ1: 健全性診断
```bash
bmc doctor
```
→ 全ブックマークの統計が表示される

### ステップ2: 無効なブックマークを作成
```bash
echo "broken:/fake/path" >> ~/.bm/bookmarks
bmc validate
```
→ 無効なブックマークが検出される（✗マーク）

### ステップ3: クリーンアップ
```bash
bmc clean
bmc validate
```
→ 無効なブックマークが削除され、✓マークに変わる

---

## 📊 新機能2: 履歴追跡（2分）

### ステップ1: ブックマークを使用
```bash
bmc go work
bmc go home
bmc go temp
bmc go work
bmc go work
```

### ステップ2: 最近の履歴を確認
```bash
bmc recent
```
→ 最近使った順に表示される

### ステップ3: 使用頻度を確認
```bash
bmc frequent
```
→ work (3回), home (1回), temp (1回) が表示される

### ステップ4: 統計を表示
```bash
bmc stats
```
→ 総アクセス数: 5回、最頻: work

### ステップ5: 履歴から選択（fzf必須）
```bash
bmc go
```
→ 矢印キーで選択、Enterで移動

---

## 🎯 主な改善点

### Before（既存）
```bash
# ブックマークを使うには名前を覚える必要があった
bmc go project-name-i-forgot
# → エラー
```

### After（新機能）
```bash
# 1. 最近使ったものを確認
bmc recent

# 2. または履歴から選択
bmc go
# → fzfで選択可能！

# 3. 無効なブックマークを自動検出
bmc doctor
bmc clean
```

---

## 🧹 クリーンアップ

```bash
# テスト用ブックマーク削除
bmc remove work
bmc remove home
bmc remove temp

# テスト用ディレクトリ削除
rm -rf ~/bmc-test

# 履歴クリア（オプション）
rm -f ~/.bm/history
```

---

## 💡 便利な使い方

### 1. 定期的な健康チェック
```bash
# 週1回実行して無効なブックマークを削除
bmc doctor
bmc clean
```

### 2. よく使うブックマークの確認
```bash
# 頻繁に使うものを確認して整理
bmc frequent
```

### 3. すばやいジャンプ
```bash
# 名前を覚えていなくても大丈夫
bmc go  # 履歴から選択
# または
bmc r   # 最近の10件を確認
```

---

## 📚 詳細なテストは TESTING.md を参照

完全なテストガイド、トラブルシューティング、パフォーマンステストなどは
`TESTING.md` に記載されています。
