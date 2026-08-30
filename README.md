# cpp-complexity-improvement

Agent Skills形式のC/C++複雑度・可読性改善スキルです。

## モード

- **複雑度改善**: Guard Clause、Predicate抽出、内部Parameter Object、責務分割で複雑度を改善
- **Readability-only**: 挙動を変えず、意図コメント、処理フェーズの可視化、安全な関数順序整理だけを実施

- Lizard + clang-tidy
- 外部I/F・API・ABIは変更しない
- 新規内部コードは明示した閾値で確認
- 既存コードは関数・指標単位のラチェット方式で悪化禁止
- 引数過多は内部Parameter Object化を検討
- 公開APIはシグネチャを維持し、内部ラッパーで吸収
- Guard Clause / Predicate抽出 / 責務分割
- Build / Test / Lizard / clang-tidy の実行結果と未実施理由を明示

詳細な判断基準は `references/QUALITY_RULES.md`、Readability-onlyの変更許可範囲は `references/READABILITY_ONLY.md`、品質コマンドの雛形は `assets/check-quality.sh.template` にあります。雛形は未設定のフェーズがある限り終了コード2で失敗し、空の品質チェックを成功扱いしません。
