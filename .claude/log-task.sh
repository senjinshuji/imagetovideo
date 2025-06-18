#!/bin/bash
# Claude タスク完了ログ記録スクリプト

# 引数からタスク内容を取得（デフォルトは"タスク完了"）
TASK_DESCRIPTION="${1:-タスク完了}"
TIMESTAMP=$(date '+%H:%M')
DATE=$(date '+%Y-%m-%d')

# CLAUDE.mdファイルのパス
CLAUDE_MD="CLAUDE.md"

# 今日の日付セクションが存在するかチェック
if ! grep -q "### $DATE" "$CLAUDE_MD"; then
    # 新しい日付セクションを追加
    echo "" >> "$CLAUDE_MD"
    echo "### $DATE" >> "$CLAUDE_MD"
    echo "" >> "$CLAUDE_MD"
fi

# タスク完了ログを追加
echo "#### $TIMESTAMP - $TASK_DESCRIPTION" >> "$CLAUDE_MD"

# TodoListからの自動検出（もしあれば）
if [ -f ".claude/current-todos.json" ]; then
    echo "- ✅ 詳細はTodoListを参照" >> "$CLAUDE_MD"
else
    echo "- ✅ タスクが正常に完了しました" >> "$CLAUDE_MD"
fi

echo "" >> "$CLAUDE_MD"

echo "📝 CLAUDE.mdにログを記録しました: $TASK_DESCRIPTION"