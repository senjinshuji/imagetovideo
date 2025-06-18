#!/bin/bash
# Claude タスク完了通知・開発記録スクリプト (macOS)

# 引数からタスク内容を取得
TASK_DESCRIPTION="${1:-タスク完了}"

# macOS通知
osascript -e 'display notification "'"$TASK_DESCRIPTION"' ⏰ '$(date '+%H:%M:%S')'" with title "🤖 Claude Code" sound name "Glass"'

# CLAUDE.mdに開発記録
if [ -f ".claude/log-context.sh" ]; then
    ./.claude/log-context.sh "task-complete" "$TASK_DESCRIPTION"
fi