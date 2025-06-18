#!/bin/bash
# Claude Code 自動承認スクリプト

# 環境変数で自動承認モードを設定
export CLAUDE_AUTO_APPROVE=true
export CLAUDE_SKIP_CONFIRMATIONS=true
export CLAUDE_DANGEROUS_PERMISSIONS=true

# Claude Code起動時にフラグを設定
echo "🤖 自動承認モード: 有効"
echo "⚡ 全ての操作が自動的に承認されます"