# 品質ルール詳細

## 優先順位

1. 外部I/F・仕様・API/ABI互換性
2. Build / Testの維持
3. 可読性
4. 複雑度の改善
5. メトリクス値そのもの

メトリクスを満たすための仕様変更は禁止する。

## 初期閾値

| 指標 | 初期基準 | 主な用途 |
|---|---:|---|
| Cognitive Complexity | <= 15 | 人間の理解負荷 |
| 関数サイズ | <= 80行 | 関数の大きさ |
| 引数数 | <= 6 | API/責務の複雑さ |
| ネスト深度 | <= 3 | 制御構造の読みやすさ |

プロジェクト既存規約がある場合は、既存規約を優先する。

関数サイズはclang-tidyの`readability-function-size.LineThreshold`で判定する。

## ラチェット方式

| 状態 | 判定 |
|---|---|
| 新規 Cognitive Complexity 8 | PASS |
| 新規 Cognitive Complexity 16 | FAIL / 改善 |
| 既存診断・指標 18 → 18 | 原則許容 |
| 既存診断・指標 18 → 20 | FAIL |
| 既存診断・指標 18 → 14 | PASS |

差分判定のためだけに巨大な独自解析基盤を作らない。

ただし、警告総数だけの比較では、ある関数の改善が別の関数の悪化を相殺できる。少なくとも次のキーで変更前後を比較する。

- ファイルパス
- 関数名または安定した関数識別子
- 関数サイズ
- 引数数
- Cognitive Complexity
- ネスト深度

clang-tidyの診断は、既存コードの警告数だけでなくファイル・関数・診断種別単位で変更前後を比較する。警告総数だけの比較では、ある関数の改善が別の関数の悪化を相殺できるため、ラチェット判定として不十分である。

## 外部I/Fの識別

次のいずれかに該当するものは外部I/F候補として保守的に扱う。

- public/include等の公開ヘッダ
- export指定されたシンボル
- 他モジュール・他ライブラリから参照される関数
- API仕様書に記載された関数・型
- ABI互換性が要求される型
- 外部向けテストが固定するI/F
- CLIオプション、設定ファイル、永続化形式、通信プロトコル
- callback、vtable、FFI境界、プラグイン境界

不明なら変更しない。

## Local Function Naming

### 適用範囲と作成前の確認

関数抽出・分割を含め、新たに作成する内部関数に適用する。例はCのファイルスコープの `static` 関数、C++の無名名前空間内の関数など。公開APIやcallback等の外部契約に拘束される名前は、その契約を優先する。この規則を理由に既存関数を一括改名せず、Readability-onlyモードの変更許可範囲も拡張しない。

新しい関数を作成する前に、同一ファイルおよび同一モジュールの既存関数名・宣言・関連実装を確認する。モジュールの範囲はリポジトリの構成と責務に従う。

同じ責務・操作を表す既存の動詞がある場合は、それを再利用し、新しい同義語を導入しない。辞書上の類似だけで判断せず、処理の意味や契約の違いを表す場合に限り、別の動詞を使用する。

命名の優先順位:

1. リポジトリの明示的な規約
2. 同一ファイル・同一モジュールで同じ責務に定着した命名とドメイン語彙
3. 以下のNaming PatternとPreferred Vocabulary

一般的に正しい英語へ置き換えることより、既存のドメイン語彙との整合を優先する。新しい語彙を導入する場合は、既存語彙では処理の意味や契約を表現できない理由を変更説明に短く記す。

### Naming Pattern

既存規約がなければ、原則として次の形にする。

```text
<verb>_<object>[_<detail>]
```

例: `read_sensor_value()`、`validate_motor_config()`、`update_device_state()`、`handle_timeout()`、`is_sensor_ready()`。

接頭辞・語順・大文字小文字も既存規約を優先する。例えば `sensor_read_value()` が定着していれば、`read_sensor_value()` に変えない。

### Boolean Functions

状態や条件の真偽を返すPredicateには、原則として `is_`、`has_`、`can_`、`should_` を使う。Predicateには、状態変更やイベント消費などの副作用を原則として持たせない。

`bool` を返すことだけを理由にPredicateとみなさない。例えば `is_sensor_ready()` は状態の判定だが、`read_sensor_value()` が読み取り操作の成否を返す場合は、操作を表す名前を維持する。`validate_motor_config()` も検証処理の成否を返す名前として使用できる。

### Preferred Vocabulary

既存の適切な命名がない場合の推奨語彙:

| 動詞 | 意味 |
|---|---|
| `init_` | 初期化 |
| `reset_` | 初期状態へ戻す |
| `clear_` | 内容を消去 |
| `get_` | 保持値を取得 |
| `read_` | HW/I/Oから取得 |
| `set_` | 値を設定 |
| `update_` | 現在値から更新 |
| `validate_` | 妥当性検証 |
| `parse_` | 構文解析 |
| `convert_` | データ変換 |
| `find_` | 検索 |
| `handle_` | イベント処理 |
| `process_` | 一連の処理 |
| `build_` | 構築 |

推奨動詞を使うだけで十分とはせず、目的語や必要な詳細を含め、名前全体で責務が伝わるようにする。

### Avoid

意味が曖昧な `check_`、`do_`、`execute_`、`manage_`、`helper_`、`common_`、`utility_` を安易に使用しない。

例外は、対象モジュールで同じ責務を表す命名として定着している場合とする。リポジトリ内のどこかに使用例があるだけでは例外にしない。

この規則はAgentの作成前確認と変更後レビューに適用する。同義語や責務の違いを、単語の一致だけで機械的なFAIL条件にしない。

## 引数過多の改善ルール

### 内部関数

1. 本当に必要な引数か確認
2. 他の値から安全に導出できないか確認
3. 同じ概念に属する引数をParameter Object化
4. 入力・設定・状態・出力が混在していないか確認
5. 関数の責務過多なら分割

### Parameter Object化の条件

- 同じ概念を表す値が複数ある
- 同じ引数群が複数箇所で使われる
- 設定値群として自然
- 呼び出し時に各位置引数の意味が分かりにくい
- 内部設定項目の拡張可能性が高い

### 禁止

無関係な値を `Args` 構造体へ押し込むだけの変更は禁止。

### 外部公開関数

公開シグネチャは変更しない。

必要なら:

```text
公開API（旧シグネチャを維持）
    ↓
内部Parameter Objectへ変換
    ↓
内部実装関数
```

公開APIに対する「引数数 <= 6」は、外部仕様との競合時には適用除外する。

## 複雑条件式

複雑なBoolean式は、意味のあるPredicateへ分離できるか検討する。

改善前:

```c
if (enabled &&
    sensor_valid &&
    !emergency_stop &&
    (temperature < MAX_TEMP || cooling_active)) {
```

改善後:

```c
if (is_sensor_ready(state) &&
    is_temperature_safe(state)) {
```

## ネスト

深いネストではGuard Clauseを優先する。

ただし以下に注意する。

- cleanup順序
- lock/unlock
- resource release
- 副作用
- エラー処理順序
- 組み込みでの割込み・タイミング依存

可読性向上のために動作を変えない。

## clang-tidy

既存 `.clang-tidy` を上書きしない。

追加対象:

```text
readability-function-cognitive-complexity
readability-function-size
```

clang-tidyの既定値だけでは本スキルの初期基準にならない。Cognitive Complexityの既定閾値は25で、`readability-function-size` の引数数とネスト深度は既定では無効である。既存設定へ、プロジェクト規約に合わせた値をマージする。

規約がない場合の初期設定例:

```yaml
Checks: >
  -*,
  readability-function-cognitive-complexity,
  readability-function-size
CheckOptions:
  readability-function-cognitive-complexity.Threshold: 15
  readability-function-size.LineThreshold: 80
  readability-function-size.ParameterThreshold: 6
  readability-function-size.NestingThreshold: 3
```

既存の `Checks` や `CheckOptions` は保持する。`LineThreshold`はclang-tidyの関数サイズ指標として設定する。

clang-tidyは警告だけでは通常非0を返さない。既存警告がない対象では `--warnings-as-errors='*'` 等で違反を失敗にする。既存警告がある対象では、関数単位のラチェット判定が新規違反・悪化・解析失敗に対して非0を返すようにする。独自チェックを使う場合は、ビルドに使ったLLVMと同じclang-tidyへ `-load` でプラグインを読み込む。

解析には対象ソースを含む有効な `compile_commands.json` が必要である。差分行だけの解析は、関数宣言行に出る診断やヘッダ変更の影響を見落とし得るため、変更関数を含む翻訳単位全体を対象にする。

公開APIが引数数閾値を超える場合は、シグネチャを変えず、仕様上の例外として警告と理由を記録する。無関係な既存警告を一括修正しない。

ツール仕様:

- [clang-tidy: readability-function-cognitive-complexity](https://clang.llvm.org/extra/clang-tidy/checks/readability/function-cognitive-complexity.html)
- [clang-tidy: readability-function-size](https://clang.llvm.org/extra/clang-tidy/checks/readability/function-size.html)

## コメント

関数内コメントは、対象処理のWHYだけでなく、関数を上から読んだときに処理の流れを理解できるようにする。入口から主要な分岐、ループ、状態遷移、正常終了・エラー終了まで、読み手が次の処理へ進む理由を必要な箇所に短く残す。すべての文や自明な処理へ機械的にコメントを付けてはいけない。

良い対象:

- なぜ値が3なのか
- なぜ待ち時間が必要なのか
- なぜ通常経路を使えないのか
- なぜ外部I/Fラッパーが残っているのか
- この処理が関数のどの段階（初期化、検証、通常処理、復旧、終了）に当たるのか
- 複数の分岐やループを経て、次に何を成立させるのか

避けるコメント:

- コードを逐語訳したWHATコメント
- `if`や`return`など構文だけを説明するコメント
- 処理の流れを細切れにして、かえって全体像を隠す大量コメント

## 完了時の外部I/F検証

最低限確認する。

- 公開関数シグネチャ
- 公開型
- 戻り値
- エラーコード
- 可視シンボル
- 呼び出し順序や副作用
- タイミング依存処理
- Unit Test

最終報告に必ず次を記載する。

```text
External Interface Changed: NO
```
