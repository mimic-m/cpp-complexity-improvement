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
| Lizard CCN | <= 10 | 分岐・条件式 |
| Lizard NLOC | <= 80 | 関数サイズ |
| Lizard 引数数 | <= 6 | API/責務の複雑さ |
| Cognitive Complexity | <= 15 | 人間の理解負荷 |
| ネスト深度 | <= 3 | 制御構造の読みやすさ |

プロジェクト既存規約がある場合は、既存規約を優先する。

Lizardの `length` と `nloc` は別指標である。NLOCの閾値には `-T nloc=80` を使い、`-L 80` で代用しない。

## ラチェット方式

| 状態 | 判定 |
|---|---|
| 新規 CCN 8 | PASS |
| 新規 CCN 14 | FAIL / 改善 |
| 既存 18 → 18 | 原則許容 |
| 既存 18 → 20 | FAIL |
| 既存 18 → 14 | PASS |

差分判定のためだけに巨大な独自解析基盤を作らない。

ただし、警告総数だけの比較では、ある関数の改善が別の関数の悪化を相殺できる。少なくとも次のキーで変更前後を比較する。

- ファイルパス
- 関数名または安定した関数識別子
- CCN
- NLOC
- 引数数
- Cognitive Complexity
- ネスト深度

Lizardの変更前レポートを終了コードでゲートしない場合は、報告専用として次のように実行できる。

```sh
lizard -C 10 -T nloc=80 -a 6 -i -1 src include
```

`-i -1` は警告を許容してレポートを得るためのオプションであり、ラチェット判定そのものではない。CIの合否は、保存した変更前値との関数単位比較、または新規関数だけの閾値判定で決める。

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
  readability-function-size.ParameterThreshold: 6
  readability-function-size.NestingThreshold: 3
```

既存の `Checks` や `CheckOptions` は保持する。LizardのNLOCとclang-tidyの行数は同一指標ではないため、`LineThreshold` をNLOCの代用として機械的に設定しない。

解析には対象ソースを含む有効な `compile_commands.json` が必要である。差分行だけの解析は、関数宣言行に出る診断やヘッダ変更の影響を見落とし得るため、変更関数を含む翻訳単位全体を対象にする。

公開APIが引数数閾値を超える場合は、シグネチャを変えず、仕様上の例外として警告と理由を記録する。無関係な既存警告を一括修正しない。

ツール仕様:

- [Lizard README](https://github.com/terryyin/lizard/blob/master/README.rst)
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
