---
name: cpp-complexity-improvement
description: Introduces and applies a repeatable C/C++ complexity-improvement workflow using Lizard and clang-tidy. Use when adding code-quality gates, analyzing cyclomatic/cognitive complexity, reducing nesting or complex conditions, refactoring functions with too many parameters, or improving changed legacy code while strictly preserving external API/ABI and interface specifications.
compatibility: Designed for coding agents that can inspect and edit a local C/C++ repository and run shell commands. Lizard and clang-tidy may need to be installed in the target environment.
metadata:
  version: "1.0"
  language: "ja"
---

# C/C++ Complexity Improvement

このスキルは、既存C/C++プロジェクトへ **Lizard + clang-tidy** による複雑度解析と自己修正ループを導入・適用する。

## 最重要ルール

**外部I/F仕様を変更してはならない。**

品質指標より、外部仕様・API/ABI互換性・既存動作を優先する。

保護対象には少なくとも以下を含める。

- 公開関数名
- 公開関数の引数型・順序・個数
- 戻り値型とエラーコード
- 公開構造体・列挙型・定数
- 外部参照シンボル
- ABI
- 外部仕様書で定義されたI/F
- 呼び出し側から観測可能な動作

外部I/Fか内部I/Fか判断できない場合は、**変更しない**。

詳細は [品質ルール](references/QUALITY_RULES.md) を参照する。

## 使用する品質ツール

追加する品質解析OSSは原則として次の2つだけにする。

- Lizard
- clang-tidy

既存のBuild、Test、CI、静的解析ツールは尊重し、重複する仕組みを作らない。

## ワークフロー

### 1. 変更前にプロジェクトを調査する

次を確認する。

- C/C++ソースとヘッダの配置
- 公開ヘッダと内部ヘッダ
- Build方法
- Test方法
- CMake / Make / Ninja等
- `compile_commands.json`
- `.clang-tidy`
- CI設定
- `AGENTS.md` 等のAgent指示
- `tools/`、`scripts/`、`ci/`
- 外部I/Fを定義するコード・仕様・テスト

既存方式を優先し、最小変更で導入する。

### 2. ベースラインを取得する

変更対象関数について可能なら変更前の以下を記録する。

- CCN
- NLOC
- 引数数
- Cognitive Complexity
- ネスト深度

レガシーコードでは絶対値だけでFAILさせず、ラチェット方式を使う。

### 3. 品質チェックを統合する

プロジェクトの既存方式に合わせ、可能なら1コマンドで以下を実行できるようにする。

```text
Build
→ Unit Test
→ Lizard
→ clang-tidy
```

既存コマンドがなければ、`assets/check-quality.sh.template` を参考にプロジェクト用スクリプトを作る。

### 4. 基準を適用する

新規内部コードの初期目安:

- CCN <= 10
- NLOC <= 80
- 引数数 <= 6
- Cognitive Complexity <= 15
- ネスト深度 <= 3

既存コード:

- 基準超過だけでは直ちにFAILにしない
- 変更による悪化を禁止する
- 可能なら改善する

### 5. 違反時は原因別に改善する

#### 複雑な分岐・ネスト

次の順に検討する。

1. Guard Clause
2. 条件への意味付け
3. Predicate関数への抽出
4. 責務単位の関数分割

`check1()` や `conditionA()` のような、メトリクス低減だけを目的とする抽出は禁止する。

#### 引数過多

内部関数で引数数が多い場合は次の順に検討する。

1. 不要・導出可能な引数を確認
2. 意味的に同じ引数群を構造体（Parameter Object）へまとめる
3. 責務過多なら関数分割

構造体はドメイン上の意味を持たせる。

良い例:

```c
typedef struct {
    int target_speed;
    int max_current;
    int timeout_ms;
} MotorStartConfig;
```

悪い例:

```c
typedef struct {
    int arg1;
    int arg2;
    int arg3;
} FunctionArgs;
```

### 6. 外部I/Fの引数は変更しない

公開APIの引数が多くても、シグネチャを変更してはならない。

必要なら、公開APIをラッパーとして維持し、内部だけParameter Object化する。

```c
int motor_start(Motor *m, int speed, int current, int timeout_ms)
{
    const MotorStartConfig config = {
        .target_speed = speed,
        .max_current = current,
        .timeout_ms = timeout_ms,
    };

    return motor_start_internal(m, &config);
}
```

外部APIの引数数超過は、仕様上の例外として記録する。

### 7. コメントを自己レビューする

コメント率を品質指標にしない。

コードから明白なWHATコメントを増やさず、次のWHYを必要に応じて残す。

- ハードウェア制約
- タイミング制約
- Magic Numberの理由
- 仕様上の例外
- Workaround
- 特殊アルゴリズム
- 互換性維持処理

### 8. 改善後に必ず再検証する

改善したら必ず再実行する。

```text
Build
→ Unit Test
→ Lizard
→ clang-tidy
```

さらに外部I/Fが変わっていないことを確認する。

## 完了条件

- Build PASS
- Unit Test PASS
- Lizard確認済み
- clang-tidy確認済み
- 新規警告を増やしていない
- 新規内部コードは原則として基準内
- 既存コードの複雑度を悪化させていない
- 外部I/F・API・ABI変更なし

## 完了報告

以下を簡潔に報告する。

1. プロジェクト調査結果
2. 導入・変更した品質チェック
3. Build / Test / Lizard / clang-tidy結果
4. 変更関数の主要メトリクス Before / After
5. Parameter Object化した場合の構造体名と理由
6. 既存違反として残した項目
7. `External Interface Changed: NO`

外部I/F変更が必要に見える場合でも自動変更せず、提案として分離する。
