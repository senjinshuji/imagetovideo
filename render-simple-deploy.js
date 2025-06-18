const https = require('https');

const RENDER_API_KEY = 'rnd_RhftZfycmN3DYPiKm79ifw40X902';

async function makeRequest(options, data) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        console.log(`Response ${options.path}:`, res.statusCode);
        console.log('Body:', body);
        try {
          resolve({ status: res.statusCode, body: JSON.parse(body) });
        } catch {
          resolve({ status: res.statusCode, body });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

async function deploy() {
  // 1. Get owner
  const ownerRes = await makeRequest({
    hostname: 'api.render.com',
    path: '/v1/owners',
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${RENDER_API_KEY}`,
      'Accept': 'application/json'
    }
  });

  if (ownerRes.status !== 200) {
    throw new Error('Failed to get owner');
  }

  const ownerId = ownerRes.body[0].owner.id;
  console.log('\n✅ Got owner ID:', ownerId);

  // 2. Create service - シンプルな構造で
  const serviceData = {
    type: 'web_service',
    name: 'image-to-video-api',
    ownerId: ownerId,
    autoDeploy: 'yes',
    // Git
    repo: 'https://github.com/senjinshuji/image-to-video-backend',
    branch: 'master',
    // Build & Start
    buildCommand: 'pip install -r requirements.txt',
    startCommand: 'uvicorn app.main:app --host 0.0.0.0 --port $PORT',
    // Runtime
    env: 'python',
    pythonVersion: '3.11',
    // Environment Variables
    envVars: [
      { key: 'APP_ENV', value: 'production' },
      { key: 'DEBUG', value: 'false' },
      { key: 'CORS_ORIGINS', value: '["https://image-to-video-frontend-mbj011s5m-senjinshujis-projects.vercel.app"]' },
      { key: 'OPENAI_API_KEY', value: 'YOUR_OPENAI_API_KEY' },
      { key: 'KLING_ACCESS_KEY', value: 'At8fkCe3NpKyeFrHBEh9JtJLCCteCJgf' },
      { key: 'KLING_SECRET_KEY', value: 'pJent9rFbmCHGDYndk3dmMyG4PHyagL8' },
      { key: 'JWT_SECRET_KEY', value: 'jwt-secret-' + Math.random().toString(36).substring(7) }
    ]
  };

  const createRes = await makeRequest({
    hostname: 'api.render.com',
    path: '/v1/services',
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RENDER_API_KEY}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    }
  }, serviceData);

  if (createRes.status === 201) {
    console.log('\n✅ Service created successfully!');
    console.log('🌐 URL: https://image-to-video-api.onrender.com');
    console.log('📊 Dashboard: https://dashboard.render.com');
    console.log('\n⏳ Deployment will take 10-15 minutes...');
    console.log('\n📝 Next: Update Vercel environment:');
    console.log('NEXT_PUBLIC_API_URL=https://image-to-video-api.onrender.com/api/v1');
  } else {
    console.error('\n❌ Failed to create service');
  }
}

deploy().catch(console.error);