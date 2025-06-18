const https = require('https');

const RENDER_API_KEY = 'rnd_RhftZfycmN3DYPiKm79ifw40X902';

// 環境変数
const envVars = [
  { key: 'APP_ENV', value: 'production' },
  { key: 'DEBUG', value: 'false' },
  { key: 'PYTHON_VERSION', value: '3.11.0' },
  { key: 'CORS_ORIGINS', value: '["https://image-to-video-frontend-mbj011s5m-senjinshujis-projects.vercel.app"]' },
  { key: 'OPENAI_API_KEY', value: 'YOUR_OPENAI_API_KEY' },
  { key: 'KLING_ACCESS_KEY', value: 'At8fkCe3NpKyeFrHBEh9JtJLCCteCJgf' },
  { key: 'KLING_SECRET_KEY', value: 'pJent9rFbmCHGDYndk3dmMyG4PHyagL8' },
  { key: 'JWT_SECRET_KEY', value: 'your-secure-jwt-secret-' + Math.random().toString(36).substring(7) }
];

// Blueprintベースのデプロイ
const blueprintData = {
  services: [
    {
      type: 'web',
      name: 'image-to-video-api',
      runtime: 'python',
      repo: 'https://github.com/senjinshuji/image-to-video-backend',
      buildCommand: 'pip install -r requirements.txt',
      startCommand: 'uvicorn app.main:app --host 0.0.0.0 --port $PORT',
      envVars: envVars
    }
  ],
  databases: [
    {
      name: 'image-to-video-db',
      databaseName: 'image_to_video',
      plan: 'starter'
    }
  ]
};

async function createBlueprint() {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(blueprintData);
    
    const options = {
      hostname: 'api.render.com',
      port: 443,
      path: '/v1/blueprints',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RENDER_API_KEY}`,
        'Content-Type': 'application/json',
        'Content-Length': data.length
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        if (res.statusCode === 201) {
          resolve(JSON.parse(body));
        } else {
          reject(new Error(`Failed: ${res.statusCode} - ${body}`));
        }
      });
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

// Ownerを取得してサービスを作成
async function deployToRender() {
  // まずOwner情報を取得
  const ownerOptions = {
    hostname: 'api.render.com',
    port: 443,
    path: '/v1/owners',
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${RENDER_API_KEY}`,
      'Accept': 'application/json'
    }
  };

  const owners = await new Promise((resolve, reject) => {
    https.get(ownerOptions, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          resolve(JSON.parse(body));
        } else {
          reject(new Error(`Failed to get owners: ${body}`));
        }
      });
    }).on('error', reject);
  });

  const ownerId = owners[0].owner.id;
  console.log('Owner ID:', ownerId);

  // サービスデータ
  const serviceData = {
    autoDeploy: 'yes',
    branch: 'master',
    name: 'image-to-video-api',
    ownerId: ownerId,
    repo: 'https://github.com/senjinshuji/image-to-video-backend',
    type: 'web_service',
    serviceDetails: {
      buildCommand: 'pip install -r requirements.txt',
      startCommand: 'uvicorn app.main:app --host 0.0.0.0 --port $PORT',
      env: 'python',
      envSpecificDetails: {
        pythonVersion: '3.11'
      }
    },
    envVars: envVars
  };

  // サービスを作成
  const createOptions = {
    hostname: 'api.render.com',
    port: 443,
    path: '/v1/services',
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RENDER_API_KEY}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    }
  };

  const result = await new Promise((resolve, reject) => {
    const req = https.request(createOptions, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        console.log('Response status:', res.statusCode);
        console.log('Response body:', body);
        if (res.statusCode === 201) {
          resolve(JSON.parse(body));
        } else {
          reject(new Error(`Failed: ${res.statusCode} - ${body}`));
        }
      });
    });

    req.on('error', reject);
    req.write(JSON.stringify(serviceData));
    req.end();
  });

  return result;
}

// 実行
console.log('🚀 Deploying to Render...\n');
deployToRender()
  .then(result => {
    console.log('✅ Deployment successful!');
    console.log('Service ID:', result.service.id);
    console.log('URL:', `https://${result.service.name}.onrender.com`);
    console.log('\n📝 Next steps:');
    console.log('1. Wait for build to complete (10-15 minutes)');
    console.log('2. Update Vercel environment:');
    console.log('   NEXT_PUBLIC_API_URL=https://image-to-video-api.onrender.com/api/v1');
  })
  .catch(error => {
    console.error('❌ Deployment failed:', error.message);
  });