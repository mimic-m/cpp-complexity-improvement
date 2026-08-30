# cpp-complexity-improvement

Agent Skills形式のC/C++複雑度改善スキルです。

- Lizard + clang-tidy
- 外部I/F・API・ABIは変更しない
- 新規コードは閾値遵守
- 既存コードはラチェット方式で悪化禁止
- 引数過多は内部Parameter Object化を検討
- 公開APIはシグネチャを維持し、内部ラッパーで吸収
- Guard Clause / Predicate抽出 / 責務分割
- Build / Test / 再解析を必須化
