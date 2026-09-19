# company-internal-comments

LLVM/clang-tidyの正式なモジュールとして、関数内の重要な制御点に直前コメントがあることを検査します。

## 対象

- Boolean演算数が `BooleanOperatorThreshold` を超える `if`
- `for` / `while`
- `StateNamesRegex` に一致する代入
- `StateSetterRegex` に一致する状態変更関数呼び出し

コメント本文の意味は判定しません。FixItも生成しません。コメントの内容はCoding Agentが確認し、WHYと関数内の処理段階・流れが理解できるように記述します。マクロ展開内は誤検出防止のため除外します。既存の `NOLINT(company-internal-comments)` を利用できます。

## ビルドとテスト

```sh
cmake -S custom-check -B build/custom-check \
  -DLLVM_DIR=/path/to/lib/cmake/llvm \
  -DClang_DIR=/path/to/lib/cmake/clang \
  -DCMAKE_CXX_COMPILER=/path/to/bin/clang++ \
  -DCLANG_TIDY_EXECUTABLE=/path/to/bin/clang-tidy
cmake --build build/custom-check
cmake --build build/custom-check --target company_internal_comments_tests
```

LLVM/Clang 18以降が必要です。パスは同じLLVMの導入先へ揃えてください。配布LLVMと異なるコンパイラのABIでビルドすると、ロード時に未解決シンボルが発生する場合があります。
CMakeの標準ジェネレーターを使用するため、Ninjaは必要ありません。既存のMakeやXcodeなど、環境にあるCMake対応のビルドツールが選択されます。

テストはプラグインの登録、正常終了、成功用0件・失敗用7件の診断を確認します。Boolean演算子数1は対象外、2は対象とし、演算子オーバーロード呼び出しでも停止しないことを検証します。

インストーラーのツール選択、テスト実行中の異常終了、品質ゲートの回帰テスト:

```sh
python3 tests/test_tooling.py /path/to/bin/clang-tidy
```

実プロジェクトの解析でも`-load /path/to/company-internal-comments.so`を指定します。警告の合否判定は[品質チェックの設定例](../README.md#integrate-with-a-cc-project)を参照してください。
