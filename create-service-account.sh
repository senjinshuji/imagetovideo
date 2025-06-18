#!/bin/bash

# サービスアカウント作成スクリプト
set -e

echo "🔧 Creating GCP Service Account"

PROJECT_ID="image-to-video"
SERVICE_ACCOUNT_NAME="image-to-video-deploy"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# カラー出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 既存の認証確認
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo -e "${YELLOW}⚠️  gcloudにログインしていません${NC}"
    echo "まず以下のコマンドでログインしてください:"
    echo -e "${GREEN}gcloud auth login${NC}"
    exit 1
fi

# プロジェクト設定
echo -e "${GREEN}📋 プロジェクト設定中...${NC}"
gcloud config set project ${PROJECT_ID}

# サービスアカウント作成
echo -e "${GREEN}👤 サービスアカウント作成中...${NC}"
if gcloud iam service-accounts describe ${SERVICE_ACCOUNT_EMAIL} 2>/dev/null; then
    echo -e "${YELLOW}サービスアカウントは既に存在します${NC}"
else
    gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} \
        --display-name="Image to Video Deployment Service Account" \
        --description="Service account for deploying Image to Video application"
    echo -e "${GREEN}✅ サービスアカウントを作成しました${NC}"
fi

# 必要なロールを付与
echo -e "${GREEN}🔑 必要なロールを付与中...${NC}"

ROLES=(
    "roles/artifactregistry.admin"
    "roles/cloudbuild.builds.editor"
    "roles/cloudsql.admin"
    "roles/run.admin"
    "roles/iam.serviceAccountUser"
    "roles/storage.admin"
    "roles/serviceusage.serviceUsageAdmin"
)

for ROLE in "${ROLES[@]}"; do
    echo "  - ${ROLE}"
    gcloud projects add-iam-policy-binding ${PROJECT_ID} \
        --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
        --role="${ROLE}" \
        --quiet 2>/dev/null || true
done

# キーファイルが既に存在する場合は確認
if [ -f "gcp-service-account-key.json" ]; then
    echo -e "${YELLOW}⚠️  既存のキーファイルが見つかりました${NC}"
    read -p "新しいキーを作成しますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}既存のキーを使用します${NC}"
        exit 0
    fi
    rm -f gcp-service-account-key.json
fi

# サービスアカウントキーを作成
echo -e "${GREEN}🔐 サービスアカウントキーを作成中...${NC}"
gcloud iam service-accounts keys create gcp-service-account-key.json \
    --iam-account=${SERVICE_ACCOUNT_EMAIL}

echo -e "${GREEN}✅ サービスアカウントキーを作成しました${NC}"
echo -e "${YELLOW}📄 キーファイル: gcp-service-account-key.json${NC}"

# .gitignoreに追加
if ! grep -q "gcp-service-account-key.json" .gitignore 2>/dev/null; then
    echo "gcp-service-account-key.json" >> .gitignore
    echo -e "${GREEN}✅ .gitignoreにキーファイルを追加しました${NC}"
fi

echo ""
echo -e "${GREEN}🎉 セットアップ完了！${NC}"
echo ""
echo "次のコマンドでデプロイを実行できます:"
echo -e "${YELLOW}./setup-gcp-cli.sh${NC}"
echo -e "${YELLOW}./deploy-to-gcp.sh${NC}"