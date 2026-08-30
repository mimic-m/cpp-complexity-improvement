# Readability-onlyルール

## 目的と適用条件

外部仕様、動作、タイミング、メモリ配置を変えず、対象C/C++ファイルを上から読んだときの理解コストを下げる。

ユーザーがコメント改善、処理構造の可視化、関数定義の並び替えなどを求め、ロジックや構造の変更を求めていない場合に適用する。機能追加や一般的なリファクタリングとは分離する。

リポジトリ固有の指示やユーザーが指定した変更範囲を優先する。このルールと競合しない [品質ルール](QUALITY_RULES.md) は引き続き適用する。

## 編集前に確認する

ユーザーが範囲を指定していない場合は、最初は1ファイルに絞る。関数単体だけを見ず、対象ファイル全体と関連する公開宣言・テストを読む。

次を説明できる状態にしてから編集する。

- ファイルの責務
- public/external entry point
- internal helper
- 初期化、通常処理、エラー処理、recovery/cleanupの流れ
- hardware、protocol、timing、memory layout上の制約
- 関数の論理グループと現在の読み順

既存のBuild、Test、Lizard、clang-tidy、format手順を確認し、編集前の結果を記録する。リポジトリに既存の可読性監査スクリプトや設定があれば利用するが、存在しない補助ファイル、設定、レポートを前提にしない。

## 変更してよいもの

原則として次に限定する。

- WHY / INTENT / CONSTRAINT / INVARIANTを示す短いコメント
- 長い処理のPHASEを示すコメント
- ファイル内の論理セクションコメント
- 安全性を確認できた関数定義の並び替え
- 並び替えに必要なinternal/static関数のforward declaration
- 既存format規約による変更箇所中心のformat

## デフォルトでは変更しないもの

明示指示がない限り変更しない。

- public APIの名前、引数、戻り値
- 型定義
- グローバル変数、file-static変数の定義順
- マクロ定義の順序・内容
- `#if` / `#ifdef` / `#pragma` を跨ぐ移動
- `volatile` / `const` / `restrict` 等のqualifier
- ISR、callback、registrationの意味や順序
- `section` / `packed` / `aligned` / `weak` / `constructor` 等のattribute
- リンカ配置に関係する定義
- static objectの初期化順
- テーブル・配列の要素順
- 関数分割
- rename
- 条件式・アルゴリズムの書き換え

関数分割、Boolean分解、helper関数化が有効でも、このモードでは変更せず次段階候補として報告する。

## 読みにくさを評価する

次の観点で現在の配置と説明不足を確認する。

- 主要entry pointが見つけやすいか
- main flowからhelperへ自然に読み進められるか
- 同じ責務の関数が離れていないか
- utilityが主要処理を分断していないか
- prototypeとdefinitionの対応が追いやすいか
- cleanupや例外経路の制約がコードだけで理解できるか

Lizardやclang-tidyの値は書き換え命令ではなく、詳しく読む箇所を選ぶシグナルとして使う。プロジェクト規約がなければ次を注意ラインにできる。

- CCN >= 10: 注意、CCN >= 15: 高優先
- NLOC >= 40: 注意、NLOC >= 80: 高優先
- 引数数 >= 6
- branchやnestingが多い
- clang-tidy readability診断が集中している

既存コードで対象が多すぎる場合は、現在値の上位10〜20%などレビュー可能な範囲へ絞る。閾値超過だけを理由に変更しない。

## コメントを改善する

コードだけから判断しづらい次の情報を書く。

- WHY: なぜ処理が必要か
- INTENT: 何を成立させたいか
- CONSTRAINT: hardware、通信仕様、互換性、timing等の制約
- INVARIANT: 維持すべき状態
- PHASE: 長い処理のどの段階か

良い例:

```c
/* Ignore the first sample because the sensor output is unstable after power-on. */
```

```c
/* Validate the complete frame before updating externally visible state. */
```

複雑な条件式も、まず条件全体の制御上の意味を説明する。

```c
/* Enter recovery only when the link is healthy and retry is still permitted. */
if (link_ok && !fatal_error && retry_count < MAX_RETRY) {
```

次は行わない。

- コードをそのまま文章化するコメント
- 全if、loop、functionへの機械的なコメント
- 変数名から分かる内容の説明
- 自明なgetter、setter、wrapperへの説明追加
- Doxygen形式の新規一括導入

既存コメントが正しければ残し、古いコメントやコードと矛盾するコメントは修正する。コメントは可能な限り1〜2行にする。

仕様、コード、テストから確認できない理由を推測でコメントにしない。意図を裏付けられない場合はコメントを追加せず、確認事項として報告する。

## 関数定義を整理する

プロジェクト固有ルールがなければ、読み手が主要処理から詳細へ降りられる順序を目安にする。

```text
1. include
2. macro / constant
3. type declarations
4. file-scope variables
5. internal function prototypes
6. public / externally important entry points
7. feature group A: main flow → helpers
8. feature group B: main flow → helpers
9. generic internal utilities
```

static helperをcallerより下へ移す場合は、必要なprototypeを追加する。

関数定義は次をすべて確認できる場合だけ移動する。

- 通常の関数定義である
- preprocessor blockを跨がない
- attribute、pragma、section配置に依存しない
- 関数アドレスの登録順などに意味がない
- 宣言不足を生じない
- C/C++の初期化順、リンカ配置、メモリ配置に影響しない

判断できない場合は移動せず、提案だけを残す。

## Formatと検証

既存format規約を優先する。clang-formatが既に設定されている場合も変更箇所中心に適用し、ファイル全体の無関係なformat差分を作らない。新しいformatツールをこのモードだけのために追加しない。

編集後は変更前と同じBuild、Test、Lizard、clang-tidyを再実行し、`git diff` で次を確認する。

- 挙動変更を伴う差分がない
- 差分が許可されたコメント、関数移動、forward declaration、局所formatだけである
- 条件式やアルゴリズムを書き換えていない
- qualifierやattributeを落としていない
- 無関係なformat差分がない
- コメントがコードと矛盾していない
- 新規コンパイラ警告を増やしていない

実行不能な検証は `PASS` とせず、コマンドと理由を記録する。

## 完了報告

```text
対象:
- <files>

構造分析:
- ファイルの責務:
- 主な処理フロー:
- 読みにくさの主因:

実施:
- コメント:
- 関数順序整理:
- format:

定量結果:
- Max CCN: before -> after
- High-priority functions: before -> after
- clang-tidy diagnostics: before -> after

検証:
- build: PASS/FAIL/未実施
- test: PASS/FAIL/未実施

変更しなかった次段階候補:
- 必要な場合のみ

External Interface Changed: NO
```
