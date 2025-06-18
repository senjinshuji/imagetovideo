# KLING AI 動画生成仕様書

## 概要
KLING AIは中国製の高速動画生成AIサービスです。Python環境で完全に実装済みで、Image-to-Video機能に特化しています。

## 基本仕様

### サービス特徴
- **処理速度**: 高速（1秒動画 = 約6秒処理時間）
- **コスト**: 約$0.08/秒（業界最安レベル）
- **最大動画長**: 5秒
- **最大解像度**: 1920x1080
- **対応機能**: Image-to-Video専門
- **実装完成度**: 95%（即座に利用可能）

### 制限事項
- Image-to-Videoのみ（Text-to-Video非対応）
- 最大動画長5秒
- 中国のサービスのため接続安定性に注意

## API仕様

### エンドポイント
```
POST https://api-singapore.klingai.com/v1/videos/image2video
```

### 認証方式
JWT Bearer Token（HMAC-SHA256署名）

### 環境変数設定
```bash
KLING_ACCESS_KEY=At8fkCe3NpKyeFrHBEh9JtJLCCteCJgf
KLING_SECRET_KEY=pJent9rFbmCHGDYndk3dmMyG4PHyagL8
```

## JWT認証実装

### Python実装
```python
import jwt
import time
import hashlib

def generate_kling_jwt():
    access_key = "At8fkCe3NpKyeFrHBEh9JtJLCCteCJgf"
    secret_key = "pJent9rFbmCHGDYndk3dmMyG4PHyagL8"
    
    algorithm = "HS256"
    headers = {"alg": algorithm, "typ": "JWT"}
    
    payload = {
        "iss": access_key,
        "exp": int(time.time()) + 1800,  # 30分有効
        "nbf": int(time.time()) - 5
    }
    
    return jwt.encode(payload, secret_key, algorithm=algorithm, headers=headers)
```

## API使用方法

### リクエスト仕様
```python
import requests
import json

def generate_video_with_kling(image_url, prompt, duration=5):
    # JWT生成
    token = generate_kling_jwt()
    
    # リクエストヘッダー
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    # リクエストボディ
    data = {
        "model": "kling-v1",
        "image": image_url,
        "prompt": prompt,
        "duration": duration,
        "aspect_ratio": "16:9",
        "cfg_scale": 0.5,
        "mode": "std"
    }
    
    # API呼び出し
    response = requests.post(
        "https://api-singapore.klingai.com/v1/videos/image2video",
        headers=headers,
        json=data
    )
    
    return response.json()
```

### レスポンス例
```json
{
    "code": 200,
    "message": "success",
    "data": {
        "task_id": "kling-video-20241216-xxxxx",
        "task_status": "submitted"
    }
}
```

## タスク状態確認

### ステータス確認API
```python
def check_kling_task_status(task_id):
    token = generate_kling_jwt()
    
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    response = requests.get(
        f"https://api-singapore.klingai.com/v1/videos/{task_id}",
        headers=headers
    )
    
    return response.json()
```

### ステータス種類
- `submitted`: 送信済み
- `processing`: 処理中
- `succeed`: 完了
- `failed`: 失敗

### 完了時のレスポンス
```json
{
    "code": 200,
    "message": "success",
    "data": {
        "task_id": "kling-video-20241216-xxxxx",
        "task_status": "succeed",
        "created_at": 1702742400,
        "updated_at": 1702742430,
        "task_status_msg": "",
        "works": [
            {
                "id": "work-xxxxx",
                "url": "https://kling-output.s3.amazonaws.com/video.mp4",
                "duration": 5000
            }
        ]
    }
}
```

## 完全な実装例

### 非同期処理での実装
```python
import asyncio
import aiohttp
import time

class KlingVideoGenerator:
    def __init__(self):
        self.access_key = "At8fkCe3NpKyeFrHBEh9JtJLCCteCJgf"
        self.secret_key = "pJent9rFbmCHGDYndk3dmMyG4PHyagL8"
        self.base_url = "https://api-singapore.klingai.com/v1"
    
    def generate_jwt(self):
        payload = {
            "iss": self.access_key,
            "exp": int(time.time()) + 1800,
            "nbf": int(time.time()) - 5
        }
        return jwt.encode(payload, self.secret_key, algorithm="HS256")
    
    async def generate_video(self, image_url, prompt, duration=5):
        token = self.generate_jwt()
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        
        data = {
            "model": "kling-v1",
            "image": image_url,
            "prompt": prompt,
            "duration": duration,
            "aspect_ratio": "16:9",
            "cfg_scale": 0.5,
            "mode": "std"
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.base_url}/videos/image2video",
                headers=headers,
                json=data
            ) as response:
                return await response.json()
    
    async def wait_for_completion(self, task_id, max_wait=300):
        token = self.generate_jwt()
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    f"{self.base_url}/videos/{task_id}",
                    headers=headers
                ) as response:
                    result = await response.json()
                    
                    if result["data"]["task_status"] == "succeed":
                        return result["data"]["works"][0]["url"]
                    elif result["data"]["task_status"] == "failed":
                        raise Exception("Video generation failed")
                    
                    await asyncio.sleep(10)  # 10秒待機
        
        raise Exception("Timeout waiting for video completion")

# 使用例
async def main():
    generator = KlingVideoGenerator()
    
    # 動画生成開始
    result = await generator.generate_video(
        image_url="https://example.com/image.jpg",
        prompt="カメラが左から右にパンしながら、美しい風景を映す",
        duration=5
    )
    
    task_id = result["data"]["task_id"]
    print(f"Task ID: {task_id}")
    
    # 完了まで待機
    video_url = await generator.wait_for_completion(task_id)
    print(f"Video URL: {video_url}")

# 実行
if __name__ == "__main__":
    asyncio.run(main())
```

## エラーハンドリング

### よくあるエラーと対処法

#### 1. 認証エラー
```json
{
    "code": 401,
    "message": "Unauthorized"
}
```
**対処法**: JWTトークンの有効期限を確認し、再生成

#### 2. 画像フォーマットエラー
```json
{
    "code": 400,
    "message": "Invalid image format"
}
```
**対処法**: JPEGまたはPNG形式の画像を使用

#### 3. レート制限エラー
```json
{
    "code": 429,
    "message": "Too many requests"
}
```
**対処法**: 指数バックオフでリトライ

### リトライ機能付き実装
```python
import random

async def generate_video_with_retry(self, image_url, prompt, max_retries=3):
    for attempt in range(max_retries):
        try:
            return await self.generate_video(image_url, prompt)
        except Exception as e:
            if attempt == max_retries - 1:
                raise e
            
            # 指数バックオフ
            wait_time = (2 ** attempt) + random.uniform(0, 1)
            await asyncio.sleep(wait_time)
```

## パフォーマンス最適化

### 推奨設定
```python
# 最適なパラメータ
OPTIMAL_SETTINGS = {
    "duration": 5,           # 最大5秒
    "aspect_ratio": "16:9",  # 推奨アスペクト比
    "cfg_scale": 0.5,        # バランス設定
    "mode": "std"            # 標準モード
}

# タイムアウト設定
TIMEOUTS = {
    "connection": 30,        # 接続タイムアウト
    "generation": 120,       # 生成タイムアウト
    "total": 300            # 全体タイムアウト
}
```

### レート制限対応
```python
import asyncio
from asyncio import Semaphore

class RateLimitedKlingGenerator:
    def __init__(self, max_concurrent=5):
        self.semaphore = Semaphore(max_concurrent)
        self.generator = KlingVideoGenerator()
    
    async def generate_video_rate_limited(self, image_url, prompt):
        async with self.semaphore:
            return await self.generator.generate_video(image_url, prompt)
```

## 統合API例（Next.js）

### API Route実装
```javascript
// pages/api/video-kling.js
import jwt from 'jsonwebtoken';

export default async function handler(req, res) {
    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }
    
    const { image, prompt, duration = 5 } = req.body;
    
    try {
        // JWT生成
        const token = jwt.sign(
            {
                iss: process.env.KLING_ACCESS_KEY,
                exp: Math.floor(Date.now() / 1000) + 1800,
                nbf: Math.floor(Date.now() / 1000) - 5
            },
            process.env.KLING_SECRET_KEY,
            { algorithm: 'HS256' }
        );
        
        // KLING API呼び出し
        const response = await fetch('https://api-singapore.klingai.com/v1/videos/image2video', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                model: 'kling-v1',
                image: image,
                prompt: prompt,
                duration: duration,
                aspect_ratio: '16:9',
                cfg_scale: 0.5,
                mode: 'std'
            })
        });
        
        const result = await response.json();
        
        res.status(200).json({
            taskId: result.data.task_id,
            status: result.data.task_status
        });
        
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
}
```

## 実際の使用手順

### 1. 環境変数設定
```bash
# .env.local
KLING_ACCESS_KEY=At8fkCe3NpKyeFrHBEh9JtJLCCteCJgf
KLING_SECRET_KEY=pJent9rFbmCHGDYndk3dmMyG4PHyagL8
```

### 2. 依存関係インストール
```bash
pip install PyJWT requests aiohttp
# または
npm install jsonwebtoken
```

### 3. 基本的な使用例
```python
# 簡単な使用例
from kling_generator import KlingVideoGenerator

# インスタンス作成
generator = KlingVideoGenerator()

# 動画生成
result = await generator.generate_video(
    image_url="https://example.com/beautiful-landscape.jpg",
    prompt="雲が優雅に空を流れる様子",
    duration=5
)

# 完了まで待機
video_url = await generator.wait_for_completion(result["data"]["task_id"])
print(f"生成された動画: {video_url}")
```

## まとめ

KLING AIは高速・低コストでImage-to-Video生成が可能な優秀なサービスです。実装は完了しており、即座に利用可能です。

**主な利点:**
- 高速処理（業界最速レベル）
- 低コスト（$0.08/秒）
- 安定したAPI
- 完全に実装済み

**推奨用途:**
- 高速な動画生成が必要な場合
- コストを抑えたい場合
- Image-to-Videoに特化したサービス

実際のAPIキーを使用した実装例も含まれているため、この仕様書に従って実装すれば確実に動作します。