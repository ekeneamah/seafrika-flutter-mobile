# 🚀 Deployment Solutions for Google Cloud SDK PATH Issue

## 🔍 **The Problem:**
- Google Cloud SDK is installed but `gcloud` command isn't found
- This happens when the installation doesn't update the system PATH

## ✅ **Quick Solutions:**

### **Solution 1: Use Firebase CLI (Recommended)**
```bash
cd "c:\Users\HP\source\repos\seafrika-flutter-mobile\backend"
npm run deploy
```

### **Solution 2: Fix gcloud PATH**
Run this PowerShell script:
```powershell
cd "c:\Users\HP\source\repos\seafrika-flutter-mobile\backend"
powershell -ExecutionPolicy Bypass -File "fix-gcloud-path.ps1"
```

### **Solution 3: Manual PATH Fix**
1. Open PowerShell as Administrator
2. Find Google Cloud SDK:
   ```powershell
   Get-ChildItem -Path "C:\" -Name "*google-cloud-sdk*" -Directory -Recurse -ErrorAction SilentlyContinue
   ```
3. Add to PATH (example):
   ```powershell
   $env:PATH = "C:\Users\HP\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin;$env:PATH"
   ```

### **Solution 4: Reinstall with PATH Update**
```bash
winget uninstall Google.CloudSDK
winget install Google.CloudSDK --include-unknown
```

## 🔧 **Updated package.json Scripts:**

I've updated your scripts to use Firebase CLI as the default:

```json
{
  "deploy": "npm run build && firebase deploy --only functions",
  "deploy:gcloud": "npm run build && gcloud functions deploy seafrikaApi --runtime=nodejs20 --trigger-http --allow-unauthenticated --source=dist --entry-point=seafrikaApi",
  "deploy:dev": "npm run build && firebase deploy --only functions"
}
```

## 🌐 **Expected Deployment URLs:**

### **Firebase Functions URL:**
```
https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi
```

### **Instagram Webhook URL:**
```
https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api/webhooks/instagram
```

### **API Documentation:**
```
https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api
```

## 🔑 **Firebase Authentication Check:**

Make sure you're logged into Firebase:
```bash
firebase login
firebase projects:list
```

You should see `sme-afrika` in the list.

## 🎯 **Deployment Steps:**

1. **Build and Deploy:**
   ```bash
   cd "c:\Users\HP\source\repos\seafrika-flutter-mobile\backend"
   npm run deploy
   ```

2. **Check Deployment:**
   ```bash
   firebase functions:list
   ```

3. **Test Your API:**
   Visit: `https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api`

## 🔧 **Troubleshooting:**

### **If Firebase CLI fails:**
```bash
npm install -g firebase-tools
firebase login
```

### **If build fails:**
```bash
npm run build
# Check for TypeScript errors
```

### **If deployment hangs:**
- Check your internet connection
- Verify Firebase project permissions
- Try `firebase logout` then `firebase login`

## 🎉 **Success Indicators:**

When deployment succeeds, you'll see:
```
✔ Deploy complete!

Project Console: https://console.firebase.google.com/project/sme-afrika/overview
Function URL (seafrikaApi): https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi
```

## 📱 **For Facebook Instagram App:**

Use this webhook URL in your Facebook Developer Console:
```
https://us-central1-sme-afrika.cloudfunctions.net/seafrikaApi/api/webhooks/instagram
```

## 🔐 **Environment Variables:**

Make sure to set these in Firebase Functions:
```bash
firebase functions:config:set firebase.project_id="sme-afrika"
firebase functions:config:set firebase.storage_bucket="sme-afrika.firebasestorage.app"
```

Or use Firebase environment config file.
