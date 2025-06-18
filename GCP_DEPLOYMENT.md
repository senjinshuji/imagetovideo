# Google Cloud Platform デプロイガイド

## 前提条件
- Google Cloud アカウント
- `image-to-video` プロジェクトへのアクセス権限
- Docker Desktop インストール済み
- Google Cloud SDK (gcloud) インストール済み

## 環境準備

### 1. gcloud CLIのインストール
```bash
# macOS
brew install google-cloud-sdk

# または公式インストーラー
curl https://sdk.cloud.google.com | bash
```

### 2. 認証とプロジェクト設定
```bash
# Google Cloudにログイン
gcloud auth login

# プロジェクトを設定
gcloud config set project image-to-video

# 現在の設定確認
gcloud config list
```

### 3. 環境変数の設定
```bash
# .envファイルをコピーして編集
cp .env.example .env

# 以下を設定：
# OPENAI_API_KEY=sk-...
# KLING_ACCESS_KEY=At8fkCe3NpKyeFrHBEh9JtJLCCteCJgf
# KLING_SECRET_KEY=pJent9rFbmCHGDYndk3dmMyG4PHyagL8
```

## ワンコマンドデプロイ

```bash
# デプロイスクリプトを実行
./deploy-to-gcp.sh
```

これで以下が自動的に行われます：
1. 必要なGoogle Cloud APIの有効化
2. Dockerイメージのビルド
3. Artifact Registryへのプッシュ
4. Cloud SQLインスタンスの作成
5. Cloud Runへのデプロイ

## 手動デプロイ手順

### 1. 必要なAPIを有効化
```bash
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  sqladmin.googleapis.com
```

### 2. Artifact Registry リポジトリ作成
```bash
gcloud artifacts repositories create image-to-video \
  --repository-format=docker \
  --location=asia-northeast1
```

### 3. Docker認証設定
```bash
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
```

### 4. Dockerイメージのビルドとプッシュ
```bash
# バックエンド
docker build -t asia-northeast1-docker.pkg.dev/image-to-video/image-to-video/backend:latest ./image-to-video-backend
docker push asia-northeast1-docker.pkg.dev/image-to-video/image-to-video/backend:latest

# フロントエンド
docker build -t asia-northeast1-docker.pkg.dev/image-to-video/image-to-video/frontend:latest ./image-to-video-frontend
docker push asia-northeast1-docker.pkg.dev/image-to-video/image-to-video/frontend:latest
```

### 5. Cloud SQL設定（初回のみ）
```bash
# インスタンス作成
gcloud sql instances create image-to-video-db \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=asia-northeast1

# データベース作成
gcloud sql databases create image_to_video \
  --instance=image-to-video-db

# パスワード設定
gcloud sql users set-password postgres \
  --instance=image-to-video-db \
  --password=postgres123
```

### 6. Cloud Runデプロイ
```bash
# バックエンド
gcloud run deploy image-to-video-backend \
  --image=asia-northeast1-docker.pkg.dev/image-to-video/image-to-video/backend:latest \
  --region=asia-northeast1 \
  --allow-unauthenticated \
  --add-cloudsql-instances=image-to-video:asia-northeast1:image-to-video-db \
  --set-env-vars="OPENAI_API_KEY=$OPENAI_API_KEY,KLING_ACCESS_KEY=$KLING_ACCESS_KEY,KLING_SECRET_KEY=$KLING_SECRET_KEY"

# フロントエンド（バックエンドURL取得後）
BACKEND_URL=$(gcloud run services describe image-to-video-backend --region=asia-northeast1 --format="value(status.url)")

gcloud run deploy image-to-video-frontend \
  --image=asia-northeast1-docker.pkg.dev/image-to-video/image-to-video/frontend:latest \
  --region=asia-northeast1 \
  --allow-unauthenticated \
  --set-env-vars="NEXT_PUBLIC_API_URL=$BACKEND_URL/api/v1,OPENAI_API_KEY=$OPENAI_API_KEY,KLING_ACCESS_KEY=$KLING_ACCESS_KEY,KLING_SECRET_KEY=$KLING_SECRET_KEY"
```

## デプロイ後の確認

### URLの確認
```bash
# フロントエンドURL
gcloud run services describe image-to-video-frontend --region=asia-northeast1 --format="value(status.url)"

# バックエンドURL
gcloud run services describe image-to-video-backend --region=asia-northeast1 --format="value(status.url)"
```

### ログの確認
```bash
# フロントエンドのログ
gcloud run logs read --service=image-to-video-frontend --region=asia-northeast1

# バックエンドのログ
gcloud run logs read --service=image-to-video-backend --region=asia-northeast1
```

## トラブルシューティング

### イメージプッシュエラー
```bash
# 認証を再設定
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
```

### Cloud Runデプロイエラー
```bash
# サービスの詳細確認
gcloud run services describe image-to-video-backend --region=asia-northeast1

# イベントログ確認
gcloud run revisions list --service=image-to-video-backend --region=asia-northeast1
```

### データベース接続エラー
```bash
# Cloud SQL Proxyを使用してローカルテスト
cloud_sql_proxy -instances=image-to-video:asia-northeast1:image-to-video-db=tcp:5432
```

## コスト最適化

1. **Cloud Run**: 最小インスタンス数を0に設定（使用時のみ起動）
2. **Cloud SQL**: 開発時はdb-f1-microを使用
3. **リージョン**: asia-northeast1（東京）を使用してレイテンシを削減

## セキュリティ

1. **APIキー管理**: Secret Managerの使用を推奨
```bash
# シークレット作成
echo -n "$OPENAI_API_KEY" | gcloud secrets create openai-api-key --data-file=-
```

2. **IAMロール**: 最小権限の原則に従う
3. **ネットワーク**: 必要に応じてVPCコネクタを設定

## 更新とロールバック

### アプリケーション更新
```bash
# 新しいイメージをビルドしてデプロイ
docker build -t asia-northeast1-docker.pkg.dev/image-to-video/image-to-video/backend:v2 ./image-to-video-backend
docker push asia-northeast1-docker.pkg.dev/image-to-video/image-to-video/backend:v2
gcloud run deploy image-to-video-backend --image=asia-northeast1-docker.pkg.dev/image-to-video/image-to-video/backend:v2 --region=asia-northeast1
```

### ロールバック
```bash
# 以前のリビジョンにロールバック
gcloud run services update-traffic image-to-video-backend --to-revisions=REVISION_NAME=100 --region=asia-northeast1
```