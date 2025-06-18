const https = require('https');

const RENDER_API_KEY = 'rnd_RhftZfycmN3DYPiKm79ifw40X902';

async function makeRequest(options, data) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
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
  console.log('🚀 Render Deployment\n');

  // 1. Get existing services
  const servicesRes = await makeRequest({
    hostname: 'api.render.com',
    path: '/v1/services?limit=100',
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${RENDER_API_KEY}`,
      'Accept': 'application/json'
    }
  });

  if (servicesRes.status === 200 && servicesRes.body.length > 0) {
    const existing = servicesRes.body.find(s => s.service && s.service.name === 'image-to-video-api');
    if (existing) {
      console.log('✅ Found existing service:', existing.service.name);
      console.log('🌐 URL: https://' + existing.service.name + '.onrender.com');
      console.log('📊 Status:', existing.service.suspended ? 'Suspended' : 'Active');
      
      // Trigger deploy
      console.log('\n🔄 Triggering new deployment...');
      const deployRes = await makeRequest({
        hostname: 'api.render.com',
        path: `/v1/services/${existing.service.id}/deploys`,
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${RENDER_API_KEY}`,
          'Accept': 'application/json'
        }
      }, {});

      if (deployRes.status === 201) {
        console.log('✅ Deployment triggered!');
        console.log('📊 Monitor: https://dashboard.render.com/web/' + existing.service.id);
      }
      return;
    }
  }

  // 2. Get owner
  const ownerRes = await makeRequest({
    hostname: 'api.render.com',
    path: '/v1/owners',
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${RENDER_API_KEY}`,
      'Accept': 'application/json'
    }
  });

  const ownerId = ownerRes.body[0].owner.id;
  console.log('👤 Owner:', ownerId);

  // 3. Create service with correct structure
  const serviceData = {
    type: 'web_service',
    name: 'image-to-video-api',
    ownerId: ownerId,
    repo: 'https://github.com/senjinshuji/image-to-video-backend',
    branch: 'master',
    autoDeploy: 'yes',
    serviceDetails: {
      env: 'python',
      region: 'oregon',
      plan: 'starter',
      buildCommand: 'pip install -r requirements.txt',
      startCommand: 'uvicorn app.main:app --host 0.0.0.0 --port $PORT',
      envSpecificDetails: {
        pythonVersion: '3.11'
      },
      // Environment variables
      envVars: [
        { key: 'APP_ENV', value: 'production' },
        { key: 'DEBUG', value: 'false' },
        { key: 'PYTHON_VERSION', value: '3.11.0' },
        { key: 'CORS_ORIGINS', value: '["https://image-to-video-frontend-mbj011s5m-senjinshujis-projects.vercel.app"]' },
        { key: 'OPENAI_API_KEY', value: 'YOUR_OPENAI_API_KEY' },
        { key: 'KLING_ACCESS_KEY', value: 'At8fkCe3NpKyeFrHBEh9JtJLCCteCJgf' },
        { key: 'KLING_SECRET_KEY', value: 'pJent9rFbmCHGDYndk3dmMyG4PHyagL8' },
        { key: 'JWT_SECRET_KEY', value: 'jwt-' + Date.now() }
      ]
    }
  };

  console.log('\n📦 Creating service...');
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

  console.log('Response:', createRes.status);
  console.log('Body:', JSON.stringify(createRes.body, null, 2));

  if (createRes.status === 201) {
    console.log('\n✅ Success!');
    console.log('🌐 URL: https://image-to-video-api.onrender.com');
    console.log('\n📝 Update Vercel:');
    console.log('NEXT_PUBLIC_API_URL=https://image-to-video-api.onrender.com/api/v1');
  }
}

deploy().catch(console.error);