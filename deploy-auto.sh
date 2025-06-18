#!/bin/bash

# 自動デプロイスクリプト
# 使い方: ./deploy-auto.sh

set -e

echo "🚀 GCP自動デプロイを開始します..."

# 環境変数チェック
if [ -f .env ]; then
    source .env
fi

required_vars=("OPENAI_API_KEY" "KLING_ACCESS_KEY" "KLING_SECRET_KEY")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ エラー: $var が設定されていません"
        echo "💡 .envファイルを作成するか、環境変数を設定してください"
        exit 1
    fi
done

# プロジェクト設定
PROJECT_ID="image-to-video-463301"
REGION="asia-northeast1"

# 現在の認証状態を確認
echo "📋 認証状態を確認中..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "❌ 認証されていません。以下のいずれかの方法で認証してください："
    echo ""
    echo "1. サービスアカウント認証（推奨）:"
    echo "   ./create-service-account.sh"
    echo "   gcloud auth activate-service-account --key-file=gcp-service-account-key.json"
    echo ""
    echo "2. OAuth認証:"
    echo "   gcloud auth login"
    echo ""
    exit 1
fi

# プロジェクト設定
echo "🔧 プロジェクトを設定中..."
gcloud config set project $PROJECT_ID

# デプロイ方法の選択
echo ""
echo "デプロイ方法を選択してください:"
echo "1. ローカルスクリプトでデプロイ (./deploy-to-gcp.sh)"
echo "2. Cloud Buildでデプロイ (cloudbuild.yaml)"
echo -n "選択 (1 or 2): "
read choice

case $choice in
    1)
        echo "📦 ローカルスクリプトでデプロイを実行..."
        ./deploy-to-gcp.sh
        ;;
    2)
        echo "☁️ Cloud Buildでデプロイを実行..."
        # Cloud SQL接続名を取得
        CLOUD_SQL_CONNECTION=$(gcloud sql instances describe image-to-video-db --format="value(connectionName)" 2>/dev/null || echo "")
        
        if [ -z "$CLOUD_SQL_CONNECTION" ]; then
            echo "⚠️ Cloud SQLインスタンスが見つかりません。新規作成します..."
            CLOUD_SQL_CONNECTION="$PROJECT_ID:$REGION:image-to-video-db"
        fi
        
        # DB_PASSWORDの設定
        if [ -z "$DB_PASSWORD" ]; then
            DB_PASSWORD=$(openssl rand -base64 32)
            echo "🔑 新しいデータベースパスワードを生成しました"
        fi
        
        gcloud builds submit --config=cloudbuild.yaml \
            --substitutions=_OPENAI_API_KEY="${OPENAI_API_KEY}",_KLING_ACCESS_KEY="${KLING_ACCESS_KEY}",_KLING_SECRET_KEY="${KLING_SECRET_KEY}",_CLOUD_SQL_CONNECTION_NAME="${CLOUD_SQL_CONNECTION}",_DB_PASSWORD="${DB_PASSWORD}"
        ;;
    *)
        echo "❌ 無効な選択です"
        exit 1
        ;;
esac

echo ""
echo "✅ デプロイが完了しました！"
echo ""
echo "📱 アプリケーションURL:"
echo "Frontend: https://image-to-video-frontend-xxxxx-an.a.run.app"
echo "Backend: https://image-to-video-backend-xxxxx-an.a.run.app"
echo ""
echo "📊 GCPコンソール:"
echo "https://console.cloud.google.com/run?project=$PROJECT_ID"