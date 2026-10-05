#!/bin/bash
# クラウドセッションの開始時の入り口。共有ツール（ai-agent-tools）が無ければ隣に clone し、
# cloud-session-start に準備を任せる。手順は共通ルール「クラウド作業のルール」。
# ローカル（CLAUDE_CODE_REMOTE が true でない）では何もしない。
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
tools_dir="$(dirname "$project_dir")/ai-agent-tools"

if [ ! -e "$tools_dir" ]; then
	if ! GIT_LFS_SKIP_SMUDGE=1 git clone --quiet --depth 1 https://github.com/LightSpeedC/ai-agent-tools "$tools_dir" >&2; then
		echo "ai-agent-tools の clone に失敗しました。共通ルール・共有ツールが使えません。ユーザーに報告すること。"
		exit 0
	fi
	echo "ai-agent-tools を $tools_dir に clone しました。共有ツールは $tools_dir/bin にあります。"
fi

# cloud-session-start が入る前の古い clone なら、変更が無いときだけ最新に追いつかせる
if [ ! -e "$tools_dir/bin/cloud-session-start" ] && [ -z "$(git -C "$tools_dir" status --porcelain 2>/dev/null || echo dirty)" ]; then
	git -C "$tools_dir" pull --quiet --ff-only >&2 || true
fi

if [ ! -e "$tools_dir/bin/cloud-session-start" ]; then
	echo "$tools_dir に cloud-session-start がありません。中身を確かめず消さないこと。ユーザーに報告すること。"
	exit 0
fi

bash "$tools_dir/bin/cloud-session-start" --project "$project_dir" ${CLAUDE_ENV_FILE:+--env-file "$CLAUDE_ENV_FILE"} || true
exit 0
