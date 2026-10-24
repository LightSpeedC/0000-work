#!/bin/bash
# クラウドセッションの開始時の入り口。共有ツール（ai-agent-tools）が無ければ隣に clone し、
# cloud-session-start に準備を任せる。手順は共通ルール「クラウド作業のルール」。
# そのあと、このプロジェクトと隣の ai-obsidian-vault を fetch して rebase する。
# ローカル（CLAUDE_CODE_REMOTE が true でない）では何もしない。
#
# 自分自身（0000-work）を rebase で書き換えるため、本体は main にまとめ、読み終えてから走らせる。
set -euo pipefail

# fetch して rebase する。変更があれば報告する。$1=置き場
pull_repo() {
	local dest="$1" name before after
	name="$(basename "$dest")"
	if ! git -C "$dest" rev-parse --git-dir >/dev/null 2>&1; then
		return 0
	fi
	if [ -n "$(git -C "$dest" status --porcelain)" ]; then
		echo "$name に未 commit の変更があるため、更新しませんでした。中身を確かめず消さないこと。ユーザーに報告すること。"
		return 0
	fi
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
	after="$(git -C "$dest" rev-parse --short HEAD)"
	if [ "$before" != "$after" ]; then
		echo "$name を更新しました（$before → $after）。"
	fi
}

main() {
	if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
		return 0
	fi

	local project_dir tools_dir
	project_dir="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
	tools_dir="$(dirname "$project_dir")/ai-agent-tools"

	if [ ! -e "$tools_dir" ]; then
		if ! GIT_LFS_SKIP_SMUDGE=1 git clone --quiet --depth 1 https://github.com/LightSpeedC/ai-agent-tools "$tools_dir" >&2; then
			echo "ai-agent-tools の clone に失敗しました。共通ルール・共有ツールが使えません。ユーザーに報告すること。"
		else
			echo "ai-agent-tools を $tools_dir に clone しました。共有ツールは $tools_dir/bin にあります。"
		fi
	fi

	# cloud-session-start が入る前の古い clone なら、変更が無いときだけ最新に追いつかせる
	if [ -e "$tools_dir" ] && [ ! -e "$tools_dir/bin/cloud-session-start" ] && [ -z "$(git -C "$tools_dir" status --porcelain 2>/dev/null || echo dirty)" ]; then
		git -C "$tools_dir" pull --quiet --ff-only >&2 || true
	fi

	if [ -e "$tools_dir/bin/cloud-session-start" ]; then
		bash "$tools_dir/bin/cloud-session-start" --project "$project_dir" ${CLAUDE_ENV_FILE:+--env-file "$CLAUDE_ENV_FILE"} || true
	elif [ -e "$tools_dir" ]; then
		echo "$tools_dir に cloud-session-start がありません。中身を確かめず消さないこと。ユーザーに報告すること。"
	fi

	# このプロジェクトと、隣の ai-obsidian-vault（非公開。セッションに追加して clone してあるときだけ）
	pull_repo "$project_dir"
	pull_repo "$(dirname "$project_dir")/ai-obsidian-vault"
	return 0
}

main "$@"
exit $?
