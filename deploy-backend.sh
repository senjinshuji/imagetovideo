#!/bin/bash

# Render CLI deployment script for image-to-video backend

echo "=== Render Backend Deployment Script ==="
echo ""

# Check if RENDER_API_KEY is set
if [ -z "$RENDER_API_KEY" ]; then
    echo "Error: RENDER_API_KEY environment variable is not set"
    echo ""
    echo "To get your Render API key:"
    echo "1. Go to https://dashboard.render.com/account/api-keys"
    echo "2. Create a new API key"
    echo "3. Export it: export RENDER_API_KEY='your-api-key'"
    echo ""
    exit 1
fi

# Backend directory
BACKEND_DIR="../image-to-video-backend"

echo "Deploying from: $BACKEND_DIR"
echo ""

# Option 1: Using render CLI with API key
echo "Option 1: Deploy using Render CLI"
echo "--------------------------------"
echo "1. First, login to Render:"
echo "   render login --api-key $RENDER_API_KEY"
echo ""
echo "2. Deploy the service:"
echo "   cd $BACKEND_DIR"
echo "   render up"
echo ""

# Option 2: Using curl with Render API
echo "Option 2: Deploy using Render API directly"
echo "-----------------------------------------"
echo "Creating deployment via API..."
echo ""

# Create service via API
create_service() {
    curl -X POST https://api.render.com/v1/services \
      -H "Authorization: Bearer $RENDER_API_KEY" \
      -H "Content-Type: application/json" \
      -d '{
        "type": "web_service",
        "name": "image-to-video-api",
        "repo": "https://github.com/senjinshuji/image-to-video-backend",
        "autoDeploy": "yes",
        "branch": "master",
        "buildCommand": "pip install -r requirements.txt",
        "startCommand": "uvicorn app.main:app --host 0.0.0.0 --port $PORT",
        "envVars": [
          {"key": "APP_ENV", "value": "production"},
          {"key": "DEBUG", "value": "false"},
          {"key": "PYTHON_VERSION", "value": "3.11.0"},
          {"key": "CORS_ORIGINS", "value": "[\"https://image-to-video-frontend-mbj011s5m-senjinshujis-projects.vercel.app\"]"},
          {"key": "OPENAI_API_KEY", "value": "'"$OPENAI_API_KEY"'"},
          {"key": "KLING_ACCESS_KEY", "value": "'"$KLING_ACCESS_KEY"'"},
          {"key": "KLING_SECRET_KEY", "value": "'"$KLING_SECRET_KEY"'"},
          {"key": "JWT_SECRET_KEY", "generateValue": true}
        ]
      }'
}

# Option 3: Using GitHub integration
echo "Option 3: One-click deploy with Blueprint"
echo "----------------------------------------"
echo "Open this URL in your browser:"
echo "https://render.com/deploy?repo=https://github.com/senjinshuji/image-to-video-backend"
echo ""

echo "Choose one of the above options to deploy."