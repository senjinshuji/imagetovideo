#!/bin/bash

# ヘッドレスCLIデプロイ（認証トークン使用）
set -e

echo "🚀 Headless GCP Deployment"

PROJECT_ID="image-to-video"
REGION="asia-northeast1"

# カラー出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# アクセストークンの確認
if [ -z "$GOOGLE_ACCESS_TOKEN" ]; then
    echo -e "${YELLOW}Google Cloud アクセストークンの取得方法:${NC}"
    echo ""
    echo "1. ブラウザで以下のURLにアクセス:"
    echo "   https://developers.google.com/oauthplayground/"
    echo ""
    echo "2. 左側のAPIリストから以下を選択:"
    echo "   - Google Cloud APIs > Cloud Resource Manager API v3"
    echo "   - Google Cloud APIs > Cloud Run Admin API v2"
    echo ""
    echo "3. 'Authorize APIs' をクリックしてGoogleアカウントでログイン"
    echo ""
    echo "4. 'Exchange authorization code for tokens' をクリック"
    echo ""
    echo "5. 取得した 'Access token' をコピー"
    echo ""
    echo "6. 以下のコマンドを実行:"
    echo -e "${GREEN}export GOOGLE_ACCESS_TOKEN='your-access-token-here'${NC}"
    echo -e "${GREEN}./deploy-headless.sh${NC}"
    echo ""
    exit 1
fi

# アクセストークンで認証
echo -e "${GREEN}🔐 アクセストークンで認証中...${NC}"
gcloud auth activate-access-token --access-token=${GOOGLE_ACCESS_TOKEN}

# プロジェクト設定
echo -e "${GREEN}📋 プロジェクト設定中...${NC}"
gcloud config set project ${PROJECT_ID}

# 以降は通常のデプロイプロセス
./deploy-to-gcp.sh