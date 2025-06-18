#!/bin/bash

# OAuth2を使用したCLI認証とデプロイ
set -e

echo "🚀 GCP Deployment with OAuth2 Authentication"

PROJECT_ID="image-to-video"
REGION="asia-northeast1"

# カラー出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 環境変数チェック
if [ -z "$OPENAI_API_KEY" ]; then
    if [ -f .env ]; then
        export $(cat .env | grep -v '^#' | xargs)
    else
        echo -e "${RED}Error: .env file not found or OPENAI_API_KEY not set${NC}"
        exit 1
    fi
fi

# ADC (Application Default Credentials) を使用して認証
echo -e "${GREEN}🔐 アプリケーションデフォルト認証を設定中...${NC}"
gcloud auth application-default login --no-launch-browser

# 認証コードを入力
echo -e "${YELLOW}ブラウザで表示されたURLにアクセスし、認証コードを取得してください${NC}"
echo -e "${YELLOW}認証が完了したら、Enterキーを押してください...${NC}"
read -p ""

# プロジェクト設定
echo -e "${GREEN}📋 プロジェクト設定中...${NC}"
gcloud config set project ${PROJECT_ID}

# 現在のユーザー確認
echo -e "${GREEN}👤 認証ユーザー:${NC}"
gcloud auth list

# 必要なAPIを有効化
echo -e "${GREEN}🔌 必要なAPIを有効化中...${NC}"
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable sqladmin.googleapis.com

# Artifact Registryリポジトリ作成
echo -e "${GREEN}📦 Artifact Registry設定中...${NC}"
gcloud artifacts repositories create image-to-video \
    --repository-format=docker \
    --location=${REGION} \
    --description="Image to Video Docker images" \
    2>/dev/null || echo "Repository already exists"

# Docker認証設定
echo -e "${GREEN}🐳 Docker認証設定中...${NC}"
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# デプロイ実行
echo -e "${GREEN}🚀 デプロイを開始します...${NC}"

# バックエンドイメージのビルドとプッシュ
echo -e "${GREEN}🏗️  Building backend Docker image...${NC}"
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/image-to-video/backend:latest ./image-to-video-backend

echo -e "${GREEN}📤 Pushing backend image...${NC}"
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/image-to-video/backend:latest

# フロントエンドイメージのビルドとプッシュ
echo -e "${GREEN}🏗️  Building frontend Docker image...${NC}"
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/image-to-video/frontend:latest ./image-to-video-frontend

echo -e "${GREEN}📤 Pushing frontend image...${NC}"
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/image-to-video/frontend:latest

# Cloud SQLインスタンスの確認/作成
echo -e "${GREEN}💾 Cloud SQL設定中...${NC}"
if ! gcloud sql instances describe image-to-video-db --region=${REGION} 2>/dev/null; then
    echo "Creating Cloud SQL instance..."
    gcloud sql instances create image-to-video-db \
        --database-version=POSTGRES_15 \
        --tier=db-f1-micro \
        --region=${REGION} \
        --network=default
    
    gcloud sql databases create image_to_video \
        --instance=image-to-video-db
    
    gcloud sql users set-password postgres \
        --instance=image-to-video-db \
        --password=postgres123
else
    echo "Cloud SQL instance already exists"
fi

# Cloud SQL接続名を取得
CLOUD_SQL_CONNECTION=$(gcloud sql instances describe image-to-video-db --format="value(connectionName)")

# バックエンドをCloud Runにデプロイ
echo -e "${GREEN}☁️  Deploying backend to Cloud Run...${NC}"
gcloud run deploy image-to-video-backend \
    --image=${REGION}-docker.pkg.dev/${PROJECT_ID}/image-to-video/backend:latest \
    --region=${REGION} \
    --platform=managed \
    --allow-unauthenticated \
    --add-cloudsql-instances=${CLOUD_SQL_CONNECTION} \
    --set-env-vars="OPENAI_API_KEY=${OPENAI_API_KEY},KLING_ACCESS_KEY=${KLING_ACCESS_KEY},KLING_SECRET_KEY=${KLING_SECRET_KEY},DATABASE_URL=postgresql+asyncpg://postgres:postgres123@localhost:5432/image_to_video?host=/cloudsql/${CLOUD_SQL_CONNECTION}" \
    --memory=2Gi \
    --cpu=2

# バックエンドのURLを取得
BACKEND_URL=$(gcloud run services describe image-to-video-backend --region=${REGION} --format="value(status.url)")

# フロントエンドをCloud Runにデプロイ
echo -e "${GREEN}☁️  Deploying frontend to Cloud Run...${NC}"
gcloud run deploy image-to-video-frontend \
    --image=${REGION}-docker.pkg.dev/${PROJECT_ID}/image-to-video/frontend:latest \
    --region=${REGION} \
    --platform=managed \
    --allow-unauthenticated \
    --set-env-vars="NEXT_PUBLIC_API_URL=${BACKEND_URL}/api/v1,OPENAI_API_KEY=${OPENAI_API_KEY},KLING_ACCESS_KEY=${KLING_ACCESS_KEY},KLING_SECRET_KEY=${KLING_SECRET_KEY}" \
    --memory=1Gi \
    --cpu=1

# フロントエンドのURLを取得
FRONTEND_URL=$(gcloud run services describe image-to-video-frontend --region=${REGION} --format="value(status.url)")

echo -e "${GREEN}✅ デプロイ完了！${NC}"
echo -e "${GREEN}🌐 Frontend URL: ${FRONTEND_URL}${NC}"
echo -e "${GREEN}🔧 Backend URL: ${BACKEND_URL}${NC}"
echo -e "${GREEN}📚 API Docs: ${BACKEND_URL}/api/v1/docs${NC}"