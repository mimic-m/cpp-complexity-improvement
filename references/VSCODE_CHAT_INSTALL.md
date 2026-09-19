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

このスクリプトはLLVM/Clang 18以降とCMakeを準備し、選択したLLVMのClangで`company-internal-comments`をビルドして、同じLLVMのclang-tidyでテストします。作業ディレクトリはリポジトリ外でも構いません。

環境変数で上書きできます。

```sh
LLVM_VERSION=18 PREFIX="$HOME/.local" bash scripts/install-codex.sh
```

LLVMを手動で導入済みでCMake設定ファイルの場所が標準外の場合は、`LLVM_DIR`と`Clang_DIR`を指定してください。

```sh
LLVM_DIR=/opt/llvm/lib/cmake/llvm \
Clang_DIR=/opt/llvm/lib/cmake/clang \
SKIP_DEPENDENCY_INSTALL=1 \
bash scripts/install-codex.sh
```

`LLVM_CONFIG`で`llvm-config`の実行ファイルを指定できます。未指定時は`LLVM_DIR`に対応する配置、`LLVM_VERSION`付きのコマンド、Homebrewのprefixから選択します。`CLANG_TIDY`も上書きできますが、LLVMのメジャーバージョンが一致しない場合は停止します。`CXX`未指定時は同じLLVMの`clang++`を使います。コンパイラやLLVMのバージョンを変える場合は、`BUILD_DIR`を別ディレクトリにしてください。

インストール後は、[品質チェックの設定例](../README.md#integrate-with-a-cc-project)に従い、Build、Unit Test、プラグイン読み込みを含む解析・合否判定コマンドを設定します。
