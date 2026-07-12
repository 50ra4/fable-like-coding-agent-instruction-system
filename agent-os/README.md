# Agent OS

Claude Opus / Claude Sonnet / OpenAI Codex を、Fable のような高精度なコーディングエージェントとして動かすための、軽量な指示システムです。

## Agent OS の目的

このリポジトリの目的は、汎用の LLM コーディングエージェント（Opus / Sonnet / Codex）に、特定のプロダクトに特化して調整された「Fable のような」精度でコードを書かせることです。そのために巨大なプロンプトを1枚書くのではなく、常時読み込まれるファイルは短く保ち、長い手順は必要な時だけ読み込まれる `skills/` に切り出し、プロジェクト固有の事実は各プロジェクトの `.agent-os/` に外部化する、という軽量な構成を採用しています。

## なぜ project-specific ではなく adaptive にするのか

Agent OS は最初から特定プロジェクト用にチューニングされたルール集ではありません。最初は最小限の普遍的原則（Global Layer）だけを持ち、プロジェクトごとに次のループを回すことで育っていきます。

```
観測 (observe) → 学習 (learn) → 適応 (adapt) → 評価 (evaluate)
```

- **観測**: `project-bootstrap` スキルがコードやコマンド、リスクを読み取るだけで、プロジェクトの実態を記録する。
- **学習**: ユーザーからの修正やレビューコメントを `review-feedback-log.md` に逐語で記録する。
- **適応**: 繰り返し観測された事実やルールを `.agent-os/` 配下のアダプタファイルに反映する。
- **評価**: `run-agent-evals` スキルで、instructions を変更した後も精度が落ちていないかを継続的に確認する。

この4段階を回し続けることで、同じ Agent OS の雛形が、プロジェクトごとに異なる「その場に最適化された」振る舞いへと自然に分岐していきます。project-specific に固定してしまうと他プロジェクトへ再利用できず、逆に何も学習しないと Fable のような精度には到達できません。adaptive な設計はこの両立を狙ったものです。

## Fable にこのプロンプトを渡す理由

このリポジトリ自体（README を含むメタプロンプト群）は、Fable によって **一度だけ生成** されるためのものです。Fable が読むのはこの生成用メタプロンプト一式であり、Fable はこれを元に `claude/` や `codex/` 配下の軽量な成果物（CLAUDE.md、skills、agents ファイルなど）を生成します。

日常的にコードを書く Opus / Sonnet / Codex が読むのは、生成された後の軽量ファイルだけです。生成に使ったメタプロンプト（このリポジトリ全体の設計意図を説明する長大な指示）を、日常のコーディングセッションのたびに Opus / Sonnet / Codex に読ませることはありません。生成は一度きりのビルドプロセスであり、実行時の入力ではない、という区別が重要です。

## 3層構造の説明

Agent OS は責務の異なる3つの層で構成されます。

| 層 | 内容 | 置き場所 | 責務 |
|---|---|---|---|
| Global Layer | 全プロジェクト共通の最小限の普遍的原則 | `GLOBAL_AGENTS.md`, `GLOBAL_CLAUDE.md` | プロジェクトを問わず常に正しい振る舞い（安全性、diff の小ささ、事実と推測の区別など）だけを定義する。プロジェクト固有の事実は絶対に書かない。 |
| Project Adapter Layer | プロジェクトごとに観測・蓄積される事実とルール | 各プロジェクトの `.agent-os/`、および短い `CLAUDE.md` / `AGENTS.md` | そのプロジェクト固有のコマンド、アーキテクチャ、リスク、学習済みルールを保持し、時間とともに成長する。 |
| Learning Layer | 修正・レビュー・失敗からの外部記憶 | `.agent-os/failure-log.md`, `review-feedback-log.md`, `learned-rules.md`, `evals.md` | モデルの再学習ではなく、ログとルールファイルという「外部メモリ」によってエージェントの振る舞いを継続的に改善する。 |

Global Layer は他の層の内容を決して取り込まず、Project Adapter Layer は Global Layer の原則を繰り返さない、という分離が重要です。

## Claude Code での導入方法

`scripts/bootstrap-project.sh` を実行するのが正式な導入方法です（手動手順はあくまで fallback で、詳細な手順は `INSTALL.md` を参照してください）。

```bash
bash agent-os/scripts/bootstrap-project.sh --target /path/to/project --for claude
```

このコマンドは次を配置します。

1. `project-adapter/CLAUDE.md`（`{{PROJECT_NAME}}` などのプレースホルダ入り）を対象プロジェクトのルートに `CLAUDE.md` としてコピーする（既に `CLAUDE.md` が存在する場合は上書きせず、そのまま保持する）。
2. `claude/skills` を対象プロジェクトの `.claude/skills/` にコピーする。
3. `claude/agents` を対象プロジェクトの `.claude/agents/` にコピーする。
4. `GLOBAL_AGENTS.md` / `GLOBAL_CLAUDE.md` と canonical スキル一式（`skills/`）を、それぞれ `.agent-os/GLOBAL_AGENTS.md` / `.agent-os/GLOBAL_CLAUDE.md` / `.agent-os/skills/` としてベンダリング（コピー）する。
5. プロジェクト固有の `.agent-os/` アダプタ状態ファイル一式を生成する。

## Codex での導入方法

`scripts/bootstrap-project.sh` を実行するのが正式な導入方法です（手動手順はあくまで fallback で、詳細な手順は `INSTALL.md` を参照してください）。

```bash
bash agent-os/scripts/bootstrap-project.sh --target /path/to/project --for codex
```

このコマンドは次を配置します。

1. `project-adapter/AGENTS.md`（`{{PROJECT_NAME}}` などのプレースホルダ入り）を対象プロジェクトのルートに `AGENTS.md` としてコピーする（既に `AGENTS.md` が存在する場合は上書きせず、そのまま保持する）。
2. `codex/agents/*.toml` を対象プロジェクトの `.codex/agents/` にコピーする。
3. `codex/skills` を対象プロジェクトの `.agents/skills/` にコピーする。
4. `GLOBAL_AGENTS.md` と canonical スキル一式（`skills/`）を、それぞれ `.agent-os/GLOBAL_AGENTS.md` / `.agent-os/skills/` としてベンダリング（コピー）する。
5. プロジェクト固有の `.agent-os/` アダプタ状態ファイル一式を生成する。

`bootstrap-project.sh` はこのとき Global Layer の `GLOBAL_AGENTS.md`（`--for` を問わず常に）と `GLOBAL_CLAUDE.md`（`--for claude` / `both` のとき）も `<TARGET>/.agent-os/` 配下にベンダリング（コピー）し、生成された `CLAUDE.md`/`AGENTS.md` やスキルはそのベンダリング済みパスを参照します。

## `--force` と `--reset-adapter`

`--force` は skills・agents・ベンダリング済み `.agent-os/skills/`・`GLOBAL_*.md` など Agent OS 自身が管理する（OS-owned）ファイルだけを上書きします。**`project-profile.md` / `learned-rules.md` / `failure-log.md` / `review-feedback-log.md` / `evals.md` / `command-map.md` / `architecture-map.md` / `risk-map.md` / `context-checkpoints.md` の9ファイルと、ルートの `CLAUDE.md` / `AGENTS.md` は、たとえ `--force` を指定しても絶対に上書きされません**（学習によって蓄積された、そのプロジェクト固有の状態のため）。既存のファイルがある場合は `PROTECTED:` 行が表示され、そのまま保持されます。

これらの学習状態を明示的にリセットしたい場合は `--reset-adapter` を使います。既存の保護対象ファイルを `.agent-os/backup-<タイムスタンプ>/` に自動でバックアップしたうえで、新しい雛形を再インストールします。

```bash
bash agent-os/scripts/bootstrap-project.sh --target /path/to/project --for both --reset-adapter
```

対象プロジェクト配下の `.agent-os` / `.claude` / `.codex` / `.agents` がシンボリックリンクの場合（あるいはその配下の途中経路がシンボリックリンクの場合）、コピー・ディレクトリ作成・`--reset-adapter` のバックアップ移動のいずれも、対象プロジェクトの外側に書き込むことのないよう明示的に拒否されます（エラー終了し、何も移動・作成されません）。

## 新規プロジェクトでの bootstrap 手順

新しいプロジェクトに Agent OS を導入したら、コードを変更する前に必ず次の順序で実行します。

1. **`project-bootstrap` スキルを最初に実行する。** このスキルは観測専用（observe only）であり、コードは一切変更しません。リポジトリを読み取り、`.agent-os/project-profile.md`（プロジェクトの概要）、`command-map.md`（検証済みのビルド/テスト/lint コマンド）、`risk-map.md`（触ってはいけない領域や壊れやすい箇所）を生成します。この段階では `command-map.md` はまだ空の雛形ですが、`ls`・`cat`・`grep`・`find`・`git status`/`log`/`diff` のような読み取り専用の調査コマンドは常に実行してよいものです（`command-map.md` はビルド/テストなど状態を変更するコマンドのみを対象とする allow-list であり、読み取り専用の調査はその対象外です）。
2. 上記のアダプタファイルが揃ったら、`adapt-to-project` スキルを実行し、Global Layer の原則をそのプロジェクトの実情に合わせて具体化・接続します。

## フィードバックを学習させる方法

ユーザーからの訂正やレビューコメントは `learn-from-feedback` スキルで処理します。

- ユーザーの発言は要約・言い換えせず、**逐語（verbatim）** で `.agent-os/review-feedback-log.md` に記録する。
- 記録した内容は次のカテゴリのいずれかに分類する: `convention`（命名・スタイル等の規約）、`architecture`（設計・構造）、`testing`（テスト方針）、`security`（セキュリティ）、`workflow`（作業手順）、`communication`（報告の仕方）、`forbidden-action`（絶対に行ってはいけない操作）。
- 分類後、そのルールが何回観測されたかを記録し、昇格基準（下記）に従って `learned-rules.md` に反映する。

## learned rule の昇格基準

- **1回の指摘・修正** → `candidate`（候補ルール）として記録するのみ。まだ確定した振る舞いには反映しない。
- **2回以上、同趣旨の指摘・修正が繰り返された** → `active`（有効ルール）に昇格し、以後のセッションで実際に適用する。
- **古くなった、または他のルールと矛盾するルール** → `deprecated` として明示的にマークし、削除はせず理由とともに残す。
- 一度きりの個人的な好み（one-off preference）を Global Layer のルールに昇格させてはいけません。Global Layer はあくまで普遍的な原則のためのものです。

## eval の実行方法

`run-agent-evals` スキルを使い、`.agent-os/evals.md` に保存された評価シナリオに対してエージェントの振る舞いを実行・採点します。instructions（CLAUDE.md、skills、learned-rules など）を変更したときは必ずこれを実行し、変更前後で精度が劣化していないか（precision regression）を確認します。回帰が見つかった場合は、直前の instructions の変更を疑い、`improve-instructions` スキルで修正します。

半自動化のため `scripts/run-agent-evals.sh` を使います。エージェント自身がタスクを実行する部分は自動化されません（あくまでエージェントの仕事です）が、一覧・表示・検証・記録は次のように補助されます。

```bash
# 1. eval 一覧と直近の結果を確認する
bash agent-os/scripts/run-agent-evals.sh --adapter "$TARGET" --list

# 2. 対象 eval の全文を確認する
bash agent-os/scripts/run-agent-evals.sh --adapter "$TARGET" --show <eval-name>

# 3. （ここでエージェントが Task を実際に実行する）

# 4. Validation command を確認する（--exec は command-map.md に
#    記載されたコマンドのみ、--adapter で指定したディレクトリを
#    カレントディレクトリとして実行し、それ以外は拒否する。
#    "Manual review" は常に手動確認）
bash agent-os/scripts/run-agent-evals.sh --adapter "$TARGET" --check <eval-name> [--exec]

# 5. 結果を Results テーブルに記録する
bash agent-os/scripts/run-agent-evals.sh --adapter "$TARGET" --record <eval-name> --result pass|fail --model <model-name> [--notes <text>]
```

### LLM-as-judge による第三者採点

eval の実行結果は従来、実行モデルの自己申告でした。`judge-agent-eval` スキルでは、実行モデルが実行トランスクリプトを `.agent-os/eval-transcripts/<eval名スラッグ>-<日付>.md` に保存し、より強い独立した judge モデルがそれを通読して Pass criteria / Forbidden behavior / Learning check を採点します(該当箇所の引用付き)。judge の所見は `run-agent-evals.sh --record --judge-model --judge-notes --transcript` で Results テーブルの Judge 列に記録され、judge 未実施の結果は `unjudged` として区別されます。judge は実行モデル自身であってはなりません — スクリプト自体が、トランスクリプト無し(または実在しないファイル)での judge 記録と、`--judge-model` が `--model` と一致する記録を拒否します。

### 失敗クラスタからの eval 合成（synthesize-evals）

eval の起草そのものも、ビルダーモデル（Fable 級）に予約すべき precision-critical なタスクです。実行モデルが自分自身のために eval を書くと、その回帰を持つモデルだけが fail するという識別力（discriminative power）が担保されません — 自作自演の eval は往々にしてそのモデルが既に得意なことしか検証しないからです。`synthesize-evals` スキル（`skills/synthesize-evals/SKILL.md`）は、`failure-log.md` / `review-feedback-log.md` の逐語エントリを根本原因・task shape で意味的にクラスタリングし、1クラスタにつき1つの eval を標準 Eval format で起草します。Forbidden behavior には元の失敗を再現する行動を必ず含め、その回帰を持つモデルが確実に fail するようにします。Validation command は `command-map.md` に一字一句掲載されているコマンドのみを使い、該当がなければ `"Manual review"` とします。各 eval には「捕まえる回帰」の一行説明と、根拠となるログエントリの逐語引用を HTML コメントとして直後に添付します（`run-agent-evals.sh` はパース前にコメントを除去するため、`--show`/`--check` のフォーマット互換性は保たれます）。追加は `improve-instructions` の非破壊的追加ルールに従い、既存 eval の削除・書き換えは常に承認必須です。採点は `judge-agent-eval`（#4）、ルール蒸留は `distill-rules`（#5）の領分であり、`synthesize-evals` はあくまで eval の起草とその根拠提示に責務を限定します。

### checkpoint の監査・高忠実度圧縮（audit-checkpoint）

`context-checkpoint` の Forbidden list（未検証の情報を confirmed として記載する、未実行のテストを passed として記録する、失敗の隠蔽、最新のユーザー指示の欠落）は、これまで checkpoint を書く本人モデルの自制のみに依存していました。`audit-checkpoint` スキル（`skills/audit-checkpoint/SKILL.md`）はその監査者側の執行であり、作成者と同等以下のモデルが監査すると作成者自身の盲点をそのまま継承してしまうため、作成者より強いモデル（Fable 級）が担う builder-model タスクです（`fable-build` / `distill-rules` と同格）。手順は3工程から成ります。①**裏取り**: 「Confirmed facts」「Commands run and results」「Files changed」の各記述を `git diff` / `git log` / 実際の実行記録と突き合わせ、裏付けのない記述は「Assumptions and uncertainties」への降格を提案します（勝手に書き換えるのではなく提案に留めます）。②**再圧縮**: 複数の `# Context Checkpoint` ブロックや重複記述を単一の累積 `# Context Checkpoint` へ再統合し、矛盾は最新のユーザー意図を優先して解消しつつ、supersede された決定は削除せず理由付きで保存します。③**汚染検査**: checkpoint と `learned-rules.md` / `GLOBAL_*` / canonical スキルとの間の双方向コピー（ルールが checkpoint に紛れ込む、あるいは checkpoint の内容がルール側に昇格される）を検出します。ルールへの昇格はあくまで `learn-from-feedback` を経由した場合のみ許可されます。`validate-agent-os.sh` は `context-checkpoints.md` が 200 行を超えると警告（エラーではありません）を出し、この `audit-checkpoint` スキルの実行を促します。すべての修正は `improve-instructions` と同じプロトコルに従い、diff の提示とユーザー承認を経てから適用されます。なお、リポジトリ全体の Global Layer / Project Adapter レイヤ分離の監査はこのスキルのスコープ外で、あくまで checkpoint とルール群の間の汚染検査に責務を限定します。

### レイヤ分離の意味的監査（audit-layer-separation）

Global Layer / Project Adapter の責務分離（後述の「global layer と project adapter の責務分離」）は各所で「守れ」と繰り返されてきましたが、守られているかを検査する手段はありませんでした — `validate-agent-os.sh` が検証するのは構造面のみで、記述内容がどの層に属すべきかは見ません。`audit-layer-separation` スキル（`skills/audit-layer-separation/SKILL.md`）はこの検査を担う builder-model（Fable 級）タスクです。ある記述が「すべてのプロジェクトで常に正しい」普遍原則か「この場の観測事実」かの分類は、記述の意味と適用範囲の推論そのものであり、字面には現れません（プロジェクト名が書かれていなくても、特定のディレクトリ構成を前提にした「原則」は固有です）。また学習ループを回す実行モデル自身が汚染の発生源であるため、同格モデルによる自己監査では検出力が出ません（審判 > 被審判）。監査は `GLOBAL_AGENTS.md` / `GLOBAL_CLAUDE.md`・canonical skills・導入先の `CLAUDE.md` / `AGENTS.md`・`learned-rules.md`（+ `.agent-os/rules/*.md`）の全記述を「普遍原則 / プロジェクト固有事実 / 中間」に分類し、**現在の置き場所と分類が食い違うものだけ**を、逐語引用・根拠・移動 diff 付きで報告します。Global → Adapter は降格提案として提示しますが、Adapter 側で見つかった普遍的べき論を Global へ昇格させる提案は行いません — 昇格は `learn-from-feedback` の昇格基準のみを経由します。中間例（「PR は小さく分割する」等）は勝手に裁定せず「Needs manual confirmation」として提示します。機械的に検出可能な明白な汚染（`GLOBAL_*.md` 内のパッケージマネージャ名等）は `validate-agent-os.sh` が警告レベルの前処理として検出しますが、意味判定はスクリプトでは行いません — 警告は候補にすぎず、false positive は無視できます。推奨タイミングは `improve-instructions` の実行時、および Global Layer（`GLOBAL_*.md` / canonical skills）を変更する PR の前です。すべての移動・削除は diff の提示とユーザー承認を経てからのみ適用されます。

### architecture-map / risk-map の全体合成（synthesize-project-maps）

`project-bootstrap` が書く `architecture-map.md` / `risk-map.md` の初版は、一セッションの一次観測にすぎません。レイヤー構造・依存方向・責務境界・壊れやすさをリポジトリ全体（コード・設定・CI・git 履歴）から抽出するには一貫した視点での全体読解が必要で、これは `distill-rules` / `synthesize-evals` と同じ理由でビルダーモデル（Fable 級）専用の precision-critical なタスクです — 誤ったマップは無いより悪く、以後の全セッションと `architecture-reviewer` サブエージェントを誤った前提のまま拘束してしまいます。特に git 履歴からの壊れやすさ推定（頻繁なホットフィックス・差し戻し）はコミット数の表面的な集計では足りず、なぜその変更が起きたかの読解を要します。`synthesize-project-maps` スキル（`skills/synthesize-project-maps/SKILL.md`）は、初版作成（`project-bootstrap`）と全体読解による高度化（本スキル）を役割分担し、両マップのすべての記述にファイルパスまたは git 履歴という根拠を必須で添付し、根拠のない記述は仮説として明示します。網羅性の偽装を防ぐため「未観測領域（Unobserved areas）」の明示も両マップに必須です。既存マップに実質的な内容がある場合は上書きせず、`improve-instructions` と同じ diff＋承認プロトコルに従って差分提案として提示します — 両マップは `bootstrap-project.sh` の PROTECTED 学習資産であり、プレースホルダのみの節を埋める場合に限り直接適用できます。`command-map.md` はスコープ外です — コマンドは実行して検証する必要があり、観測専用の本スキルの責務を超えます。

## global layer と project adapter の責務分離

- **Global Layer** には、プロジェクトを問わず常に成り立つ最小限の原則だけを書きます。特定の言語・フレームワーク・ディレクトリ構成・コマンドは絶対に書きません。
- **Project Adapter** には、観測によって確認された、そのプロジェクト固有の事実だけを書きます。一般化した「べき論」や、他プロジェクトにも当てはまりそうな原則は書きません。
- 両者を混ぜてはいけません。Global Layer にプロジェクト固有の記述が混入すると他プロジェクトへの再利用性が失われ、Project Adapter に普遍的な原則を書くと Global Layer との重複・矛盾が発生します。

この分離が実際に守られているかの継続検証は前述の `audit-layer-separation` スキルが担い、機械的な前処理として `validate-agent-os.sh` の警告レベルの汚染検出が補助します。

## ルールが肥大化したときの整理方法

CLAUDE.md、skills、learned-rules.md 等が増えすぎて読みにくくなったら `improve-instructions` スキルを実行します。このスキルは次を行います。

- 重複しているルールをマージする。
- `scripts/detect-rule-conflicts.sh` を実行し、矛盾するルールを検出する。
- 古くなった・使われなくなったルールを `deprecated` として整理する（削除ではなくマーク）。
- 数行を超える手順が常時読み込みファイル（CLAUDE.md / AGENTS.md）に紛れ込んでいたら、`skills/` へ移動し、元の場所には一行のポインタだけを残す。

昇格・統合・矛盾解消の**意味的な判断**（文言が違うが同趣旨の指摘の集約と実効 recurrence count の算出、極性語に依存しない矛盾検出）は `distill-rules` スキル（`skills/distill-rules/SKILL.md`）が担います。これは `fable-build` と同じく builder-class モデル（Fable 級）が実行する precision-critical なタスクです。（`fable-build` と異なり Agent OS リポジトリ限定ではなく、インストール済みプロジェクトの `.agent-os/*` ログに対する保守実行も対象です。禁止されるのは通常のコーディングセッション内での実行のみです。）機械的な前処理として `scripts/detect-rule-conflicts.sh --pairs`（active ルールの候補ペアを Scope / Applies to の近さ順に列挙）を使い、すべての昇格・統合・deprecated 提案には支持する証拠エントリの逐語引用が必須で、矛盾は「矛盾ペア＋根拠＋解消案」の形式でユーザー判断に委ねられます。適用は `improve-instructions` と同じ diff＋承認プロトコルに従い、無承認では一切適用されません。

`learned-rules.md` 自体が肥大化した場合（目安: active なルールが10件を超える、またはファイルが300行を超える）は、`scripts/split-learned-rules.sh` で `Status: active` のルールをスコープ別ファイル（`.agent-os/rules/global.md` / `project.md` / `directory.md` / `file-pattern.md`、各ルールの `Scope:` フィールドに従う）へ分割できます。`learned-rules.md` には各ルールへのポインタとなる `## Active rules index` が残り、candidate・deprecated のルールは常に `learned-rules.md` に残ります。分割後は、`CLAUDE.md` / `AGENTS.md` などの常時読み込みチェックリストや各 skill・subagent も、`## Active rules index` が指す `.agent-os/rules/*.md` を読むよう指示されます。分割前と同じく `Status: active` のルールとして拘束力を持つため、`learned-rules.md` だけを読んで分割済みのルールを見落とすことはありません。

```bash
# 移動計画だけを確認する（ファイルは変更しない）
bash agent-os/scripts/split-learned-rules.sh --adapter "$TARGET" --dry-run

# 実際に分割する
bash agent-os/scripts/split-learned-rules.sh --adapter "$TARGET"
```

分割は任意（optional）です。初期状態は単一ファイルのままで問題なく、`detect-rule-conflicts.sh` / `summarize-learning-log.sh` / `validate-agent-os.sh` はいずれのレイアウトにも対応しています。

## Fable によるビルド（fable-build）

`claude/` / `codex/` 配下のラッパー（skills / agents）は手で編集せず、`fable-build` スキル（`skills/fable-build/SKILL.md`）に従って Fable（ビルダーモデル）が canonical スキルから再生成します。機械的な部分は `scripts/fable-build.sh` が補助します。

```bash
# canonical → ラッパーの対応と欠落を一覧する
bash agent-os/scripts/fable-build.sh --list

# 再生成候補（ビルド出力ディレクトリ）と現状の diff を提示する
bash agent-os/scripts/fable-build.sh --diff <build-dir>

# 形式検証（frontmatter / TOML キー / ラッパー行数 / validate-agent-os.sh）
bash agent-os/scripts/fable-build.sh --check
```

意味的な判定（ラッパーが canonical と意味的に等価か、プラットフォーム非対称が正当か）はスクリプトでは行わず、Fable が `reports/fable-build-parity.md` にパリティ監査レポートとして残します。再生成 diff は `improve-instructions` と同じ「diff+理由を提示し、承認後に適用」プロトコルに従い、承認なしに上書きされることはありません。

## ディレクトリ構成の一覧

```
agent-os/
├── README.md                  # 本ドキュメント（日本語）
├── GLOBAL_AGENTS.md            # Global Layer: 全エージェント共通の最小原則
├── GLOBAL_CLAUDE.md            # Global Layer: Claude Code 固有の差分
├── INSTALL.md                  # 導入手順（日本語）
├── templates/                   # 各種テンプレート
├── skills/                      # 18 の canonical スキル
│   ├── project-bootstrap/
│   ├── project-profile/
│   ├── synthesize-project-maps/   # リポジトリ全体からのマップ合成（Fable 用: 根拠必須・未観測明示）
│   ├── adapt-to-project/
│   ├── learn-from-feedback/
│   ├── improve-instructions/
│   ├── distill-rules/             # 意味的ルール蒸留（Fable 用: 昇格・統合・矛盾解消）
│   ├── generate-agent-files/
│   ├── fable-build/               # Fable 用ビルド手順（ラッパー再生成 + パリティ監査）
│   ├── run-agent-evals/
│   ├── judge-agent-eval/          # eval 実行結果の第三者採点（LLM-as-judge）
│   ├── synthesize-evals/          # 失敗クラスタからの eval 合成（Fable 用: 識別力の担保）
│   ├── fix-bug-safely/
│   ├── implement-feature-safely/
│   ├── context-checkpoint/       # 長時間セッションの checkpoint / handoff summary 用
│   ├── audit-checkpoint/         # checkpoint の監査・高忠実度再圧縮（Fable 用: handoff 品質保証）
│   ├── audit-layer-separation/   # レイヤ分離の意味的監査（Fable 用: 置き場所の食い違い検出・降格提案のみ）
│   └── review-changes/
├── claude/                      # Claude Code 向け生成物
│   ├── CLAUDE.md
│   ├── skills/
│   └── agents/*.md
├── codex/                        # OpenAI Codex 向け生成物
│   ├── AGENTS.md
│   ├── agents/*.toml
│   └── skills/
├── project-adapter/              # Project Adapter Layer の雛形
│   ├── AGENTS.md
│   ├── CLAUDE.md
│   └── .agent-os/
├── reports/                     # fable-build のパリティ監査レポート
└── scripts/
    ├── bootstrap-project.sh
    ├── fable-build.sh
    ├── validate-agent-os.sh
    ├── summarize-learning-log.sh
    ├── detect-rule-conflicts.sh
    ├── run-agent-evals.sh
    └── split-learned-rules.sh
```

## `claude/CLAUDE.md` と `codex/AGENTS.md` は何のためにあるか

`claude/CLAUDE.md` と `codex/AGENTS.md` は、**このリポジトリ（Agent OS の開発元）自身の中で** Claude Code / Codex を使って作業するときのエントリポイントです。`bootstrap-project.sh` はこの2ファイルをどこにもインストールしません — 対象プロジェクトの `CLAUDE.md` / `AGENTS.md` として実際にコピーされるのは `project-adapter/CLAUDE.md` / `project-adapter/AGENTS.md` の方です（前述の各インストール手順を参照）。この2ファイルはそれとは別に、任意でユーザーのグローバル設定（例: `~/.claude/CLAUDE.md` や Codex のグローバル設定）の候補として使うこともできますが、必須ではありません。導入先プロジェクトの成果物と混同しないよう注意してください。

## 注意: メタプロンプトを Opus / Sonnet / Codex に毎回渡さないこと

このリポジトリ（`agent-os/` 全体、特にこの README のようなメタ文書）は、Fable がこのシステムを生成するための素材です。**日常のコーディングセッションで Opus / Sonnet / Codex に渡してよいのは、生成後の軽量ファイル（`CLAUDE.md` / `AGENTS.md` / `skills/` / `agents/` / `.agent-os/` の中身）だけです。** この生成用メタプロンプト一式を毎回のセッションで読み込ませることは、常時読み込みコストを不必要に増大させ、Agent OS が目指す「軽量な指示システム」という設計原則そのものに反します。
