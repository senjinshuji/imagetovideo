#!/bin/bash
# Claude開発記録・コンテキスト記録スクリプト

TASK_DESCRIPTION="$1"
DETAILS="$2"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
DATE=$(date '+%Y-%m-%d')

CLAUDE_MD="CLAUDE.md"

# セッション開始時の記録
if [ "$1" = "session-start" ]; then
    echo "" >> "$CLAUDE_MD"
    echo "### $DATE セッション開始" >> "$CLAUDE_MD"
    echo "**開始時刻**: $(date '+%H:%M')" >> "$CLAUDE_MD"
    echo "" >> "$CLAUDE_MD"
    echo "**前回からの継続事項**" >> "$CLAUDE_MD"
    echo "- 開発環境構築済み" >> "$CLAUDE_MD"
    echo "" >> "$CLAUDE_MD"
fi

# タスク完了時の記録
if [ "$1" = "task-complete" ]; then
    echo "**完了タスク**: $DETAILS" >> "$CLAUDE_MD"
    echo "- ✅ $(date '+%H:%M') - $DETAILS" >> "$CLAUDE_MD"
    echo "" >> "$CLAUDE_MD"
fi

# 技術決定の記録
if [ "$1" = "tech-decision" ]; then
    # CLAUDE.mdの「技術的な決定事項」セクションを更新
    echo "- $DETAILS ($(date '+%m/%d %H:%M'))" >> "$CLAUDE_MD"
fi

# 最終更新時刻を更新
sed -i '' "s/\*最終更新:.*\*/\*最終更新: $TIMESTAMP\*/" "$CLAUDE_MD"

echo "📝 開発記録を更新しました: $TASK_DESCRIPTION"