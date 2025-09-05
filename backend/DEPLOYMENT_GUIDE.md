# 🚀 Deploy Seafrika Backend to Google Cloud Functions

## Prerequisites Setup

### 1. Install Google Cloud CLI

**Option A: Download and Install**
1. Go to https://cloud.google.com/sdk/docs/install-windows
2. Download the Google Cloud CLI installer
3. Run the installer and follow the setup wizard
4. Restart your terminal/PowerShell

**Option B: Using PowerShell (Alternative)**
```powershell
# Download and install Google Cloud SDK
Invoke-WebRequest -Uri "https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe" -OutFile "GoogleCloudSDKInstaller.exe"
.\GoogleCloudSDKInstaller.exe
```

### 2. Authenticate with Google Cloud

```bash
# Login to your Google account
gcloud auth login

# Set your project ID (use your Firebase project)
gcloud config set project sme-afrika

# Enable required APIs
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable firebase.googleapis.com
```

## 🔧 Deployment Steps

### Step 1: Build the Project
```bash
cd backend
npm run build
```

### Step 2: Set Environment Variables for Production

Create production environment variables in Google Cloud:

```bash
# Set Firebase configuration
gcloud functions deploy seafrikaApi --set-env-vars FIREBASE_PROJECT_ID=sme-afrika,FIREBASE_PROJECT_NUMBER=229268356345,FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@sme-afrika.iam.gserviceaccount.com,FIREBASE_STORAGE_BUCKET=sme-afrika.firebasestorage.app

# Set Instagram/Facebook configuration  
gcloud functions deploy seafrikaApi --set-env-vars INSTAGRAM_APP_ID=779189224487576,INSTAGRAM_VERIFY_TOKEN=IGWebhookVerifyToken_f4c9d7b82e6a47cbb913e2e50dca5a91-verify-token,FACEBOOK_APP_ID=744815985034707

# Set other configuration
gcloud functions deploy seafrikaApi --set-env-vars NODE_ENV=production,PORT=8080,API_PREFIX=api
```

**Important**: For the private key, you'll need to set it separately:
```bash
gcloud functions deploy seafrikaApi --set-env-vars FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC3j6Vdc0DJtmjH
2Fl9O03aaJMZTzbxBXYO0m+GpjyM3xl46/ykmFv0dTHExenpes+vLwG61vKnWEJW
MvIXqGXvOMhbghBEPaQDepbIqKb32hnezk41oKYc343f6WKAhsryMuXHU2D9ZKMF
xFNilWmp7SECuzZ4I+uxSIdFL6rsIrGD8wz9gzaXhLhg/Oq4BPxpSHfrxUgR6ydH
V+QEHAQTB2fICjh+R7gxV06EUJzNUzNpwkbqUvAeJKhvUxSvIzns+22oLmp7keez
KfcUDXiEsJNQLhinrGbIZo3OM/PDkQHYMkD76WwxPrxmWH+Jx98wfdPneuuPU+Xj
yOawj1ZXAgMBAAECggEAVecljlw3f66bzpqTFqZAQuwZmwiVP6o8m6cjhjIZuBtY
Qly9+RFMR1TpG5s7YoaU1vj6qEObf3EwakKhRS0Lty4tpZVyo1zteqtOEU3MBcXN
wZVuyG4MDwsXzCfebyOlqj7jhaqhgzQrjrFYDJS7xEgy4KJYVVUKIgc9NsWeCa9P
f3rYdXnxsiOzS/gmZyk7aA4Mk5+9jArvanu3ZJTAfx4uVFx9c7gmSPSlPtQLyO8i
prc+LqTAsz2wGPHx76oGqEkGx0PRI1aY4BeTYZJ34H96fttEBC3ezFVXGKyT/hEL
xVEqe6RpTVNyaiec22MepV5jBEPWsjOSys9z9zHDEQKBgQDl/NvKIZPRehDTihem
DuhjSj6o27xiY5BtQLm8FlOhWe1RElB8OcJ+O2IERi76hIwimN+/Q+9wtiXhhXKg
MvV1yhixnJfZOcKR0lEdMmTdUUh/D3wZvcmCFrnIHW8hUkwTSLV0sDLQTOPu5IdC
cJBVE3Iwr3uTsCKbAqYj8sCJgwKBgQDMUokp6nSV1/peEqW+u0+gX1BrItRRirE9
GBHyCeTbOGMDEslt3yReZOoR8FPLNZr7EKxEdU0MyVEqp2sSwzpiTssJgJLXYNRK
sAwWwRtdQjPiyTx2vyJjdyDh8/sfHKO4iUUCRuGe/89PrBpECOhCnBOyjhBQF5lJ
bIK13XYrnQKBgCkOGWIc2llTk/tfNFeFY8CNuV/FUfyyT07hdgZ4addsyStmvI1g
djK4gQfIS4yW6rkmVxK6mtyg92QpwUuNrTmoqP3TuVuirvP++lHe9Bh58RoVdo7V
zUn2qpVpg7QMD96FZTb+WSPMBghYLTkUBP/a59B/Eu1LTPIk5+mU5P/nAoGBAIfM
m4mWYKJvB+KadjrMd+HZN7PdVExV5/L5GoRJ+yeQ1I3oYKR72Mo8PC5sEuVO3ZDc
xgJCDFHhQ+cbmti/lQBd6iiIohAwNSjm1UISWsOjCqVCpsMtygdd2CcVZ+SHvnEa
GxmmTrLExt7nPhXV7bjHz3evYDw7UxAv5LhHVxEpAoGAYCcViZoMyAh3AY6DMuzF
6D7TCCG4C/InmdsxsEHq+mUP+/YDtpuuY5zr2ktVKOmJ3swCe7+SW9TxufJxHrsX
BfNRIqc5r5DazM23vBhBeXmZJV5ZO5o/0te0dyBy4jVm5wl2H/0cNx8xob6bbGhV
OIwrXToAyDynjfx6hOs7X9M=
-----END PRIVATE KEY-----"
```

### Step 3: Deploy to Google Cloud Functions

**Option A: Deploy Production Function**
```bash
npm run deploy
```

**Option B: Deploy Development Function**
```bash
npm run deploy:dev
```

**Option C: Manual Deploy with All Settings**
```bash
gcloud functions deploy seafrikaApi \
  --runtime=nodejs20 \
  --trigger-http \
  --allow-unauthenticated \
  --source=dist \
  --entry-point=seafrikaApi \
  --set-env-vars NODE_ENV=production,FIREBASE_PROJECT_ID=sme-afrika \
  --memory=1GB \
  --timeout=540s
```

## 🔗 Get Your Webhook URL

After deployment, you'll get a URL like:
```
https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi
```

### Instagram Webhook Endpoints

Your webhook URLs for Facebook Instagram will be:

**Webhook Callback URL:**
```
https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api/instagram/webhook
```

**Verify Token:** 
```
IGWebhookVerifyToken_f4c9d7b82e6a47cbb913e2e50dca5a91-verify-token
```

## 📱 Configure Facebook Instagram App

1. Go to [Facebook for Developers](https://developers.facebook.com/)
2. Select your Instagram app (ID: 779189224487576)
3. Go to **Instagram > Basic Display > Webhooks**
4. Add the webhook callback URL above
5. Enter the verify token above
6. Subscribe to the events you want to receive

## 🧪 Test Your Deployment

### Test API Health
```bash
curl https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api
```

### Test Instagram Webhook
```bash
curl -X GET "https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api/instagram/webhook?hub.mode=subscribe&hub.challenge=test123&hub.verify_token=IGWebhookVerifyToken_f4c9d7b82e6a47cbb913e2e50dca5a91-verify-token"
```

### Access Swagger Documentation
```
https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api/docs
```

## 🔍 Monitor and Debug

### View Function Logs
```bash
gcloud functions logs read seafrikaApi --limit=50
```

### View Function Details
```bash
gcloud functions describe seafrikaApi
```

### Update Environment Variables
```bash
gcloud functions deploy seafrikaApi --update-env-vars KEY=value
```

## 🚨 Important Security Notes

1. **Environment Variables**: Never commit secrets to your repository
2. **CORS Settings**: Update CORS origins for production domains
3. **API Keys**: Rotate Instagram/Facebook app secrets regularly
4. **Firebase Rules**: Set up proper Firestore security rules
5. **Function Permissions**: Review IAM permissions regularly

## 🔄 Updates and Redeployment

To update your function:
```bash
# Make your changes, then:
npm run build
npm run deploy
```

The function will be updated with zero downtime.

---

**Next Steps:** Once deployed, add the webhook URL to your Facebook Instagram app settings to start receiving webhook events!
