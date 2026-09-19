---
name: cpp-complexity-improvement
description: Review and refactor existing C/C++ code with Lizard and clang-tidy while preserving external API/ABI. Use for complexity gates, legacy-code ratchets, or no-behavior-change readability passes limited to intent comments and safe function ordering; not for general feature work.
metadata:
  version: "1.2"
  language: "ja"
  compatibility: "Requires repository inspection and shell access; Lizard and clang-tidy may need project-approved installation."
---

# C/C++ Complexity Improvement

既存C/C++プロジェクトへ **Lizard + clang-tidy** による複雑度解析、ラチェット、動作保持リファクタリングを導入・適用する。

## モード選択

依頼の変更許可範囲に合わせ、最初にモードを選ぶ。

- **複雑度改善モード**: Guard Clause、Predicate抽出、内部Parameter Object、責務分割などにより複雑度を改善する。以降のワークフローと [品質ルール](references/QUALITY_RULES.md) を適用する。
- **Readability-onlyモード**: 挙動やロジックを変えず、WHY/INTENT/CONSTRAINTコメント、処理フェーズの可視化、安全な関数定義順の整理、変更箇所のformatだけを行う。選択したら [Readability-onlyルール](references/READABILITY_ONLY.md) を全文読み、その狭い変更許可範囲を優先する。

依頼が両方を含む場合は、readability-onlyの差分と構造リファクタリングの差分を可能な限り段階分けし、どちらのモードで各変更を行ったか報告する。

## 必須条件

- 外部I/F・API/ABI・呼び出し側から観測可能な動作を変更しない。
- 品質指標より既存仕様、Build、Testを優先する。
- 追加する品質解析OSSは原則 Lizard と clang-tidy だけにする。既存ツールは維持する。
- 実行していない検証や、ツール不足で実行できなかった検証を `PASS` と報告しない。
- メトリクス値だけを下げるための分割、命名、抑制を行わない。

外部I/Fか内部I/Fか判断できない場合は変更しない。閾値、ラチェット、例外、ツール設定を適用するときは [品質ルール](references/QUALITY_RULES.md) を読む。

## ワークフロー

### 1. リポジトリと外部I/Fを調査する

変更前に次を確認する。

- C/C++ソース、公開/内部ヘッダ、仕様、テスト
- Build/Test手順、CMake/Make/Meson/Ninja等の既存方式
- `compile_commands.json` の生成方法と対象ファイルの収録状況
- `.clang-tidy`、Lizard設定、既存静的解析、CI
- `AGENTS.md`、`tools/`、`scripts/`、`ci/` 等のリポジトリ固有指示
- 公開関数、公開型、エラーコード、エクスポートシンボル、CLI、プロトコル、ファイル形式などの保護対象

既存のコマンドやCIジョブを拡張し、重複する仕組みを作らない。

### 2. 編集前のベースラインを取得する

実際のリポジトリ手順で、編集前に次を実行・記録する。

- Buildと関連Unit Test
- Lizardとclang-tidyのバージョン
- 変更候補関数の CCN、NLOC、引数数、Cognitive Complexity、ネスト深度
- 既存警告と対象外理由

Build、Test、ツール、コンパイルDBが利用不能なら、試したコマンドと原因を記録する。利用不能な項目は `未実施` または `確認不可` とし、検証済みとは扱わない。

### 3. ゲート方式を決める

新規内部コードにはプロジェクト規約を優先し、規約がなければ次を初期目安にする。

- CCN <= 10
- NLOC <= 80
- 引数数 <= 6
- Cognitive Complexity <= 15
- ネスト深度 <= 3

既存コードは、閾値超過だけで一括FAILにしない。関数単位・指標単位の変更前値と比較し、悪化を禁止して改善または維持を要求する。警告総数だけの比較では、別の悪化が改善に相殺されるためラチェットとして不十分である。

LizardでNLOCを指定するときは `-L` ではなく `-T nloc=80` を使う。`-L` は関数長の閾値であり、NLOCと同一ではない。

clang-tidyでは対象チェックを有効化し、意図する閾値を明示する。既存 `.clang-tidy` は上書きせずマージする。差分行だけではなく、変更した関数を含む翻訳単位全体を解析する。

### 4. 品質チェックを統合する

可能なら既存の1コマンドへ次の順序を統合する。

```text
Build
→ Unit Test
→ Lizard
→ clang-tidy
```

既存コマンドがなければ `assets/check-quality.sh.template` をコピーしてプロジェクト用に置き換える。このテンプレートは未設定のままでは明示的に失敗する。全フェーズを実コマンドへ置き換え、レガシーコードには関数単位のラチェット判定を追加してから利用する。

### 5. 原因に応じて改善する

以下は複雑度改善モードで適用する。Readability-onlyモードでは構造変更を行わず、参照ルールに従う。

複雑な分岐・ネストは次の順に検討する。

1. Guard Clause
2. 条件への意味付け
3. 意味のあるPredicate関数への抽出
4. 責務単位の関数分割

`check1()` や `conditionA()` のような、指標低減だけを目的とする抽出は禁止する。

内部関数の引数過多は次の順に検討する。

1. 不要・安全に導出可能な引数を除く
2. 同じ概念の値をドメイン上意味のあるParameter Objectへまとめる
3. 責務過多なら関数を分割する

公開APIのシグネチャは変更しない。必要なら既存の公開APIをラッパーとして残し、内部だけParameter Object化する。公開APIの引数数超過は仕様上の例外として記録する。

cleanup順序、lock/unlock、resource release、副作用、エラー順序、タイミング制約を保つ。コードから明白なWHATコメントを増やさず、制約や互換性処理などのWHYを残す。関数内を上から読んだときに、初期化、検証、通常処理、復旧、終了などの処理段階と主要な分岐・ループのつながりが理解できるようにする。ただし、すべての文へコメントを付けず、流れの理解に必要な箇所へ限定する。

### 6. 同じ条件で再検証する

変更前と同じBuild、Unit Test、Lizard、clang-tidyを再実行する。次も確認する。

- 変更関数の各指標が悪化していない
- 新規内部コードが基準内、または例外理由が記録されている
- 新規警告が増えていない
- 公開ヘッダ、公開型、シグネチャ、可視シンボル、戻り値、エラーコードに意図しない差分がない
- 呼び出し順序、副作用、タイミング依存処理を関連テストで維持している

失敗時は原因を修正して同じ一式を再実行する。環境上実行不能な項目は、完了条件から黙って除外せず明示する。

## 完了報告

以下を簡潔に報告する。

1. プロジェクト調査結果
2. 導入・変更した品質チェック
3. Build / Test / Lizard / clang-tidy の実行コマンドと結果（未実施理由を含む）
4. 変更関数の主要メトリクス Before / After
5. Parameter Object化した場合の構造体名と理由
6. 既存違反として残した項目
7. `External Interface Changed: NO`

Readability-onlyモードでは、上記に加えて参照ルールの専用報告形式を使う。

外部I/F変更が必要に見える場合でも自動変更せず、提案として分離する。
