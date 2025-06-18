#!/usr/bin/env node

const https = require('https');
const { execSync } = require('child_process');

// Configuration
const RENDER_API_KEY = process.env.RENDER_API_KEY;
const GITHUB_REPO = 'https://github.com/senjinshuji/image-to-video-backend';

// Environment variables for the service
const ENV_VARS = {
  APP_ENV: 'production',
  DEBUG: 'false',
  PYTHON_VERSION: '3.11.0',
  CORS_ORIGINS: '["https://image-to-video-frontend-mbj011s5m-senjinshujis-projects.vercel.app"]',
  OPENAI_API_KEY: process.env.OPENAI_API_KEY || 'YOUR_OPENAI_API_KEY',
  KLING_ACCESS_KEY: process.env.KLING_ACCESS_KEY || 'At8fkCe3NpKyeFrHBEh9JtJLCCteCJgf',
  KLING_SECRET_KEY: process.env.KLING_SECRET_KEY || 'pJent9rFbmCHGDYndk3dmMyG4PHyagL8',
};

async function makeRequest(options, data) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(body) });
        } catch (e) {
          resolve({ status: res.statusCode, body });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(JSON.stringify(data));
    req.end();
  });
}

async function getRenderAPIKey() {
  if (RENDER_API_KEY) return RENDER_API_KEY;

  console.log('\n🔑 Render API Key not found in environment.');
  console.log('\nTo get your API key:');
  console.log('1. Go to: https://dashboard.render.com/account/api-keys');
  console.log('2. Create a new API key');
  console.log('3. Set it as environment variable:');
  console.log('   export RENDER_API_KEY="your-api-key"\n');
  
  process.exit(1);
}

async function getOwnerInfo(apiKey) {
  const options = {
    hostname: 'api.render.com',
    path: '/v1/owners',
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Accept': 'application/json'
    }
  };

  const response = await makeRequest(options);
  if (response.status !== 200) {
    throw new Error('Failed to get owner info');
  }
  return response.body[0]; // Return first owner
}

async function checkExistingService(apiKey) {
  console.log('🔍 Checking for existing service...');
  
  const options = {
    hostname: 'api.render.com',
    path: '/v1/services?type=web_service&limit=100',
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Accept': 'application/json'
    }
  };

  const response = await makeRequest(options);
  if (response.status !== 200) {
    console.error('Failed to fetch services:', response.body);
    return null;
  }

  const services = response.body;
  return services.find(s => s.service.name === 'image-to-video-api');
}

async function createService(apiKey, ownerId) {
  console.log('🚀 Creating new service...');
  
  const serviceData = {
    type: 'web_service',
    name: 'image-to-video-api',
    ownerId: ownerId,
    autoDeploy: 'yes',
    repo: GITHUB_REPO,
    branch: 'master',
    buildCommand: 'pip install -r requirements.txt',
    startCommand: 'uvicorn app.main:app --host 0.0.0.0 --port $PORT',
    serviceDetails: {
      env: 'python',
      envSpecificDetails: {
        pythonVersion: '3.11.0'
      }
    },
    envVars: Object.entries(ENV_VARS).map(([key, value]) => ({ key, value }))
  };

  const options = {
    hostname: 'api.render.com',
    path: '/v1/services',
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    }
  };

  const response = await makeRequest(options, serviceData);
  return response;
}

async function triggerDeploy(apiKey, serviceId) {
  console.log('🔄 Triggering deployment...');
  
  const options = {
    hostname: 'api.render.com',
    path: `/v1/services/${serviceId}/deploys`,
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Accept': 'application/json'
    }
  };

  const response = await makeRequest(options, {});
  return response;
}

async function main() {
  console.log('🚀 Render Backend Deployment Tool\n');

  try {
    const apiKey = await getRenderAPIKey();
    
    // Get owner info first
    const owner = await getOwnerInfo(apiKey);
    console.log(`👤 Owner: ${owner.owner.name} (${owner.owner.id})`);
    
    // Check if service already exists
    const existingService = await checkExistingService(apiKey);
    
    if (existingService) {
      console.log(`✅ Found existing service: ${existingService.service.name}`);
      console.log(`🌐 URL: https://${existingService.service.name}.onrender.com`);
      
      const answer = process.argv.includes('--force') ? 'y' : 
        await new Promise(resolve => {
          process.stdout.write('\nTrigger new deployment? (y/n): ');
          process.stdin.once('data', data => resolve(data.toString().trim()));
        });

      if (answer.toLowerCase() === 'y') {
        const deployResponse = await triggerDeploy(apiKey, existingService.service.id);
        if (deployResponse.status === 201) {
          console.log('✅ Deployment triggered successfully!');
          console.log(`📊 Monitor at: https://dashboard.render.com/web/${existingService.service.id}`);
        } else {
          console.error('❌ Failed to trigger deployment:', deployResponse.body);
        }
      }
    } else {
      console.log('📦 Creating new service...');
      const createResponse = await createService(apiKey, owner.owner.id);
      
      if (createResponse.status === 201) {
        console.log('✅ Service created successfully!');
        console.log(`🌐 URL: https://image-to-video-api.onrender.com`);
        console.log(`📊 Monitor at: https://dashboard.render.com/web/${createResponse.body.service.id}`);
        console.log('\n⏳ Initial deployment may take 10-15 minutes...');
      } else {
        console.error('❌ Failed to create service:', createResponse.body);
      }
    }

    // Update frontend environment
    console.log('\n📝 Next steps:');
    console.log('1. Wait for deployment to complete');
    console.log('2. Update Vercel environment variable:');
    console.log('   NEXT_PUBLIC_API_URL=https://image-to-video-api.onrender.com/api/v1');
    console.log('3. Redeploy frontend on Vercel');

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { main };