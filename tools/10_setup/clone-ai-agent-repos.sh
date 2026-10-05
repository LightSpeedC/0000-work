#!/bin/bash
# クラウドセッションの開始時に、共通ルール（ai-agent-rules）と共有ツール（ai-agent-tools）を
# プロジェクトの隣へ取得し、共有ツールの bin/ を PATH に入れる。
# 既にあるときは、日（JST）が変わっていれば fetch して rebase する。
# AGENTS.md の `@../ai-agent-rules/common-rules.md` が読め、html2md 等を名前で呼べるようにするため。
# ローカル（CLAUDE_CODE_REMOTE が true でない）では何もしない。
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
parent_dir="$(dirname "$project_dir")"
today="$(TZ=Asia/Tokyo date +%F)"

# 最後に取得・更新した日の記録先。.git の中なので git 管理外。$1=置き場
stamp_path() {
	echo "$(git -C "$1" rev-parse --absolute-git-dir)/last-update-date"
}

# 日が変わっていれば fetch して rebase する。$1=リポジトリ名 $2=更新後に読ませる指示
update_repo() {
	local name="$1" note="$2"
	local dest="$parent_dir/$name"
	local stamp
	stamp="$(stamp_path "$dest")"

	if [ "$(cat "$stamp" 2>/dev/null || true)" = "$today" ]; then
		return 0
	fi

	if [ -n "$(git -C "$dest" status --porcelain)" ]; then
		echo "$name に未 commit の変更があるため、更新しませんでした。中身を確かめず消さないこと。ユーザーに報告すること。"
		return 0
	fi

	local before after
	before="$(git -C "$dest" rev-parse --short HEAD)"
	if ! git -C "$dest" fetch --quiet origin >&2; then
		echo "$name の fetch に失敗しました。古いまま使っています。ユーザーに報告すること。"
		return 0
	fi
	if ! git -C "$dest" rebase --quiet '@{u}' >&2; then
		git -C "$dest" rebase --abort >/dev/null 2>&1 || true
		echo "$name の rebase に失敗したため、元に戻しました。古いまま使っています。ユーザーに報告すること。"
		return 0
	fi
	echo "$today" > "$stamp"

	after="$(git -C "$dest" rev-parse --short HEAD)"
	if [ "$before" != "$after" ]; then
		echo "$name を更新しました（$before → $after）。$note"
	fi
}

# 無ければ取得し、あれば日が変わったときだけ更新する。
# $1=リポジトリ名 $2=有無の判定に使うファイル $3=取得・更新後に読ませる指示
clone_repo() {
	local name="$1" marker="$2" note="$3"
	local url="https://github.com/LightSpeedC/$name"
	local dest="$parent_dir/$name"

	if [ -e "$dest/$marker" ]; then
		update_repo "$name" "$note"
		return 0
	fi

	if [ -e "$dest" ]; then
		echo "$name の置き場 $dest は既にありますが、$marker がありません。中身を確かめず消さないこと。ユーザーに報告すること。"
		return 1
	fi

	if GIT_LFS_SKIP_SMUDGE=1 git clone --quiet --depth 1 "$url" "$dest" >&2; then
		echo "$today" > "$(stamp_path "$dest")"
		echo "$name を $dest に clone しました。$note"
	else
		echo "$name（$url）の clone に失敗しました。ユーザーに報告すること。"
		return 1
	fi
}

clone_repo "ai-agent-rules" "common-rules.md" \
	"AGENTS.md の参照が読み込まれていない、または古い場合は、作業開始前に $parent_dir/ai-agent-rules/common-rules.md を読み、その指示に従うこと。" || true

tools_bin="$parent_dir/ai-agent-tools/bin"
if clone_repo "ai-agent-tools" "bin/html2md" "共有ツールは $tools_bin にあり、PATH に入れてあります。"; then
	# Windows で commit されたため実行権限が無い。拡張子の無いもの（sh 版）だけに付ける。
	# 更新で増えたものにも付けるため、毎回付け直す
	git -C "$parent_dir/ai-agent-tools" config core.fileMode false
	find "$tools_bin" -maxdepth 1 -type f ! -name "*.*" -exec chmod +x {} +

	if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
		echo "export PATH=\"$tools_bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
	else
		echo "CLAUDE_ENV_FILE が無いため、$tools_bin を PATH に入れられませんでした。共有ツールはフルパスで呼ぶこと。"
	fi
fi

# author は ai-agent-rules から読むので、clone の後に呼ぶ（SessionStart の hooks を並べると同時に走る）
bash "$(dirname "$0")/set-git-author.sh" || true
exit 0
