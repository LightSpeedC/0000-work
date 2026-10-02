#!/bin/bash
# クラウドセッションで、このプロジェクトの git の author を ai-agent-rules の最新コミットと同じにする。
# クラウドの環境は author が Claude になっているため。
# 値はリポジトリにも出力にも書かない。書き込み先は .git/config（git 管理外）だけ。
# ローカル（CLAUDE_CODE_REMOTE が true でない）では何もしない。
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

# 環境変数で指定されていれば、git はそちらを使うので何もしない
if [ -n "${GIT_AUTHOR_NAME:-}" ] && [ -n "${GIT_AUTHOR_EMAIL:-}" ]; then
	exit 0
fi

project_dir="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
src="$(dirname "$project_dir")/ai-agent-rules"

name="$(git -C "$src" log -1 --format=%an 2>/dev/null || true)"
email="$(git -C "$src" log -1 --format=%ae 2>/dev/null || true)"

if [ -z "$name" ] || [ -z "$email" ]; then
	echo "ai-agent-rules から git の author を読めませんでした。commit の author は Claude のままになります。ユーザーに報告すること。"
	exit 0
fi

git -C "$project_dir" config user.name "$name"
git -C "$project_dir" config user.email "$email"
echo "git の author を ai-agent-rules の最新コミットと同じ値に設定しました（値は表示しない）。"
exit 0
