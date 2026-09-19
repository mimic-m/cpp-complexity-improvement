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
  -DClang_DIR=/path/to/lib/cmake/clang
cmake --build build/custom-check
cmake --build build/custom-check --target company_internal_comments_tests
```

LLVM/Clangの導入先によって `LLVM_DIR` と `Clang_DIR` は変更してください。
