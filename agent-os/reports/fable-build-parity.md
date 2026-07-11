# Fable Build — Semantic Parity Report

単一の累積レポート。`fable-build` の各ビルドはこのファイルにマージする（追記で2つ目のレポートブロックを作らない）。

- Last build: 2026-07-11（issue #5: distill-rules 追加ビルド + improve-instructions/learn-from-feedback への相互参照追加）
- Builder: Fable（ビルダーモデル）
- 対象: canonical 14 スキル（`distill-rules` 新規追加）× Claude/Codex ラッパー、および agent 定義 6 ペア（`distill-rules` に対応する新規 agent 定義はなし — fable-build と同じく手書きラッパーのみのビルダー系スキル）
- 手法: 各 canonical スキルの拘束項目（Procedure の必須ステップ / Forbidden / Done criteria）を抽出し、Claude ラッパーと Codex ラッパーが「文言は違っても同じ振る舞いをプロンプトするか」を突き合わせた。字面 diff ではなく意味比較。スクリプト（`scripts/fable-build.sh`、`scripts/detect-rule-conflicts.sh --pairs`）は列挙・diff 提示・形式検証・機械的候補ペア列挙のみで、この判定には関与していない。

## 判定基準

- ラッパーは全文冒頭で canonical への差し戻し（deferral）を明記しているため、**個別ステップの省略それ自体は不合格ではない**。不合格となるのは (a) Claude/Codex の一方だけがある振る舞いをプロンプトする非対称で正当な根拠がないもの、(b) canonical の Forbidden と矛盾する記述、(c) ラッパーへの新規手続きの混入。
- 正当なプラットフォーム非対称（例: compact の扱い）は「根拠付きで維持」する。

## スキル別パリティ表

| スキル | 拘束項目カバレッジ（Claude / Codex） | 非対称・所見 | 判定 |
|---|---|---|---|
| project-bootstrap | 観測専用・コマンド出典必須・秘密情報不読・仮説と事実の分離: 両者 OK | Codex 版に「テスト戦略の観測」と「ユーザーへの最終サマリ報告」がなく Claude 版のみ存在（根拠のない非対称） | **修正適用**（Codex に 2 項目追加） |
| project-profile | 事実/仮説分離・単一guess昇格禁止・肥大化禁止・訂正の明示: 両者 OK | Codex 版に「last updated 行の記録」（canonical step 7、Claude 版は step 7 で明記）がない | **修正適用**（Codex に 1 項目追加） |
| adapt-to-project | 仮説昇格禁止・Global Layer 不変更・1回の指摘の active 昇格禁止・常時読込ファイルの短さ: 両者 OK | Claude 版 Forbidden に「command-map.md にないコマンドの発明禁止」が追加されている — Global Layer 原則の再掲であり矛盾なし（正当と判定） | 等価 |
| learn-from-feedback | 逐語記録・7分類・2回で active 昇格・矛盾の表面化・曖昧ルール禁止・Rule フォーマット: 両者 OK | canonical step 9「どのファイルをどの status で更新したか報告」を両ラッパーが同等に省略（deferral がカバー、両者対称）。**（本ビルド）** canonical step 3 に「同一実質・別表現が疑われる場合は文字列一致ではなく `distill-rules` のクラスタリング結果（実効再現回数）を参照する」の1文を追加し、両ラッパーの対応ステップにも同粒度で反映済み（Claude 25行 / Codex 45行、いずれも canonical 80行より短いことを確認済み） | 等価（記録のみ） |
| improve-instructions | diff+承認プロトコル・削除でなく deprecated・矛盾の表面化・checkpoint 内容の直接昇格禁止: 両者 OK | learned-rules 分割提案（canonical step 9）は両者同等に省略（対称）。**（本ビルド）** canonical step 3 に「機械的チェックを超える意味的な統合・矛盾判定は `distill-rules`（`--pairs` を機械的下処理として利用）へ委譲できる」の1文を追加し、両ラッパーの対応ステップにも同粒度で反映済み（Claude 27行 / Codex 44行、いずれも canonical 67行より短いことを確認済み） | 等価 |
| distill-rules（新規） | 逐語証拠必須（全提案）・conflict の一方的解決禁止（pair+証拠+選択肢のみ提示）・diff+承認プロトコルのみ（`improve-instructions` 経由）・builder-model 限定（通常セッションでの実行禁止）・削除禁止（deprecated のみ）: 両者 OK | 初回は手書き（本ビルドで `fable-build` と同じ手法・同じ位置付けで作成）。canonical（65行）より短いことを確認済み（Claude 28行 / Codex 43行）、両者とも `skills/distill-rules/SKILL.md` へのポインタを含む。プラットフォーム固有の非対称は意図的に設けていない | 等価 |
| generate-agent-files | ラッパーへの新規手続き禁止・意味乖離禁止・Global 汚染禁止・重複禁止・checkpoint 非対称の扱い: 両者 OK | canonical に fable-build への相互参照 1 行を追加（前回ビルド）。リポジトリ保守メタ情報のためラッパー非反映は正当 | 等価 |
| fable-build（新規） | 意味判定のスクリプト委譲禁止・無承認上書き禁止・非対称の平坦化禁止・ラッパー行数 < canonical: 両者 OK | 初回は手書き（本ビルドで作成）。Codex 版のみ TOML キー（name/description/developer_instructions）を明記 — プラットフォーム固有形式のため正当 | 等価 |
| run-agent-evals | forbidden behavior 発生時の pass 禁止・失敗の隠蔽禁止・--exec の command-map ゲート・失敗の failure-log 記録・run transcript の保存（`.agent-os/eval-transcripts/<slug>-<date>.md`）・`--record` への `--judge-model`/`--judge-notes`/`--transcript` 伝播・`judge-agent-eval` への採点依頼・自己採点（自分の実行分に `--judge-notes` を付けない）の禁止・**（レビュー修正）`run-agent-evals.sh` 自身が transcript 未指定/無効（存在しない・空・symlink・adapter 外）での judge 記録を拒否し、`--judge-model` が `--model` と一致する場合も拒否することの明記**: 両者 OK | Learning check への明示言及を両者同等に省略（対称、canonical へ deferral）。Claude「eval 実行と instructions 修正の同時実施禁止」/ Codex「基準の発明禁止」はそれぞれ他方の canonical 記述と矛盾しない補強。新規の transcript/judge 項目、および今回のスクリプト強制の言及は Claude/Codex 双方に同等の粒度で追加済み（非対称なし） | 等価（記録のみ） |
| judge-agent-eval（新規） | transcript 必須（なければ `unjudged` のまま拒否）・実行モデル自身の採点禁止・Pass criteria ごとの引用付き verdict・Forbidden behavior の引用付き検出・Learning check の実施検証・self-report とのミスマッチ検出・`--check --exec` 経由でのみ再検証・`--record --judge-model --judge-notes --transcript` での記録（構造化された `--judge-model` フラグを使用、判定モデル名をnotes内の自由記述に頼らない）: 両者 OK | 初回作成（本ビルド）。両ラッパーとも `fable-build`/`fable-build.sh` の frontmatter・pointer・行数規約に準拠。プラットフォーム固有の非対称は意図的に設けていない。レビュー修正で `--judge-model` フラグ化した際も両ラッパー同等の粒度で更新済み | 等価 |
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
5. （issue #4 ビルド）`scripts/run-agent-evals.sh` — `--record` に `--judge-notes`/`--transcript` を追加し、Results 表に `Judge` 列（6列目）を追加。既存 5 列テーブルはヘッダ/セパレータのみをその場で 6 列に拡張し、既存データ行は無変更のまま。
6. （issue #4 ビルド）`claude/skills/run-agent-evals/SKILL.md`・`codex/skills/run-agent-evals/SKILL.md` — canonical の新規ステップ（transcript 保存・`judge-agent-eval` への採点依頼・自己採点禁止）を両ラッパーに同等の粒度で追加。両ラッパーとも canonical（93行）より短いことを確認済み（Claude 29行 / Codex 47行）。
7. （issue #4 ビルド）`claude/skills/judge-agent-eval/SKILL.md`・`codex/skills/judge-agent-eval/SKILL.md` — 新規作成。canonical（58行）より短いことを確認済み（Claude 29行 / Codex 44行）、両者とも `skills/judge-agent-eval/SKILL.md` へのポインタを含む。
8. （レビュー修正: Codex P1×2 対応）`scripts/run-agent-evals.sh` — `--judge-model <name>` フラグを新設し、`--judge-notes` は `--judge-model` と `--transcript` の両方を要求（片方のみ・`--judge-model` 単独はいずれも usage error, exit 2）。`--transcript` 指定時は常に（judged/unjudged 問わず）実体・非空・非symlink・adapter root 内であることを検証し、違反時は record 拒否（exit 1）。`--judge-model` と `--model` が trim + lowercase 後に一致する場合も record 拒否（exit 1、"judge must not be the executing model"）。Judge セルの書式を `<judge-model>: <judge-notes>; transcript: <path>` に変更（judge-model もパイプ/改行/CR をサニタイズ）。usage() と Exit codes セクションを更新。
9. （レビュー修正）`skills/judge-agent-eval/SKILL.md`・`claude/skills/judge-agent-eval/SKILL.md`・`codex/skills/judge-agent-eval/SKILL.md` — 記録コマンドを `--judge-model <judge-model> --judge-notes "<verdict>"` の構造化フラグ形式に更新（notes内に判定モデル名を書く記法を廃止）。canonical Done criteria の文言も「judge notes（判定モデル名を含む）」→「judge model・judge notes・transcript path」に更新。
10. （レビュー修正）`skills/run-agent-evals/SKILL.md`・`claude/skills/run-agent-evals/SKILL.md`・`codex/skills/run-agent-evals/SKILL.md` — step 9(相当) に `--judge-model`/`--judge-notes` 経由の記録とスクリプト自身による transcript 必須化・same-model 拒否を追記。Forbidden の自己採点禁止ブロックに「スクリプトが `--judge-model`=`--model` を拒否する」旨を追記。
11. （issue #5 ビルド）`skills/distill-rules/SKILL.md`・`claude/skills/distill-rules/SKILL.md`・`codex/skills/distill-rules/SKILL.md` — 新規作成。14番目の canonical スキルとして、逐語ログ（`review-feedback-log.md`/`failure-log.md`/`learned-rules.md`/`.agent-os/rules/*.md`）を意味的にクラスタリングし、実効再現回数・昇格/統合/deprecated 提案・pair+証拠+選択肢形式の conflict 報告を `improve-instructions` の diff+承認フローに流し込む builder-model 専用スキルを定義（`fable-build` と同じ位置付け）。両ラッパーとも canonical より短く、`skills/distill-rules/SKILL.md` へのポインタを含むことを確認済み。
12. （issue #5 ビルド）`scripts/detect-rule-conflicts.sh` — `--pairs` モードを新設（`--adapter`/`--file` と併用可）。`Status: active` のルールのみを対象に全ペア（i<j）を機械的な近さのみでスコアリングする（Applies-to の完全一致ターゲット共有 +3/件、Scope 一致 +2、完全一致を除いた残りターゲットのトークン共有 +1（1件のみ、トークン数に比例しない））。Rule 本文の内容・文言比較は一切行わず、意味判定は `distill-rules` に委譲。既存の findings モード（`--pairs` 未指定時）は既存の `parse_rules`/`all_rules` パーサをそのまま再利用し、出力・終了コードとも変更前とバイト単位で同一であることをベースライン diff で確認済み（後述）。`--pairs` は常に exit 0（usage error 時のみ exit 2）。
13. （issue #5 ビルド）`skills/improve-instructions/SKILL.md`・`claude/skills/improve-instructions/SKILL.md`・`codex/skills/improve-instructions/SKILL.md`、および `skills/learn-from-feedback/SKILL.md`・`claude/skills/learn-from-feedback/SKILL.md`・`codex/skills/learn-from-feedback/SKILL.md` — それぞれの対応ステップに `distill-rules` への相互参照を1文ずつ追加（上記パリティ表の該当行を参照）。ラッパー行数はいずれも canonical 未満のまま。

## ドキュメント整合監査（機械的整合のみ）

初回ビルドの整合監査で検出し、修正済み:

- `README.md`（--force 保護対象）: 「8ファイル」だが `bootstrap-project.sh` の `ADAPTER_STATE_FILES` は 9 個（`context-checkpoints` を含む）→ **9ファイルに修正、`context-checkpoints.md` を列挙に追加**。
- `INSTALL.md` L101 相当: 「9つ」と述べつつ列挙は 8 ファイル → **`context-checkpoints.md` を追加**。
- `INSTALL.md`（検証方法）: 「必須の8ファイル」→ **9ファイルに修正**（`validate-agent-os.sh` の `ADAPTER_FILES` 9 個と一致）。
- `README.md` / `INSTALL.md`: canonical スキル数 11 → **12**（`fable-build` 追加に伴う）。ディレクトリツリーに `fable-build/`・`fable-build.sh`・`reports/` を追加。

## 検証結果（本ビルド時点）

- `bash agent-os/scripts/validate-agent-os.sh` → PASS: 85 / WARN: 0 / FAIL: 0（初回ビルド時点の記録）
- `bash agent-os/scripts/fable-build.sh --list` → PASS: 54 / FAIL: 0（12 スキル × 両ラッパー、orphan なし、agent 6 ペア OK）（初回ビルド時点の記録）
- `bash agent-os/scripts/fable-build.sh --check` → PASS（frontmatter / TOML キー / ラッパー行数 < canonical / canonical へのポインタ / validate 連携）（初回ビルド時点の記録）
- サンプルプロジェクトへの `bootstrap-project.sh --for both` → 配置成功、`validate-agent-os.sh --adapter` PASS: 96 / FAIL: 0、`fable-build` ラッパーも両プラットフォームに配置確認（初回ビルド時点の記録）

### 本ビルド（issue #4: judge-agent-eval 追加）での再検証

- `bash agent-os/scripts/fable-build.sh --list` → PASS: 58 / FAIL: 0（13 スキル × 両ラッパー、orphan なし、agent 6 ペア OK、`judge-agent-eval` が新規に検出されている）
- `bash agent-os/scripts/fable-build.sh --check` → own checks PASS: 97 / WARN: 0 / FAIL: 0、内部で呼ぶ `validate-agent-os.sh` も PASS: 88 / WARN: 0 / FAIL: 0、overall RESULT: PASS
- `scripts/run-agent-evals.sh` の手動テスト（スクラッチアダプタ、コミット対象外）: 新規 evals.md（Results セクションなし）への `--record` → 6列ヘッダ + `Judge=unjudged` で新規作成／既存 5 列テーブルへの `--record` → ヘッダ・セパレータのみ 6 列へその場拡張、既存データ行は無変更／`--judge-notes`+`--transcript` 付き `--record` → `Judge` セルが `"<judge-notes>; transcript: <path>"`／`|` と改行を含む `--judge-notes` はサニタイズされ表を壊さない／`--judge-notes` と `--list` の同時指定はエラー(exit 2)／`--list`・`--show`・`--check` の既存動作に影響なし。すべて期待どおり。

### レビュー修正（Codex P1×2）後の再検証（本ビルド）

`scripts/run-agent-evals.sh --adapter <scratch> --record ...` を `/tmp` 配下のスクラッチアダプタ（コミット対象外）で実測。全13ケースとも期待どおり:

- `bash -n agent-os/scripts/run-agent-evals.sh` → exit 0。
- `--judge-notes` のみ（`--transcript` なし） → `ERROR: --judge-notes requires --transcript ...` exit 2。
- `--judge-notes`+`--transcript` のみ（`--judge-model` なし） → `ERROR: --judge-notes requires --judge-model ...` exit 2。
- `--judge-model` 単独 → `ERROR: --judge-model requires --judge-notes ...` exit 2。
- 存在しない transcript → `ERROR: refusing to record: ... does not exist, is not a regular file, or is empty` exit 1。
- 空の transcript ファイル → 同上のメッセージで exit 1。
- symlink の transcript → `ERROR: refusing to record: ... is a symlink` exit 1。
- symlink された親ディレクトリ経由で adapter 外を指す transcript、および `../` で adapter 外を指す transcript → いずれも `ERROR: refusing to record: ... resolves to <phys-path>, outside <adapter_phys> ...` exit 1（`.agent-os` エスケープゲートと同じ物理パス比較手法を再利用）。
- `--judge-model "Codex" --model "codex"`（trim+lowercase 一致） → `ERROR: refusing to record: --judge-model equals --model — the judge must not be the executing model` exit 1。
- 正常系（実ファイルの transcript、別名の judge-model） → `Judge` セルが `"<judge-model>: <judge-notes>; transcript: <path>"` で記録、exit 0。
- `--transcript` のみ（judge フラグなし） → `Judge` セルが `"unjudged; transcript: <path>"`、exit 0（許可された組み合わせ）。
- 素の `--record`（新フラグなし）を既存 5 列テーブルに対して実行（回帰確認） → ヘッダ・セパレータのみ 6 列へその場拡張、既存データ行は無変更、新規行は `Judge=unjudged`、exit 0。
- `--judge-model` にパイプ・改行を含む値 → サニタイズされ表が壊れない（`judge|with\nnewline` → `judgewith newline`）。

最終チェック: `bash agent-os/scripts/validate-agent-os.sh` → PASS: 88 / WARN: 0 / FAIL: 0。`bash agent-os/scripts/fable-build.sh --check` → own checks PASS: 97 / WARN: 0 / FAIL: 0、内部の `validate-agent-os.sh` も PASS: 88 / WARN: 0 / FAIL: 0、overall RESULT: PASS。

### 本ビルド（issue #5: distill-rules 追加）での検証

本ビルドはスキル/スクリプト側の編集と、`validate-agent-os.sh`・`README.md`・`INSTALL.md`・`claude/CLAUDE.md`・`codex/AGENTS.md` への登録・ドキュメント側の編集を分担して行ったため、リポジトリ全体の検証は両者が揃った時点で最終実行した: `bash agent-os/scripts/validate-agent-os.sh` → PASS: 91 / WARN: 0 / FAIL: 0。`bash agent-os/scripts/fable-build.sh --list` → PASS: 62 / WARN: 0 / FAIL: 0（14 スキル × 両ラッパー、orphan なし、agent 6 ペア OK、`distill-rules` が新規に検出されている）。`bash agent-os/scripts/fable-build.sh --check` → own checks PASS: 104 / WARN: 0 / FAIL: 0、内部の `validate-agent-os.sh` も PASS、overall RESULT: PASS。ビルド範囲内で個別に実施・確認したのは以下:

- `bash -n agent-os/scripts/detect-rule-conflicts.sh` → exit 0。
- 変更前ベースライン（`--adapter <sample-adapter>` および `--file <sample-adapter>/.agent-os/learned-rules.md`、いずれも active ルール2件が `migrations/` で重複する固定サンプル）との出力 diff → 両モードともバイト単位で空 diff、exit code もそれぞれ変更前と同一（1, 1）。`--pairs` 未指定時の後方互換性を実測で確認。
- `--pairs --adapter <sample-adapter>` → active ルール2件のみが対象になり（candidate ルール1件は除外）、ペア1件・score=5（`Applies to` 完全一致 "migrations/" で +3、Scope 一致（project/project）で +2、完全一致除外後の残余トークンなしで +1 は付与されず）が期待どおり出力され、exit 0。追加の手動テスト（3〜4ルールの合成ケース）でも、部分トークン一致のみのペア（+1 のみ）、スコア降順+同点時のルール名アルファベット順ソート、`Status:` の大文字小文字混在の扱いが期待どおりであることを確認。
- 3つの `distill-rules/SKILL.md`（canonical/claude/codex）すべてに `---` フロントマター（`name:`/`description:`）があること、Claude/Codex 両ラッパーが canonical より行数が少なく、`skills/distill-rules/SKILL.md` という文字列（canonical への差し戻しポインタ）を含むことを確認済み。
- `improve-instructions`・`learn-from-feedback` の canonical/Claude/Codex 各ファイルで、追加後もラッパーが canonical より行数が少ないことを `awk 'END{print NR}'` で再確認済み（上記パリティ表に行数を記録）。

## 次回ビルドへの持ち越し（記録のみの所見）

- learn-from-feedback: ラッパーが対称に省略している報告系ステップ（更新ファイルの報告）をラッパーに昇格させるか判断する。
- architecture-reviewer: Codex TOML の出力に severity グルーピングを揃えるか判断する。
- implement-feature-safely: Codex 版に明示の報告ステップを追加するか判断する。
- judge-agent-eval: 初回運用後、実際の判定パターンを見て Claude/Codex ラッパーの記述粒度を調整する余地がないか次回ビルドで確認する。
- distill-rules: 初回の実運用（実プロジェクトのログでの蒸留）後、クラスタリング・conflict 報告の記述粒度がラッパーで十分か次回ビルドで確認する。
