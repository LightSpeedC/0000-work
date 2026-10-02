# ローカルルール

このプロジェクトでだけ通る決めごと。全プロジェクトに通ることは共通ルールに置き、ここには書かない。

> 📅 作成: 2026-10-02 / 更新: 2026-10-02

[^^](../../README.md)

## 運用

### 1. クラウドセッションでの共通ルール・共有ツールの取得

クラウド（Claude Code on the web）のセッションは毎回新しい環境で始まるため、`AGENTS.md` が参照する `../ai-agent-rules/` も、`html2md` 等の共有ツールも無い。**SessionStart フックで、セッションの開始時に clone し、共有ツールを PATH に入れる**。

#### 値

| 項目 | 値 | 備考 |
|---|---|---|
| 共通ルール | `https://github.com/LightSpeedC/ai-agent-rules` | public。認証なしで clone できる |
| 共有ツール | `https://github.com/LightSpeedC/ai-agent-tools` | public。認証なしで clone できる |
| 置き場 | プロジェクトの隣の `ai-agent-rules/`・`ai-agent-tools/` | `AGENTS.md` の相対パス `../ai-agent-rules/` に合わせる |
| PATH | `../ai-agent-tools/bin` | `CLAUDE_ENV_FILE` に書き、セッション中のコマンドに効かせる |
| 動く条件 | `CLAUDE_CODE_REMOTE` が `true` | ローカルでは何もしない |
| 履歴 | `--depth 1` | 使うだけなので履歴は要らない |
| スクリプト | `tools/10_setup/clone-ai-agent-repos.sh` | `.claude/settings.json` の `SessionStart` から呼ぶ |

#### 決めごと

- **既にあれば clone しない**。pull もしない。クラウドのセッションは毎回 clone し直すので、常に最新になる。有無は `common-rules.md`・`bin/html2md` で見る
- **置き場に目印のファイルが無いものがあれば、消さずに報告する**
- **clone に失敗してもセッションは止めない**。失敗したことをフックの出力で伝え、ユーザーに報告する
- **共有ツールの `bin/` のうち、拡張子の無いもの（sh 版）に実行権限を付ける**。Windows で commit されたため、clone しただけでは権限が無く `Permission denied` になる。clone 側は `core.fileMode false` にし、権限の差を変更として出さない
- **Linux で動くのは拡張子の無いものだけ**。`.cmd`・`.ps1` は Windows 用。`html2md`・`check-public`・`check-markdown`・`convert-encoding`・`text`・`psls` の起動は確かめた
- **スクリプトは `.claude/hooks/` ではなく `tools/10_setup/` に置く**。共通ルールの「.gitignore の共通除外設定」では `.claude/` 配下で共有するのは `settings.json`・`commands/`・`agents/`・`skills/` だけで、`hooks/` は除外される

### 2. AGENTS.md に共通ルールの参照も置く

共通ルールの「ローカルルール（プロジェクトルール）」は、`AGENTS.md` に `local-rules.md` の参照だけを置くとしている。ここはそれと違い、**`common-rules.md` の参照も置く**。

- **なぜ**: ローカルではホーム配下の設定から共通ルールを読むが、クラウドのセッションにはそれが無い。`AGENTS.md` から参照しないと、共通ルールが読まれない
- **どこまで**: `AGENTS.md` の `common-rules.md` の参照（Codex 用のコメントを含む）だけ
- **いつまで**: クラウドのセッションで共通ルールを読む別の手段ができるまで

### 3. Stop フックの指示どおり commit・push する

クラウドの環境は、未 commit・未 push の変更があると、応答の終わりに「commit して push せよ」というフィードバックを返す。このプロジェクトでは、**そのフィードバックに従って commit し、push する**。

#### 共通ルールと違うところ

共通ルールの「重大な操作の確認方法」は、commit・push を「commitして」「pushして」の明示があるときだけ行うとしている。ここはそれと違い、**Stop フックのフィードバックを commit・push の指示として扱う**。

- **なぜ**: クラウドの環境はセッションが終わると消え、commit・push していない変更は残らない。フィードバックは応答のたびに来るため、確認を挟むと毎回止まる
- **どこまで**: Stop フックが求める commit と、作業中のブランチ（`develop`）への push だけ。ファイル削除・履歴の書き換え等、ほかの取り消しにくい操作は共通ルールどおり明示を待つ
- **いつまで**: このプロジェクトをクラウドで使うあいだ

#### 決めごと

- **commit の前の確認は省かない**。共通ルールの「コミット前の確認」に従い、`check-public` で新しく追跡するファイルを見る。指摘が残れば commit せず報告する
- **commit メッセージは共通ルールの「git の使い方」に従う**。`Claude-Session:` の行は付けない
- **commit・push したら、何を commit したかを応答で伝える**

[^^](../../README.md)
