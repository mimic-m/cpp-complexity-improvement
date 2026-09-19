# cpp-complexity-improvement

> **C/C++の外部I/Fを守りながら、複雑度と可読性を継続的に改善するAgent Skill**

clang-tidyと独自のclang-tidy Checkを組み合わせ、Coding Agentによる安全な品質改善ループを導入します。メトリクスを下げること自体を目的にせず、仕様互換性、Build、Unit Test、読みやすさを優先します。

<p align="center">
	<strong>Build / Test / Analyze / Improve / Verify</strong>
</p>

## Highlights

- **外部I/Fを変更しない**: 公開API、ABI、型、エラーコード、外部シンボルを保護
- **clang-tidy**: Cognitive Complexity、関数サイズ、引数数、ネストを確認
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
 Build -> Unit Test -> clang-tidy
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

このスクリプトはLLVM/Clang 18以降とCMakeを準備し、同じLLVMのClangで`company-internal-comments`をビルドして、そのLLVMのclang-tidyでテストします。`LLVM_VERSION=18`のようにメジャーバージョンを指定できます。LLVMを導入済みで標準外の配置を使う場合は、次のように指定するとパッケージのインストールを省略できます。

```sh
LLVM_DIR=/opt/llvm/lib/cmake/llvm \
Clang_DIR=/opt/llvm/lib/cmake/clang \
SKIP_DEPENDENCY_INSTALL=1 \
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

次は、既存警告がない対象向けに、警告を失敗扱いにする設定例です。`PATH`はプラグインのビルドに使ったLLVMの`bin`へ、`-load`は実際に生成したプラグインの絶対パスへ置き換えます。

```sh
export PATH="/path/to/llvm/bin:$PATH"
BUILD_COMMAND='cmake --build build' \
TEST_COMMAND='ctest --test-dir build --output-on-failure' \
CLANG_TIDY_COMMAND='run-clang-tidy -p build -load "/path/to/company-internal-comments.so" -warnings-as-errors="*"' \
bash tools/check-quality.sh
```

`compile_commands.json`を生成し、既存の`.clang-tidy`へ設定例をマージしてください。独自チェックは名前を設定するだけでは有効にならず、解析時の`-load`が必要です。

既存警告がある対象では、一括で警告をエラー化せず、`CLANG_TIDY_COMMAND`に導入先の関数単位のラチェット判定コマンドを設定します。そのコマンドはプラグインを読み込んで解析し、新規違反・指標悪化・解析失敗で非0を返す必要があります。設定例の`WarningsAsErrors`もこの運用に合わせて調整します。`tools/check-quality.sh`自体は診断の比較を行わず、各コマンドの終了コードを伝播します。

## Initial Thresholds

| Metric | Initial threshold | Policy |
| --- | ---: | --- |
| Cognitive Complexity | `<= 15` | New internal code |
| Function size | `<= 80 lines` | New internal code |
| Function arguments | `<= 6` | New internal code |
| Nesting depth | `<= 3` | New internal code |

既存コードは閾値超過だけで失敗にせず、ファイル・関数・指標単位で悪化を禁止します。clang-tidyの各診断を変更前後で比較し、既存警告の一括修正は行いません。プロジェクト固有規約がある場合はそちらを優先します。

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
tools/check-quality.sh        # Build -> Test -> clang-tidy
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
- 品質入口は導入先のBuild/Test/clang-tidyコマンド設定が必要です。
- このリポジトリ自身はC/C++製品ソースを含まないため、製品のBuild/Test結果は報告対象にしません。

## License

ライセンスが未定義のため、利用前にリポジトリ管理者の方針を確認してください。

## Compatibility Promise

品質改善のために外部I/Fを変更しません。不明なI/Fは外部I/Fとして扱い、変更せずに提案として報告します。

```text
External Interface Changed: NO
```
