# Fable Build — Semantic Parity Report

単一の累積レポート。`fable-build` の各ビルドはこのファイルにマージする（追記で2つ目のレポートブロックを作らない）。

- Last build: 2026-07-11（初回ビルド）
- Builder: Fable（ビルダーモデル）
- 対象: canonical 12 スキル × Claude/Codex ラッパー、および agent 定義 6 ペア
- 手法: 各 canonical スキルの拘束項目（Procedure の必須ステップ / Forbidden / Done criteria）を抽出し、Claude ラッパーと Codex ラッパーが「文言は違っても同じ振る舞いをプロンプトするか」を突き合わせた。字面 diff ではなく意味比較。スクリプト（`scripts/fable-build.sh`）は列挙・diff 提示・形式検証のみで、この判定には関与していない。

## 判定基準

- ラッパーは全文冒頭で canonical への差し戻し（deferral）を明記しているため、**個別ステップの省略それ自体は不合格ではない**。不合格となるのは (a) Claude/Codex の一方だけがある振る舞いをプロンプトする非対称で正当な根拠がないもの、(b) canonical の Forbidden と矛盾する記述、(c) ラッパーへの新規手続きの混入。
- 正当なプラットフォーム非対称（例: compact の扱い）は「根拠付きで維持」する。

## スキル別パリティ表

| スキル | 拘束項目カバレッジ（Claude / Codex） | 非対称・所見 | 判定 |
|---|---|---|---|
| project-bootstrap | 観測専用・コマンド出典必須・秘密情報不読・仮説と事実の分離: 両者 OK | Codex 版に「テスト戦略の観測」と「ユーザーへの最終サマリ報告」がなく Claude 版のみ存在（根拠のない非対称） | **修正適用**（Codex に 2 項目追加） |
| project-profile | 事実/仮説分離・単一guess昇格禁止・肥大化禁止・訂正の明示: 両者 OK | Codex 版に「last updated 行の記録」（canonical step 7、Claude 版は step 7 で明記）がない | **修正適用**（Codex に 1 項目追加） |
| adapt-to-project | 仮説昇格禁止・Global Layer 不変更・1回の指摘の active 昇格禁止・常時読込ファイルの短さ: 両者 OK | Claude 版 Forbidden に「command-map.md にないコマンドの発明禁止」が追加されている — Global Layer 原則の再掲であり矛盾なし（正当と判定） | 等価 |
| learn-from-feedback | 逐語記録・7分類・2回で active 昇格・矛盾の表面化・曖昧ルール禁止・Rule フォーマット: 両者 OK | canonical step 9「どのファイルをどの status で更新したか報告」を両ラッパーが同等に省略（deferral がカバー、両者対称） | 等価（記録のみ） |
| improve-instructions | diff+承認プロトコル・削除でなく deprecated・矛盾の表面化・checkpoint 内容の直接昇格禁止: 両者 OK | learned-rules 分割提案（canonical step 9）は両者同等に省略（対称） | 等価 |
| generate-agent-files | ラッパーへの新規手続き禁止・意味乖離禁止・Global 汚染禁止・重複禁止・checkpoint 非対称の扱い: 両者 OK | canonical に fable-build への相互参照 1 行を追加（本ビルド）。リポジトリ保守メタ情報のためラッパー非反映は正当 | 等価 |
| fable-build（新規） | 意味判定のスクリプト委譲禁止・無承認上書き禁止・非対称の平坦化禁止・ラッパー行数 < canonical: 両者 OK | 初回は手書き（本ビルドで作成）。Codex 版のみ TOML キー（name/description/developer_instructions）を明記 — プラットフォーム固有形式のため正当 | 等価 |
| run-agent-evals | forbidden behavior 発生時の pass 禁止・失敗の隠蔽禁止・--exec の command-map ゲート・失敗の failure-log 記録: 両者 OK | Learning check への明示言及を両者同等に省略（対称、canonical へ deferral）。Claude「eval 実行と instructions 修正の同時実施禁止」/ Codex「基準の発明禁止」はそれぞれ他方の canonical 記述と矛盾しない補強 | 等価（記録のみ） |
| fix-bug-safely | 再現必須・根本原因の証拠・最小 diff・回帰テスト・テスト弱体化禁止・risk-map 承認: 両者 OK | なし | 等価 |
| implement-feature-safely | パターン再利用・依存追加の理由必須・境界越え承認・実コマンド検証: 両者 OK | Codex 版に明示の「報告」ステップがないが、Codex-specific note が最終レポートでの再利用元の引用を要求しており実質カバー（対称性は許容範囲、記録のみ） | 等価（記録のみ） |
| context-checkpoint | 安全境界・累積マージ（追記禁止）・未検証を confirmed と記録禁止・履歴圧縮の虚偽主張禁止・最新ユーザー意図の保持: 両者 OK | **文書化済みの正当な非対称**: Claude は手動 `/compact` に言及可（自動実行の主張は禁止）、Codex は手動圧縮指示そのものが禁止（auto-compaction 前提）。根拠: canonical `generate-agent-files` step 7 の明文規定 | 等価（非対称は正当） |
| review-changes | 全カテゴリの明示回答・failing check での承認禁止・candidate ルールでのブロック禁止・security/destructive チェックのスキップ禁止: 両者 OK | Codex 版に「命名/規約チェック」（canonical step 9、Claude 版 step 7）がなかった | **修正適用**（Codex に 1 項目追加） |

## agent 定義ペア（6組）

- code-reviewer: Claude「所見のない severity は明示せよ」に対し Codex は「省略せよ」で、canonical `review-changes` の「no findings を明示」原則と矛盾 → **修正適用**（Codex TOML を明示側に整合）。
- architecture-reviewer / test-strategist / security-reviewer / bug-investigator / instruction-maintainer: 役割境界・read-only 制約・秘密情報の扱い・提案のみ（適用禁止）はすべて意味的に等価。記録のみの軽微な差: architecture-reviewer の出力で Claude は severity グルーピングを要求し Codex は要求しない（次回ビルドでの整合候補）。

## 適用した修正 diff（根拠付き）

すべて Codex 側への追加/整合で、canonical の記述が根拠。無承認の自動上書きではなく、本ブランチの diff として提示され、PR レビュー（承認プロトコル）を経てマージされる。

1. `codex/skills/project-bootstrap/SKILL.md` — テスト戦略の観測（canonical step 6）とユーザーへのサマリ報告（canonical Outputs）を追加。Claude 版のみが持つ振る舞いだったため。
2. `codex/skills/project-profile/SKILL.md` — 「last updated 行の記録」（canonical step 7）を追加。同上。
3. `codex/skills/review-changes/SKILL.md` — 命名/規約チェック（canonical step 9）を追加。同上。
4. `codex/agents/code-reviewer.toml` — 所見なし severity の扱いを「省略」から「明示」へ変更。canonical `review-changes` の「no findings は明示せよ」と Claude 版に整合。

## ドキュメント整合監査（機械的整合のみ）

初回ビルドの整合監査で検出し、修正済み:

- `README.md`（--force 保護対象）: 「8ファイル」だが `bootstrap-project.sh` の `ADAPTER_STATE_FILES` は 9 個（`context-checkpoints` を含む）→ **9ファイルに修正、`context-checkpoints.md` を列挙に追加**。
- `INSTALL.md` L101 相当: 「9つ」と述べつつ列挙は 8 ファイル → **`context-checkpoints.md` を追加**。
- `INSTALL.md`（検証方法）: 「必須の8ファイル」→ **9ファイルに修正**（`validate-agent-os.sh` の `ADAPTER_FILES` 9 個と一致）。
- `README.md` / `INSTALL.md`: canonical スキル数 11 → **12**（`fable-build` 追加に伴う）。ディレクトリツリーに `fable-build/`・`fable-build.sh`・`reports/` を追加。

## 検証結果（本ビルド時点）

- `bash agent-os/scripts/validate-agent-os.sh` → PASS: 85 / WARN: 0 / FAIL: 0
- `bash agent-os/scripts/fable-build.sh --list` → PASS: 54 / FAIL: 0（12 スキル × 両ラッパー、orphan なし、agent 6 ペア OK）
- `bash agent-os/scripts/fable-build.sh --check` → PASS（frontmatter / TOML キー / ラッパー行数 < canonical / canonical へのポインタ / validate 連携）
- サンプルプロジェクトへの `bootstrap-project.sh --for both` → 配置成功、`validate-agent-os.sh --adapter` PASS: 96 / FAIL: 0、`fable-build` ラッパーも両プラットフォームに配置確認

## 次回ビルドへの持ち越し（記録のみの所見）

- learn-from-feedback / run-agent-evals: 両ラッパーが対称に省略している報告系ステップ（更新ファイルの報告、Learning check の明示）をラッパーに昇格させるか判断する。
- architecture-reviewer: Codex TOML の出力に severity グルーピングを揃えるか判断する。
- implement-feature-safely: Codex 版に明示の報告ステップを追加するか判断する。
