# GCPセットアップ手順

## 1. gcloudにログイン

ブラウザで以下のコマンドを実行後、表示されるURLにアクセスしてログインしてください：

```bash
gcloud auth login
```

## 2. プロジェクト設定

```bash
gcloud config set project image-to-video
```

## 3. Docker認証設定

```bash
gcloud auth configure-docker asia-northeast1-docker.pkg.dev
```

## 4. デプロイ実行

環境変数が設定済みなので、以下のコマンドでデプロイできます：

```bash
./deploy-to-gcp.sh
```

## ローカルテスト環境

現在、Docker Composeで以下のサービスが起動中です：

- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/api/v1/docs

## 次のステップ

1. 上記のgcloudログインを完了
2. デプロイスクリプトを実行
3. デプロイ完了後、表示されるURLでアクセス確認