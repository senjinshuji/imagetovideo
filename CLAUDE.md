# Image to Video プロジェクト

## プロジェクト概要
- **プロジェクト名**: Image to Video
- **目的**: 画像から動画への変換アプリケーション
- **GitHub**: https://github.com/senjinshuji/imagetovideo
- **開始日**: 2025-06-16

## 実装済み機能

### 1. OpenAI画像生成API (gpt-image-1)

**ファイル**: `openai-image-generator.js`

**実装内容**:
- OpenAI gpt-image-1モデルを使用した画像生成
- Base64形式での画像データ取得
- ファイル保存機能付き

**使用方法**:
```javascript
const OpenAIImageGenerator = require('./openai-image-generator');

const generator = new OpenAIImageGenerator();
const result = await generator.generateImage("美しい風景");
const filename = generator.saveBase64Image(result.data[0].b64_json);
```

**API仕様**:
- エンドポイント: `https://api.openai.com/v1/images/generations`
- レスポンス形式: base64形式（b64_json）
- 画像サイズ: 1024x1024
- 必須パラメータ: model, prompt, n, size
- APIキー: 環境変数 `OPENAI_API_KEY` または直接設定

### 2. KLING AI動画生成API

**ファイル**: `kling-api.js`

**実装内容**:
- JWT認証システム
- Image-to-Video動画生成
- タスク状態確認・完了待機
- エラーハンドリング・リトライ機能

**使用方法**:
```javascript
const KlingVideoGenerator = require('./kling-api');

const generator = new KlingVideoGenerator();
const result = await generator.processImageToVideo(
    imageUrl, 
    "カメラが左から右にパンしながら美しい風景を映す",
    5
);
```

**API仕様**:
- エンドポイント: `https://api-singapore.klingai.com/v1/videos/image2video`
- 認証方式: JWT Bearer Token (HMAC-SHA256)
- 最大動画長: 5秒
- 対応解像度: 1920x1080
- 必須パラメータ: model, image, prompt, duration

**環境変数**:
```bash
KLING_ACCESS_KEY=At8fkCe3NpKyeFrHBEh9JtJLCCteCJgf
KLING_SECRET_KEY=pJent9rFbmCHGDYndk3dmMyG4PHyagL8
```

## 完全なワークフロー例

```javascript
// 1. 画像生成
const imageGenerator = new OpenAIImageGenerator();
const imageResult = await imageGenerator.generateImage("美しい山と湖の風景");
const imageFilename = imageGenerator.saveBase64Image(imageResult.data[0].b64_json);

// 2. 動画生成（実際の画像URLが必要）
const videoGenerator = new KlingVideoGenerator();
const videoResult = await videoGenerator.processImageToVideo(
    'https://example.com/uploaded-image.jpg',
    'カメラがゆっくりと風景をパンする',
    5
);

console.log('Video URL:', videoResult.videoUrl);
```

## 動作確認済み
- ✅ OpenAI画像生成: 正常動作
- ✅ KLING JWT認証: 正常動作  
- ✅ KLING動画生成リクエスト: 正常動作
- ✅ KLING タスク状態確認: 正常動作
- ✅ 完全ワークフロー: 成功（Base64形式で画像を送信）

## 一気通貫テスト結果（2025-06-17）

### 成功した実装:
1. **OpenAI画像生成**: 
   - プロンプト: "A serene mountain landscape with a crystal clear lake reflecting the snow-capped peaks"
   - 生成画像: 1024x1024 PNG (1.67MB)
   - APIレスポンス形式: URL形式（b64_jsonではない）

2. **KLING動画生成**:
   - 画像形式: **Base64文字列**（data:URLプレフィックスなし）
   - タスクID: 763617337500106789
   - 処理時間: 1-5分
   - 動画長: 5秒

### 重要な発見:
- KLINGは画像URLではなく、**純粋なBase64文字列**を要求
- OpenAI APIは`response_format`パラメータを受け付けない
- KLINGのタスク処理は非同期で、完了まで定期的なポーリングが必要

### 実証済みワークフロー:
```javascript
// 1. OpenAIで画像生成
const imageGenerator = new OpenAIImageGenerator();
const imageResult = await imageGenerator.generateImage("美しい風景");
const imagePath = await imageGenerator.saveImageFromUrl(imageResult.data[0].url);

// 2. 画像をBase64に変換
const imageBuffer = fs.readFileSync(imagePath);
const base64Image = imageBuffer.toString('base64'); // 純粋なBase64文字列

// 3. KLINGで動画生成
const videoGenerator = new KlingVideoGenerator();
const videoResult = await videoGenerator.generateVideo(base64Image, "カメラパン", '5');

// 4. 完了待機
const videoUrl = await videoGenerator.waitForCompletion(videoResult.data.task_id);
```

## フロントエンド実装 (2025-06-17)

### デプロイ情報
- **Vercel URL**: https://image-to-video-frontend-hm4grbfqi-senjinshujis-projects.vercel.app
- **GitHub**: https://github.com/senjinshuji/image-to-video-frontend
- **技術スタック**: Next.js 14, TypeScript, Tailwind CSS, SWR

### 実装完了機能
1. ✅ ダッシュボード画面 (PG-01) - Google Sheets行データ一覧
2. ✅ 画像生成画面 (PG-02) - プロンプト入力と画像生成
3. ✅ 動画生成画面 (PG-03) - VeoとKling並列生成
4. ✅ 完了確認画面 (PG-04) - 動画保存と完了処理
5. ✅ レスポンシブデザイン対応
6. ✅ エラーハンドリングとToast通知
7. ✅ CI/CD (GitHub Actions → Vercel)

### 環境変数設定
Vercelダッシュボードで設定が必要:
- `NEXT_PUBLIC_API_URL`: バックエンドAPIのURL（Renderでデプロイ予定）

### 次のステップ
1. バックエンドAPIの実装（Render）
2. 環境変数の設定
3. Google Sheets連携の実装

---
*最終更新: 2025-06-17 11:05*: フロントエンドVercelデプロイ完了

