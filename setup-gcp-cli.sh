#!/bin/bash

# CLI経由でGCPセットアップを行うスクリプト
set -e

echo "🔧 GCP CLI Setup Script"

# カラー出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_ID="image-to-video"
REGION="asia-northeast1"
SERVICE_ACCOUNT_NAME="image-to-video-deploy"

# サービスアカウントキーの確認
if [ -f "gcp-service-account-key.json" ]; then
    echo -e "${GREEN}✅ サービスアカウントキーが見つかりました${NC}"
else
    echo -e "${YELLOW}⚠️  サービスアカウントキーが見つかりません${NC}"
    echo "以下の手順でサービスアカウントを作成してください："
    echo ""
    echo "1. ブラウザで Google Cloud Console を開く"
    echo "   https://console.cloud.google.com/iam-admin/serviceaccounts?project=${PROJECT_ID}"
    echo ""
    echo "2. 'サービスアカウントを作成' をクリック"
    echo "   - サービスアカウント名: ${SERVICE_ACCOUNT_NAME}"
    echo "   - 説明: Image to Video デプロイ用"
    echo ""
    echo "3. 以下のロールを付与:"
    echo "   - Cloud Build 編集者"
    echo "   - Cloud Run 管理者"
    echo "   - Artifact Registry 管理者"
    echo "   - Cloud SQL 管理者"
    echo "   - サービス アカウント ユーザー"
    echo ""
    echo "4. キーを作成（JSON形式）して、このディレクトリに"
    echo "   'gcp-service-account-key.json' として保存"
    echo ""
    exit 1
fi

# サービスアカウントで認証
echo -e "${GREEN}🔐 サービスアカウントで認証中...${NC}"
gcloud auth activate-service-account --key-file=gcp-service-account-key.json

# プロジェクト設定
echo -e "${GREEN}📋 プロジェクト設定中...${NC}"
gcloud config set project ${PROJECT_ID}

# 必要なAPIを有効化
echo -e "${GREEN}🔌 必要なAPIを有効化中...${NC}"
gcloud services enable cloudbuild.googleapis.com --quiet
gcloud services enable run.googleapis.com --quiet
gcloud services enable artifactregistry.googleapis.com --quiet
gcloud services enable sqladmin.googleapis.com --quiet

# Artifact Registryリポジトリ作成
echo -e "${GREEN}📦 Artifact Registry設定中...${NC}"
gcloud artifacts repositories create image-to-video \
    --repository-format=docker \
    --location=${REGION} \
    --description="Image to Video Docker images" \
    --quiet 2>/dev/null || echo "Repository already exists"

# Docker認証設定
echo -e "${GREEN}🐳 Docker認証設定中...${NC}"
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

echo -e "${GREEN}✅ CLI設定完了！${NC}"
echo ""
echo "次のコマンドでデプロイを実行できます:"
echo -e "${YELLOW}./deploy-to-gcp.sh${NC}"