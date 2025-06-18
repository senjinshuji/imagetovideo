# Image to Video - Deployment Guide

## Backend Deployment to Render

1. **Go to Render Dashboard**
   - Navigate to https://dashboard.render.com
   - Click "New +" → "Web Service"

2. **Connect GitHub Repository**
   - Connect to: https://github.com/senjinshuji/image-to-video-backend
   - Select the `image-to-video-backend` repository

3. **Configure Service**
   - **Name**: image-to-video-api
   - **Environment**: Python 3
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

4. **Environment Variables**
   Add the following environment variables:
   ```
   APP_ENV=production
   DEBUG=False
   CORS_ORIGINS=["https://image-to-video-frontend-mbj011s5m-senjinshujis-projects.vercel.app", "https://your-production-domain.com"]
   
   # Secrets (Add these as "Secret" type):
   OPENAI_API_KEY=YOUR_OPENAI_API_KEY
   KLING_ACCESS_KEY=At8fkCe3NpKyeFrHBEh9JtJLCCteCJgf
   KLING_SECRET_KEY=pJent9rFbmCHGDYndk3dmMyG4PHyagL8
   JWT_SECRET_KEY=your-secure-jwt-secret-key-here
   ```

5. **Database**
   - Render will automatically create a PostgreSQL database
   - The DATABASE_URL will be automatically set

6. **Deploy**
   - Click "Create Web Service"
   - Wait for the build and deploy to complete

## Frontend Environment Update

Once the backend is deployed:

1. **Get the Backend URL**
   - It will be something like: `https://image-to-video-api.onrender.com`

2. **Update Vercel Environment Variables**
   - Go to your Vercel project dashboard
   - Settings → Environment Variables
   - Update `NEXT_PUBLIC_API_URL` to: `https://image-to-video-api.onrender.com/api/v1`

3. **Redeploy Frontend**
   - Trigger a new deployment in Vercel
   - Or push any commit to trigger auto-deployment

## Post-Deployment Checklist

- [ ] Backend is running on Render
- [ ] Database migrations completed
- [ ] Frontend NEXT_PUBLIC_API_URL updated
- [ ] CORS origins include your production frontend URL
- [ ] Test image generation flow
- [ ] Test video generation flow
- [ ] Monitor logs for any errors

## Monitoring

- **Backend Logs**: Check Render dashboard → Logs
- **Frontend Logs**: Check Vercel dashboard → Functions
- **Database**: Monitor through Render dashboard → Database tab