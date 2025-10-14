# bookmark-cli 手動テストガイド

## 📋 テスト環境準備

### 1. インストール確認

```bash
# 現在のディレクトリを確認
pwd

# インストールスクリプトを実行（既にインストール済みの場合はスキップ）
./install.sh --prefix=$HOME/.local

# PATH確認
which bmc

# バージョン確認
bmc help | head -1
```

**期待結果**: `bmc - Bookmark Manager CLI v0.1.0` が表示される

---

## 🧪 Phase 1: 基本機能の確認（既存機能）

### テスト1.1: ブックマーク追加

```bash
# テスト用ディレクトリを作成
mkdir -p ~/test-bookmark/{project1,project2,project3}

# ブックマークを追加
cd ~/test-bookmark/project1
bmc add test-proj1

cd ~/test-bookmark/project2
bmc add test-proj2 ~/test-bookmark/project2

cd ~
bmc add home
```

**期待結果**:
- `Bookmark 'test-proj1' added -> /Users/.../test-bookmark/project1`
- `Bookmark 'test-proj2' added -> /Users/.../test-bookmark/project2`
- `Bookmark 'home' added -> /Users/...`

### テスト1.2: ブックマーク一覧

```bash
bmc list
```

**期待結果**:
```
NAME                 PATH
----                 ----
test-proj1          /Users/.../test-bookmark/project1
test-proj2          /Users/.../test-bookmark/project2
home                /Users/...
```

### テスト1.3: ブックマークへ移動

```bash
# goコマンドでテスト（スクリプトとして実行）
bmc go test-proj1

# 現在のディレクトリを確認
pwd
```

**期待結果**:
- パスが表示される: `/Users/.../test-bookmark/project1`

---

## 🔍 Phase 2: 検証・診断機能（新機能）

### テスト2.1: 全ブックマーク検証

```bash
# 全ブックマークが有効な状態で検証
bmc validate
```

**期待結果**:
```
✓ All bookmarks are valid (3/3)
```

### テスト2.2: 無効なブックマークを作成

```bash
# ブックマークファイルに手動で無効なエントリを追加
echo "invalid-bookmark:/nonexistent/path" >> ~/.bm/bookmarks

# 再度検証
bmc validate
```

**期待結果**:
```
✗ Found 1 invalid bookmark(s) out of 4:

invalid-bookmark -> /nonexistent/path
```

### テスト2.3: 診断レポート

```bash
bmc doctor
```

**期待結果**:
```
=== Bookmark Health Diagnostic ===

Statistics:
  Total bookmarks: 4
  Valid: 3
  Invalid: 1

Health Status: ✗ Issues found

Invalid Bookmarks:
  • invalid-bookmark
    Path: /nonexistent/path
    Issue: Directory not found

Recommendations:
  1. Run 'bmc clean' to remove invalid bookmarks
  2. Or manually fix the paths with 'bmc edit'
```

### テスト2.4: クリーンアップ（ドライラン）

```bash
# ドライランで確認
bmc clean --dry-run
```

**期待結果**:
```
Would remove: invalid-bookmark -> /nonexistent/path

Dry run completed. 1 bookmark(s) would be removed.
```

### テスト2.5: 実際のクリーンアップ

```bash
# 実際に削除
bmc clean
```

**期待結果**:
```
Removed: invalid-bookmark -> /nonexistent/path

Cleaned 1 invalid bookmark(s).
```

### テスト2.6: クリーンアップ後の検証

```bash
bmc validate
```

**期待結果**:
```
✓ All bookmarks are valid (3/3)
```

---

## 📊 Phase 3: 履歴・頻度追跡機能（新機能）

### テスト3.1: 履歴の初期状態

```bash
# 履歴が空の状態で確認
bmc recent
```

**期待結果**:
```
No history found.
```

### テスト3.2: ブックマーク使用と履歴記録

```bash
# 複数回ブックマークを使用
bmc go test-proj1
sleep 1
bmc go test-proj2
sleep 1
bmc go home
sleep 1
bmc go test-proj1
sleep 1
bmc go test-proj2
```

**期待結果**: 各コマンドでパスが表示される

### テスト3.3: 最近の履歴表示

```bash
bmc recent
```

**期待結果**:
```
Recent bookmarks (last 10):

NAME                 LAST USED
----                 ---------
test-proj2          2025-10-09 XX:XX
test-proj1          2025-10-09 XX:XX
home                2025-10-09 XX:XX
```

**確認ポイント**:
- 最新のものが上に表示される
- 重複は除去されている（test-proj1, test-proj2は1回ずつのみ）
- 時刻が表示されている

### テスト3.4: エイリアステスト

```bash
bmc r
```

**期待結果**: `bmc recent` と同じ出力

### テスト3.5: 頻度順表示

```bash
bmc frequent
```

**期待結果**:
```
Frequently used bookmarks:

NAME                 COUNT
----                 -----
test-proj1          2
test-proj2          2
home                1
```

### テスト3.6: 統計情報

```bash
bmc stats
```

**期待結果**:
```
=== Bookmark Usage Statistics ===

Total accesses: 5
Unique bookmarks used: 3
Most used: test-proj1 (2 times) または test-proj2 (2 times)

Top 5 bookmarks:
  2 × test-proj1
  2 × test-proj2
  1 × home
```

### テスト3.7: 引数なしgoコマンド（fzf統合）

```bash
# fzfがインストールされている場合のみ
bmc go
```

**期待動作**:
1. fzfのインタラクティブメニューが表示される
2. 履歴から選択できる（矢印キーで選択、Enterで確定）
3. 選択したブックマークに移動する

**fzfがない場合の期待結果**:
```
Error: ブックマーク名が指定されていません
Usage: bmc go <name>
Hint: Install fzf to select from recent history
```

---

## 🎨 Phase 4: UI機能テスト（既存機能の確認）

### テスト4.1: インタラクティブUI

```bash
# fzfがインストールされている場合
bmc ui
```

**期待動作**:
1. ブックマーク一覧がfzfで表示される
2. プレビューペインに詳細が表示される
3. 選択して移動できる

---

## 🧹 Phase 5: クリーンアップ

### テスト終了後のクリーンアップ

```bash
# テスト用ブックマークを削除
bmc remove test-proj1
bmc remove test-proj2
bmc remove home

# テスト用ディレクトリを削除
rm -rf ~/test-bookmark

# 履歴をクリア（オプション）
rm -f ~/.bm/history

# 確認
bmc list
```

**期待結果**:
```
No bookmarks found.
```

---

## ✅ テストチェックリスト

### 基本機能（既存）
- [ ] ブックマーク追加（add）
- [ ] ブックマーク一覧（list）
- [ ] ブックマークへ移動（go）
- [ ] ブックマーク削除（remove）

### 検証・診断機能（新規）
- [ ] validate: 有効なブックマークの検証
- [ ] validate: 無効なブックマークの検出
- [ ] clean --dry-run: ドライラン動作
- [ ] clean: 実際の削除
- [ ] doctor: 診断レポート表示

### 履歴・頻度機能（新規）
- [ ] recent: 最近の履歴表示
- [ ] frequent: 頻度順表示
- [ ] stats: 統計情報表示
- [ ] go (引数なし): fzfからの選択
- [ ] 自動履歴記録: goコマンド実行時

### エイリアス確認
- [ ] bmc r → bmc recent
- [ ] bmc check → bmc validate

---

## 🐛 既知の問題・注意事項

### macOSとLinuxの違い

1. **dateコマンド**
   - macOS: `date -r TIMESTAMP`
   - Linux: `date -d @TIMESTAMP`
   - → 自動検出されますが、古いmacOSでは "Unknown" と表示される可能性があります

2. **tacコマンド**
   - 一部のmacOSではデフォルトでインストールされていない可能性
   - Homebrewでインストール: `brew install coreutils`（gtacとして利用可能）

### fzf必須機能

以下の機能はfzfのインストールが必要です：
- `bmc ui`
- `bmc go` (引数なし)

インストール方法:
```bash
# macOS
brew install fzf

# Ubuntu/Debian
sudo apt install fzf
```

---

## 📈 パフォーマンステスト（オプション）

### 大量ブックマークでのテスト

```bash
# 100個のブックマークを作成
for i in {1..100}; do
  mkdir -p ~/test-bulk/dir$i
  echo "bookmark$i:$HOME/test-bulk/dir$i" >> ~/.bm/bookmarks
done

# 検証速度をテスト
time bmc validate

# 履歴表示速度をテスト
for i in {1..50}; do
  echo "$(date +%s):bookmark$i" >> ~/.bm/history
done

time bmc recent
time bmc frequent

# クリーンアップ
rm -rf ~/test-bulk
sed -i.bak '/bookmark[0-9]/d' ~/.bm/bookmarks
sed -i.bak '/bookmark[0-9]/d' ~/.bm/history
```

**期待パフォーマンス**:
- validate: 100ブックマーク < 1秒
- recent: < 0.1秒
- frequent: < 0.2秒

---

## 🎯 成功基準

全てのテストが期待結果と一致し、以下の条件を満たすこと：

1. ✅ 既存機能が正常に動作する
2. ✅ 新機能（検証・履歴）が仕様通りに動作する
3. ✅ エラーメッセージが適切に表示される
4. ✅ 後方互換性が維持されている
5. ✅ パフォーマンスが許容範囲内

---

## 📞 問題が発生した場合

1. **エラーログの確認**
   ```bash
   # 詳細なエラー表示
   bash -x $(which bmc) validate
   ```

2. **環境情報の収集**
   ```bash
   # シェル情報
   echo $SHELL
   echo $BASH_VERSION
   echo $ZSH_VERSION

   # OS情報
   uname -a

   # bmc情報
   which bmc
   cat ~/.bm/bookmarks
   cat ~/.bm/history
   ```

3. **自動テストの実行**
   ```bash
   # プロジェクトルートで
   npm test
   ```

これらの情報をもとにデバッグできます！
