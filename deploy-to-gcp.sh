#!/bin/bash

# GCPデプロイスクリプト
set -e

echo "🚀 Starting GCP deployment for image-to-video project..."

# プロジェクト設定
PROJECT_ID="image-to-video-463301"
REGION="asia-northeast1"

# カラー出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 環境変数チェック
check_env() {
    if [ -z "$OPENAI_API_KEY" ]; then
        echo -e "${RED}Error: OPENAI_API_KEY is not set${NC}"
        exit 1
    fi
    if [ -z "$KLING_ACCESS_KEY" ]; then
        echo -e "${RED}Error: KLING_ACCESS_KEY is not set${NC}"
        exit 1
    fi
    if [ -z "$KLING_SECRET_KEY" ]; then
        echo -e "${RED}Error: KLING_SECRET_KEY is not set${NC}"
        exit 1
    fi
}

# .envファイルが存在する場合は読み込む
if [ -f .env ]; then
    echo "📄 Loading environment variables from .env file..."
    export $(cat .env | grep -v '^#' | xargs)
fi

check_env

echo -e "${YELLOW}📋 Project ID: $PROJECT_ID${NC}"
echo -e "${YELLOW}📍 Region: $REGION${NC}"

# gcloudプロジェクト設定
echo "🔧 Setting up gcloud configuration..."
gcloud config set project $PROJECT_ID

# 必要なAPIを有効化
echo "🔌 Enabling required APIs..."
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable sqladmin.googleapis.com

# Artifact Registryリポジトリ作成（存在しない場合）
echo "📦 Setting up Artifact Registry..."
gcloud artifacts repositories create image-to-video \
    --repository-format=docker \
    --location=$REGION \
    --description="Image to Video Docker images" \
    2>/dev/null || echo "Repository already exists"

# Docker認証設定
echo "🔐 Configuring Docker authentication..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev

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

# Cloud SQLインスタンスの作成（存在しない場合）
echo "💾 Setting up Cloud SQL..."
if ! gcloud sql instances describe image-to-video-db --region=$REGION 2>/dev/null; then
    echo "Creating Cloud SQL instance..."
    gcloud sql instances create image-to-video-db \
        --database-version=POSTGRES_15 \
        --tier=db-f1-micro \
        --region=$REGION \
        --network=default
    
    # データベース作成
    gcloud sql databases create image_to_video \
        --instance=image-to-video-db
    
    # パスワード設定
    gcloud sql users set-password postgres \
        --instance=image-to-video-db \
        --password=postgres123
else
    echo "Cloud SQL instance already exists"
fi

# Cloud SQL接続名を取得
CLOUD_SQL_CONNECTION=$(gcloud sql instances describe image-to-video-db --format="value(connectionName)")
echo "Cloud SQL Connection: $CLOUD_SQL_CONNECTION"

# バックエンドをCloud Runにデプロイ
echo -e "${GREEN}☁️  Deploying backend to Cloud Run...${NC}"
gcloud run deploy image-to-video-backend \
    --image=${REGION}-docker.pkg.dev/${PROJECT_ID}/image-to-video/backend:latest \
    --region=$REGION \
    --platform=managed \
    --allow-unauthenticated \
    --add-cloudsql-instances=$CLOUD_SQL_CONNECTION \
    --set-env-vars="OPENAI_API_KEY=${OPENAI_API_KEY},KLING_ACCESS_KEY=${KLING_ACCESS_KEY},KLING_SECRET_KEY=${KLING_SECRET_KEY},DATABASE_URL=postgresql+asyncpg://postgres:postgres123@localhost:5432/image_to_video?host=/cloudsql/${CLOUD_SQL_CONNECTION}" \
    --memory=2Gi \
    --cpu=2 \
    --min-instances=0 \
    --max-instances=10

# バックエンドのURLを取得
BACKEND_URL=$(gcloud run services describe image-to-video-backend --region=$REGION --format="value(status.url)")
echo -e "${GREEN}Backend URL: $BACKEND_URL${NC}"

# フロントエンドをCloud Runにデプロイ
echo -e "${GREEN}☁️  Deploying frontend to Cloud Run...${NC}"
gcloud run deploy image-to-video-frontend \
    --image=${REGION}-docker.pkg.dev/${PROJECT_ID}/image-to-video/frontend:latest \
    --region=$REGION \
    --platform=managed \
    --allow-unauthenticated \
    --set-env-vars="NEXT_PUBLIC_API_URL=${BACKEND_URL}/api/v1,OPENAI_API_KEY=${OPENAI_API_KEY},KLING_ACCESS_KEY=${KLING_ACCESS_KEY},KLING_SECRET_KEY=${KLING_SECRET_KEY}" \
    --memory=1Gi \
    --cpu=1 \
    --min-instances=0 \
    --max-instances=10

# フロントエンドのURLを取得
FRONTEND_URL=$(gcloud run services describe image-to-video-frontend --region=$REGION --format="value(status.url)")

echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo -e "${GREEN}🌐 Frontend URL: $FRONTEND_URL${NC}"
echo -e "${GREEN}🔧 Backend URL: $BACKEND_URL${NC}"
echo -e "${GREEN}📚 API Docs: ${BACKEND_URL}/api/v1/docs${NC}"

# デプロイ情報を保存
cat > deployment-info.txt << EOF
Deployment Information
=====================
Date: $(date)
Project ID: $PROJECT_ID
Region: $REGION

Frontend URL: $FRONTEND_URL
Backend URL: $BACKEND_URL
API Docs: ${BACKEND_URL}/api/v1/docs

Cloud SQL Instance: image-to-video-db
Cloud SQL Connection: $CLOUD_SQL_CONNECTION
EOF

echo -e "${YELLOW}📝 Deployment information saved to deployment-info.txt${NC}"