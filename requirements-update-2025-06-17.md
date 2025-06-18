# 要件定義更新 - 動画生成独立化＆画像生成改善
更新日: 2025-06-17

## 1. 動画生成の独立実装

### 1.1 要件概要
- フロントエンドから直接KLING APIを呼び出して動画生成を可能にする
- バックエンドAPIの完成を待たずに動画生成機能を使用可能にする

### 1.2 実装方針
#### オプション1: サーバーレス関数（推奨）
- Vercel Edge FunctionsまたはAPI Routesを使用
- APIキーをサーバー側で安全に管理
- CORSの問題を回避

#### オプション2: プロキシサーバー
- 既存のバックエンドコード（kling-api.js）をNext.js API Routeに移植
- /api/generate-video エンドポイントを作成

### 1.3 API設計
```typescript
// POST /api/generate-video
interface GenerateVideoRequest {
  imageUrl: string;      // 画像URL（Base64またはHTTP URL）
  prompt: string;        // モーション説明
  duration?: number;     // 動画長（デフォルト: 5秒）
}

interface GenerateVideoResponse {
  taskId: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  videoUrl?: string;
  error?: string;
}

// GET /api/video-status/:taskId
interface VideoStatusResponse {
  taskId: string;
  status: 'pending' | 'processing' | 'completed' | 'failed';
  progress?: number;
  videoUrl?: string;
  error?: string;
}
```

## 2. 画像生成の改善 - O3によるYAML変換

### 2.1 要件概要
参考画像を使用する場合：
1. 画像をO3モデルで解析してYAML形式のプロンプトを生成
2. 生成されたYAMLプロンプトを表示
3. ユーザーが編集可能
4. 編集後のプロンプトで画像を再生成

### 2.2 YAMLプロンプト形式
```yaml
scene:
  description: "全体的なシーンの説明"
  mood: "雰囲気（例：serene, dramatic, cheerful）"
  time_of_day: "時間帯（例：golden_hour, night, dawn）"
  weather: "天候（例：clear, cloudy, rainy）"

subjects:
  - type: "主要な被写体のタイプ"
    description: "詳細な説明"
    position: "画面内の位置"
    attributes:
      - "特徴1"
      - "特徴2"

environment:
  setting: "環境設定（例：mountain, urban, forest）"
  foreground: "前景の要素"
  background: "背景の要素"
  lighting: "照明条件"

visual_style:
  art_style: "アートスタイル（例：photorealistic, anime, oil_painting）"
  color_palette: "色調（例：warm, cool, vibrant）"
  composition: "構図（例：rule_of_thirds, centered, diagonal）"

technical:
  camera_angle: "カメラアングル（例：eye_level, low_angle, aerial）"
  focal_length: "焦点距離効果（例：wide, normal, telephoto）"
  depth_of_field: "被写界深度（例：shallow, deep）"
```

### 2.3 UI/UXフロー

#### 2.3.1 画像アップロード時のフロー
1. ユーザーが参考画像をアップロード
2. ローディング表示「画像を解析中...」
3. O3 APIで画像を解析してYAML生成
4. YAMLエディタ画面を表示
5. ユーザーがYAMLを編集可能
6. 「この内容で生成」ボタンで画像生成実行

#### 2.3.2 YAMLエディタ画面
```
+--------------------------------------------------+
| 📸 参考画像の解析結果                              |
+--------------------------------------------------+
| [サムネイル画像]                                   |
|                                                  |
| 以下のYAML形式で画像の内容を解析しました。           |
| 必要に応じて編集してから生成してください。            |
|                                                  |
| +----------------------------------------------+ |
| | scene:                                       | |
| |   description: "山と湖の風景"                  | |
| |   mood: "serene"                            | |
| |   time_of_day: "golden_hour"                | |
| |   weather: "clear"                          | |
| |                                             | |
| | subjects:                                   | |
| |   - type: "mountain"                        | |
| |     description: "雪を頂いた山々"             | |
| |     position: "background center"           | |
| |     attributes:                             | |
| |       - "snow-capped peaks"                 | |
| |       - "rocky texture"                     | |
| |                                             | |
| | environment:                                 | |
| |   setting: "mountain lake"                  | |
| |   foreground: "calm water surface"          | |
| |   background: "mountain range"              | |
| |   lighting: "warm golden light"             | |
| |                                             | |
| | visual_style:                                | |
| |   art_style: "photorealistic"              | |
| |   color_palette: "warm"                     | |
| |   composition: "rule_of_thirds"             | |
| |                                             | |
| | technical:                                   | |
| |   camera_angle: "eye_level"                 | |
| |   focal_length: "wide"                      | |
| |   depth_of_field: "deep"                    | |
| +----------------------------------------------+ |
|                                                  |
| [YAMLをコピー] [リセット] [この内容で生成]          |
+--------------------------------------------------+
```

### 2.4 API設計

#### 2.4.1 画像解析API
```typescript
// POST /api/analyze-image
interface AnalyzeImageRequest {
  imageUrl: string;  // Base64またはURL
}

interface AnalyzeImageResponse {
  yaml: string;      // YAML形式のプロンプト
  preview: {         // プレビュー用の簡易情報
    description: string;
    mainSubjects: string[];
    mood: string;
  };
}
```

#### 2.4.2 YAML→プロンプト変換
```typescript
// POST /api/yaml-to-prompt
interface YamlToPromptRequest {
  yaml: string;
}

interface YamlToPromptResponse {
  prompt: string;    // 生成用の自然言語プロンプト
}
```

### 2.5 技術実装詳細

#### 2.5.1 O3 API呼び出し
```javascript
const analyzeImageWithO3 = async (imageUrl) => {
  const systemPrompt = `
    画像を解析して、以下のYAML形式で構造化された説明を生成してください。
    各フィールドは英語で記述し、値は具体的で詳細なものにしてください。
    
    [YAMLテンプレート]
    scene:
      description: 
      mood: 
      time_of_day: 
      weather: 
    
    subjects:
      - type: 
        description: 
        position: 
        attributes:
          - 
    
    environment:
      setting: 
      foreground: 
      background: 
      lighting: 
    
    visual_style:
      art_style: 
      color_palette: 
      composition: 
    
    technical:
      camera_angle: 
      focal_length: 
      depth_of_field: 
  `;
  
  // O3 APIコール
  const response = await openai.chat.completions.create({
    model: "o3-mini",
    messages: [
      { role: "system", content: systemPrompt },
      { 
        role: "user", 
        content: [
          { type: "text", text: "この画像を解析してYAML形式で説明してください。" },
          { type: "image_url", image_url: { url: imageUrl } }
        ]
      }
    ],
    temperature: 0.3,
    max_tokens: 1000
  });
  
  return response.choices[0].message.content;
};
```

#### 2.5.2 YAML編集コンポーネント
```typescript
interface YamlEditorProps {
  initialYaml: string;
  referenceImage?: string;
  onGenerate: (yaml: string) => void;
  onCancel: () => void;
}

const YamlEditor: React.FC<YamlEditorProps> = ({
  initialYaml,
  referenceImage,
  onGenerate,
  onCancel
}) => {
  const [yaml, setYaml] = useState(initialYaml);
  const [isValid, setIsValid] = useState(true);
  
  // YAML検証
  const validateYaml = (text: string) => {
    try {
      yaml.parse(text);
      setIsValid(true);
    } catch {
      setIsValid(false);
    }
  };
  
  // コンポーネント実装...
};
```

### 2.6 エラーハンドリング

1. **O3 API エラー**
   - タイムアウト（30秒）
   - レート制限
   - 画像サイズ制限（20MB）

2. **YAML検証エラー**
   - 構文エラーの即座表示
   - 必須フィールドの欠落警告

3. **フォールバック**
   - O3が利用不可の場合は通常のテキストプロンプト入力に切り替え

## 3. 実装優先順位

### Phase 1: 動画生成の独立実装（即実装）
1. Vercel API Routes作成
2. KLING API統合
3. フロントエンドからの呼び出し実装
4. 環境変数設定（KLING_ACCESS_KEY, KLING_SECRET_KEY）

### Phase 2: O3画像解析（次段階）
1. O3 API統合
2. YAMLエディタコンポーネント作成
3. 画像解析フロー実装
4. YAML→プロンプト変換ロジック

## 4. セキュリティ考慮事項

1. **APIキー管理**
   - すべてのAPIキーはサーバー側環境変数で管理
   - クライアントサイドには露出させない

2. **レート制限**
   - API Routesにレート制限を実装
   - ユーザーごとの使用回数制限

3. **入力検証**
   - 画像サイズ制限（20MB）
   - YAMLインジェクション対策
   - プロンプト長制限

## 5. 今後の拡張可能性

1. **プロンプトテンプレート**
   - よく使うYAMLテンプレートの保存
   - コミュニティ共有テンプレート

2. **バッチ処理**
   - 複数画像の一括解析
   - 複数バリエーションの同時生成

3. **学習機能**
   - ユーザーの編集パターンを学習
   - より精度の高いYAML生成