# Agent OS 導入手順 (INSTALL)

対象プロジェクトに Agent OS を実際にインストールするための、具体的な手順書です。設計の背景や各層の責務については `README.md` を参照してください。

## 前提

- `agent-os/` はこのリポジトリの中にあり、対象プロジェクトは別ディレクトリ（`<TARGET>`）とします。
- 以下、`<TARGET>` は導入先プロジェクトのルートディレクトリの絶対パスを表します。

```bash
export TARGET=/path/to/your/project
```

## Claude Code 向けインストール

Claude Code では、次のファイルが対象プロジェクトの以下の場所に配置されます。

| 生成元 | 配置先 |
|---|---|
| `agent-os/claude/CLAUDE.md` | `<TARGET>/CLAUDE.md` |
| `agent-os/claude/skills/*` | `<TARGET>/.claude/skills/*` |
| `agent-os/claude/agents/*.md` | `<TARGET>/.claude/agents/*.md` |
| (生成される) | `<TARGET>/.agent-os/*`（project-profile.md, command-map.md, risk-map.md など） |

`bootstrap-project.sh` を使えば、これらを一括で配置できます。

```bash
bash agent-os/scripts/bootstrap-project.sh --target "$TARGET" --for claude
```

手動で行う場合は次のようになります。

```bash
cp agent-os/claude/CLAUDE.md "$TARGET/CLAUDE.md"
mkdir -p "$TARGET/.claude/skills" "$TARGET/.claude/agents"
cp -r agent-os/claude/skills/. "$TARGET/.claude/skills/"
cp -r agent-os/claude/agents/. "$TARGET/.claude/agents/"
```

既に `<TARGET>/CLAUDE.md` が存在する場合は上書きせず、冒頭に1行の参照を追加してください。

```markdown
See `agent-os/claude/CLAUDE.md`(このリポジトリからコピーした内容) for baseline agent principles.
```

## Codex 向けインストール

Codex では、次のファイルが対象プロジェクトの以下の場所に配置されます。

| 生成元 | 配置先 |
|---|---|
| `agent-os/codex/AGENTS.md` | `<TARGET>/AGENTS.md` |
| `agent-os/codex/agents/*.toml` | `<TARGET>/.codex/agents/*.toml` |
| `agent-os/codex/skills/*` | `<TARGET>/.agents/skills/*` |
| (生成される) | `<TARGET>/.agent-os/*` |

```bash
bash agent-os/scripts/bootstrap-project.sh --target "$TARGET" --for codex
```

手動で行う場合:

```bash
cp agent-os/codex/AGENTS.md "$TARGET/AGENTS.md"
mkdir -p "$TARGET/.codex/agents" "$TARGET/.agents/skills"
cp -r agent-os/codex/agents/. "$TARGET/.codex/agents/"
cp -r agent-os/codex/skills/. "$TARGET/.agents/skills/"
```

## Claude Code と Codex を両方使うプロジェクト

同じプロジェクトで Claude Code と Codex の両方を使う場合は、`--for both` を指定します。両方のファイル一式が配置され、`.agent-os/` は共通で1つだけ生成されます（Project Adapter Layer はツールを問わず共有されるためです）。

```bash
bash agent-os/scripts/bootstrap-project.sh --target "$TARGET" --for both
```

## 初回実行手順（First-run procedure）

配置が終わっても、それだけではまだ「汎用の Global Layer」が置かれただけの状態です。**コードを一切変更する前に**、次の順序で `project-bootstrap` スキルを実行してください。

1. Claude Code / Codex のセッションを `<TARGET>` で開始する。
2. `project-bootstrap` スキルを呼び出す（例: Claude Code なら `.claude/skills/project-bootstrap/SKILL.md` が読み込まれる状態で「プロジェクトを bootstrap して」と依頼する）。
3. このスキルは観測専用（observe only）であり、コードは変更しません。実行が完了すると次が生成されます。
   - `<TARGET>/.agent-os/project-profile.md`
   - `<TARGET>/.agent-os/command-map.md`
   - `<TARGET>/.agent-os/risk-map.md`
4. これらのアダプタファイルが生成された後に、初めて `adapt-to-project` スキルを実行し、Global Layer の原則をこのプロジェクトに合わせて具体化します。

この順序（bootstrap → adapt）を守らずにいきなりコード変更のタスクを依頼すると、エージェントはプロジェクト固有のコマンドやリスクを知らないまま作業することになるため、必ず初回はこの手順を先に踏んでください。

## インストールの検証方法

配置が正しく行われたかどうかは、付属の検証スクリプトで確認します。

```bash
# Agent OS リポジトリ自体の構成を検証する
bash agent-os/scripts/validate-agent-os.sh

# 導入先プロジェクトのアダプタを検証する
bash agent-os/scripts/validate-agent-os.sh --adapter "$TARGET"
```

このスクリプトは以下を確認します。

- （デフォルト）`agent-os/` リポジトリ自体に必須ファイルがすべて存在し、常時読み込みファイルが肥大化していないか。
- （`--adapter` 指定時）`<TARGET>/.agent-os/` 配下に必須の8ファイル（`project-profile.md`、`learned-rules.md`、`failure-log.md`、`review-feedback-log.md`、`evals.md`、`command-map.md`、`architecture-map.md`、`risk-map.md`）が存在するか。
- （`--adapter` 指定時）`learned-rules.md` の `Status:` の値が `candidate` / `active` / `deprecated` のいずれかになっているか。

検証がすべて成功したら、通常のコーディングタスクを依頼して問題ありません。エラーが出た場合は、該当するコピー手順またはスキルの実行をやり直してください。

## トラブルシューティング

- `bootstrap-project.sh` がエラーになる場合は、`--target` に渡したパスが存在し、書き込み権限があることを確認してください。
- `.agent-os/` が生成されない場合は、先に配置手順（ファイルのコピー）が完了しているか、`project-bootstrap` スキルを実行し忘れていないかを確認してください。
- ルールの矛盾や肥大化に気づいた場合は、インストールのやり直しではなく `improve-instructions` スキルと `agent-os/scripts/detect-rule-conflicts.sh` の実行で対処してください（詳細は `README.md` を参照）。
