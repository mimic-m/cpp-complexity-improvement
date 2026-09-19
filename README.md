# cpp-complexity-improvement

> **C/C++の外部I/Fを守りながら、複雑度と可読性を継続的に改善するAgent Skill**

Lizard、clang-tidy、独自のclang-tidy Checkを組み合わせ、Coding Agentによる安全な品質改善ループを導入します。メトリクスを下げること自体を目的にせず、仕様互換性、Build、Unit Test、読みやすさを優先します。

<p align="center">
	<strong>Build / Test / Analyze / Improve / Verify</strong>
</p>

## Highlights

- **外部I/Fを変更しない**: 公開API、ABI、型、エラーコード、外部シンボルを保護
- **Lizard**: CCN、NLOC、引数数を測定
- **clang-tidy**: Cognitive Complexity、関数サイズ、ネストを確認
- **独自Check**: `company-internal-comments`で複雑な制御点と状態遷移のコメントを検査
- **ラチェット方式**: 既存コードの大量修正を避け、関数単位の悪化を防止
- **Agent対応**: 問題分類、WHYコメント、再解析までの作業ルールを提供
- **VS Code Chat / Codex対応**: セットアップ用スクリプトとVS Codeタスクを同梱

## Quality Loop

```text
Coding Agent
		 |
		 v
	Code change
		 |
		 v
 Build -> Unit Test -> Lizard -> clang-tidy
																			|
																			v
												 Classify and improve safely
																			|
																			+----> re-run quality checks
```

品質の優先順位は次の通りです。

1. 外部I/F・仕様・API/ABI互換性
2. Build / Unit Test
3. Repository styleと可読性
4. 複雑度
5. メトリクス値

## Quick Start

### Codex / Linux or macOS

```sh
bash scripts/install-codex.sh
```

このスクリプトはLLVM/Clang、CMake、Ninja、Lizardを準備し、`company-internal-comments`のビルドとテストを実行します。標準外のLLVMを使う場合は次のように指定できます。

```sh
LLVM_DIR=/opt/llvm/lib/cmake/llvm \
Clang_DIR=/opt/llvm/lib/cmake/clang \
bash scripts/install-codex.sh
```

### VS Code Chat

VS Code Chatで次を依頼するか、コマンドパレットからタスクを実行します。

```text
このワークスペースの「Install C/C++ quality skill (Codex/Chat)」タスクを実行してください。
```

手動実行:

```sh
bash scripts/install-vscode-chat.sh
```

詳細は [VS Code Chat / Codex導入手順](references/VSCODE_CHAT_INSTALL.md) を参照してください。

## Integrate With a C/C++ Project

このリポジトリは品質基盤を提供するSkillであり、製品コードや特定のBuild Systemは含みません。導入先プロジェクトでは、既存のBuild/Test手順を維持したまま、品質チェック入口へコマンドを設定します。

```sh
BUILD_COMMAND='cmake --build build' \
TEST_COMMAND='ctest --test-dir build --output-on-failure' \
LIZARD_COMMAND='lizard -C 10 -T nloc=80 -a 6 -i -1 src include' \
CLANG_TIDY_COMMAND='run-clang-tidy -p build' \
bash tools/check-quality.sh
```

`compile_commands.json`を生成し、既存の`.clang-tidy`へ設定例をマージしてください。既存設定の上書きや、既存違反の一括修正は行いません。

## Initial Thresholds

| Metric | Initial threshold | Policy |
| --- | ---: | --- |
| Lizard CCN | `<= 10` | New internal code |
| Lizard NLOC | `<= 80` | New internal code |
| Lizard arguments | `<= 6` | New internal code |
| Cognitive Complexity | `<= 15` | New internal code |
| Nesting depth | `<= 3` | New internal code |

既存コードは閾値超過だけで失敗にせず、ファイル・関数・指標単位で悪化を禁止します。たとえば既存CCN `18 -> 18`は原則許容、`18 -> 20`は改善対象です。プロジェクト固有規約がある場合はそちらを優先します。

## Comment Check

`company-internal-comments`は、関数内の理解上重要な箇所にコメントがあるかをASTで検査します。コメント本文の自然言語評価や自動FixItは行いません。

対象:

- Boolean演算が閾値を超える複雑な`if`
- `for` / `while`
- 状態変数への代入
- `set_state`などの状態変更関数

Agentは、単なるWHATではなく、制御のWHYと処理の流れが分かるコメントを書きます。初期化、検証、通常処理、復旧、終了などの段階や、状態遷移の理由を説明し、自明な処理へ大量にコメントしません。

```cpp
// Reject the frame before updating externally visible state.
if (header_valid && payload_valid) {
	publish_frame(frame);
}
```

設定例は [custom-check/clang-tidy.example.yaml](custom-check/clang-tidy.example.yaml) にあります。

## Repository Layout

```text
custom-check/                 # company-internal-commentsの実装とテスト
	include/                    # Checkヘッダ
	src/                        # clang-tidyモジュール
	tests/                      # PASS / FAILフィクスチャ
references/                   # 品質ルールとAgent運用ルール
scripts/                      # Codex / VS Code Chat導入スクリプト
tools/check-quality.sh        # Build -> Test -> Lizard -> clang-tidy
assets/                       # プロジェクトへコピーする雛形
```

## Documentation

- [品質ルール](references/QUALITY_RULES.md)
- [Readability-onlyルール](references/READABILITY_ONLY.md)
- [Coding Agent品質ループ](references/AGENT_QUALITY_LOOP.md)
- [Custom Checkのビルドとテスト](custom-check/README.md)
- [VS Code Chat / Codex導入手順](references/VSCODE_CHAT_INSTALL.md)
- [品質チェック入口の雛形](assets/check-quality.sh.template)

## Scope and Limitations

- Generated、third-party、vendor、externalコードは導入先の既存ルールに従って除外します。
- Custom Checkは初期実装でマクロ展開内を除外します。
- 品質入口は導入先のBuild/Test/Lizard/clang-tidyコマンド設定が必要です。
- このリポジトリ自身はC/C++製品ソースを含まないため、製品のBuild/Test結果は報告対象にしません。

## License

ライセンスが未定義のため、利用前にリポジトリ管理者の方針を確認してください。

## Compatibility Promise

品質改善のために外部I/Fを変更しません。不明なI/Fは外部I/Fとして扱い、変更せずに提案として報告します。

```text
External Interface Changed: NO
```
