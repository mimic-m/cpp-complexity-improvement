# VS Code Chat / Codexからのインストール

このリポジトリには、同じインストール処理を呼び出す2つの入口があります。

## VS Code Chat

VS Code Chatで次のように依頼してください。

```text
このワークスペースの「Install C/C++ quality skill (Codex/Chat)」タスクを実行してください。
```

または、ターミナルで次を実行します。

```sh
bash scripts/install-vscode-chat.sh
```

Chatの実行環境がタスク実行を許可しない場合は、ターミナルで上記コマンドを実行してください。Linuxでは`apt-get`、macOSではHomebrewを使用します。管理者権限またはsudoが必要になる場合があります。

## Codex

```sh
bash scripts/install-codex.sh
```

このスクリプトはLLVM/Clang、CMake、Ninja、Lizardを準備し、`company-internal-comments`をビルドしてテストします。作業ディレクトリはリポジトリ外でも構いません。

環境変数で上書きできます。

```sh
LLVM_VERSION=18 PREFIX="$HOME/.local" bash scripts/install-codex.sh
```

LLVMを手動で導入済みでCMake設定ファイルの場所が標準外の場合は、`LLVM_DIR`と`Clang_DIR`を指定してください。

```sh
LLVM_DIR=/opt/llvm/lib/cmake/llvm \
Clang_DIR=/opt/llvm/lib/cmake/clang \
bash scripts/install-codex.sh
```

インストール後の品質チェックは、導入先プロジェクトで`tools/check-quality.sh`にBuild、Unit Test、Lizard、clang-tidyのコマンドを設定して実行します。