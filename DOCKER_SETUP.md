# Docker環境セットアップガイド

## 前提条件
- Docker Desktop インストール済み
- Docker Compose V2 インストール済み
- Google Cloud SDK (gcloud) インストール済み（GCP デプロイの場合）

## ローカル開発環境

### 1. 環境変数の設定
```bash
# プロジェクトルートに.envファイルを作成
cp .env.example .env

# 以下の環境変数を設定
OPENAI_API_KEY=your_openai_key
KLING_ACCESS_KEY=your_kling_access_key
KLING_SECRET_KEY=your_kling_secret_key
```

### 2. 開発環境の起動
```bash
# 開発用Docker Composeで起動
docker-compose -f docker-compose.dev.yml up -d

# ログを確認
docker-compose -f docker-compose.dev.yml logs -f

# サービスの状態確認
docker-compose -f docker-compose.dev.yml ps
```

### 3. アクセスURL
- フロントエンド: http://localhost:3000
- バックエンドAPI: http://localhost:8000
- API ドキュメント: http://localhost:8000/api/v1/docs

### 4. データベースマイグレーション
```bash
# バックエンドコンテナに入る
docker-compose -f docker-compose.dev.yml exec backend bash

# マイグレーション実行
alembic upgrade head
```

### 5. 停止方法
```bash
docker-compose -f docker-compose.dev.yml down

# ボリュームも削除する場合
docker-compose -f docker-compose.dev.yml down -v
```

## 本番環境ビルド

### 1. イメージのビルド
```bash
# すべてのサービスをビルド
docker-compose build

# 個別にビルド
docker-compose build backend
docker-compose build frontend
```

### 2. 本番環境の起動
```bash
docker-compose up -d
```

## Google Cloud デプロイ

### 1. 事前準備
```bash
# プロジェクトIDを設定
export PROJECT_ID=your-gcp-project-id

# gcloud認証
gcloud auth login
gcloud config set project $PROJECT_ID

# 必要なAPIを有効化
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable sqladmin.googleapis.com
```

### 2. Cloud SQL インスタンスの作成
```bash
# PostgreSQL インスタンス作成
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
  --password=your-secure-password
```

### 3. シークレットの作成
```bash
# OpenAI APIキー
echo -n "your-openai-api-key" | gcloud secrets create openai-key --data-file=-

# KLING アクセスキー
echo -n "your-kling-access-key" | gcloud secrets create kling-access --data-file=-

# KLING シークレットキー
echo -n "your-kling-secret-key" | gcloud secrets create kling-secret --data-file=-

# データベースURL
echo -n "postgresql+asyncpg://postgres:password@/image_to_video?host=/cloudsql/PROJECT_ID:REGION:INSTANCE_NAME" | \
  gcloud secrets create db-url --data-file=-
```

### 4. サービスアカウントの作成
```bash
gcloud iam service-accounts create image-to-video-sa \
  --display-name="Image to Video Service Account"

# 必要な権限を付与
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:image-to-video-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:image-to-video-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### 5. Cloud Build でデプロイ
```bash
# cloudbuild.yaml の substitutions を更新してから実行
gcloud builds submit . \
  --config=cloudbuild.yaml \
  --substitutions=_OPENAI_API_KEY=$OPENAI_API_KEY,_KLING_ACCESS_KEY=$KLING_ACCESS_KEY,_KLING_SECRET_KEY=$KLING_SECRET_KEY,_CLOUD_SQL_CONNECTION_NAME=$PROJECT_ID:asia-northeast1:image-to-video-db,_DB_PASSWORD=your-db-password
```

### 6. 手動デプロイ（Cloud Run）
```bash
# バックエンドイメージをビルド＆プッシュ
docker build -t gcr.io/$PROJECT_ID/image-to-video-backend ./image-to-video-backend
docker push gcr.io/$PROJECT_ID/image-to-video-backend

# フロントエンドイメージをビルド＆プッシュ
docker build -t gcr.io/$PROJECT_ID/image-to-video-frontend ./image-to-video-frontend
docker push gcr.io/$PROJECT_ID/image-to-video-frontend

# サービス設定ファイルを更新してデプロイ
sed -i "s/YOUR_PROJECT_ID/$PROJECT_ID/g" backend-service.yaml
sed -i "s/YOUR_PROJECT_ID/$PROJECT_ID/g" frontend-service.yaml

gcloud run services replace backend-service.yaml --region=asia-northeast1
gcloud run services replace frontend-service.yaml --region=asia-northeast1
```

## トラブルシューティング

### ポート競合エラー
```bash
# 使用中のポートを確認
lsof -i :3000
lsof -i :8000
lsof -i :5432

# プロセスを終了
kill -9 <PID>
```

### Docker ビルドエラー
```bash
# キャッシュをクリア
docker system prune -a

# ビルドキャッシュなしで再ビルド
docker-compose build --no-cache
```

### データベース接続エラー
```bash
# PostgreSQLコンテナのログ確認
docker-compose logs db

# コンテナ内でPostgreSQLに接続
docker-compose exec db psql -U postgres -d image_to_video
```

### Next.js スタンドアローンビルドエラー
フロントエンドの `next.config.js` に以下を追加：
```javascript
module.exports = {
  output: 'standalone',
  // 他の設定...
}
```

## 開発のヒント

1. **ホットリロード**: 開発環境では、コードを変更すると自動的にリロードされます
2. **ログ確認**: `docker-compose logs -f [service-name]` で特定サービスのログを確認
3. **データベース永続化**: PostgreSQLのデータは`postgres_data`ボリュームに保存されます
4. **環境変数**: `.env`ファイルの変更後はコンテナを再起動してください