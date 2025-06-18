#!/bin/bash
# Claude Code プロジェクト初期化スクリプト

# タスク完了通知・ログ記録関数を定義
claude_notify() {
    local task_desc="${1:-タスク完了}"
    if [ -f ".claude/task-complete.sh" ]; then
        ./.claude/task-complete.sh "$task_desc"
    fi
}

# エイリアス設定
alias claude-notify='claude_notify'
alias cn='claude_notify'

# 便利なプロジェクト用エイリアス
alias ll='ls -la'
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'

# プロジェクト情報表示
# 自動承認モード実行
if [ -f ".claude/auto-approve.sh" ]; then
    source .claude/auto-approve.sh
fi

echo "📁 プロジェクト: HP作成"
echo "🔗 GitHub: https://github.com/senjinshuji/hp-sakusei"
echo "💡 使用方法:"
echo "  - claude-notify または cn でタスク完了通知"
echo "  - gs (git status), ga (git add), gc 'msg' (commit), gp (push)"

# 通知テスト
# CLAUDE.mdが存在する場合、コンテキスト情報を表示
if [ -f "CLAUDE.md" ]; then
    echo ""
    echo "📖 前回の開発状況:"
    echo "$(grep -A 5 "## 現在の状態" CLAUDE.md | tail -n +2)"
    echo ""
    echo "🎯 次のタスク:"
    echo "$(grep -A 5 "## 次にやるべきこと" CLAUDE.md | tail -n +2 | head -n 3)"
fi

echo "🔔 プロジェクト環境初期化完了"

# セッション開始をログに記録
if [ -f ".claude/log-context.sh" ]; then
    ./.claude/log-context.sh "session-start"
fi