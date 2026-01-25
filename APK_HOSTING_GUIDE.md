# APK Hosting Guide

Since Firebase Hosting's free tier doesn't allow APK files, here are the best alternatives:

## ✅ Option 1: GitHub Releases (Recommended)

**Why?** Free, reliable, unlimited bandwidth, designed for distributing app releases.

### Setup Steps:

1. **Push your code to GitHub** (if not already):
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/YOUR_USERNAME/budget-tracker.git
   git push -u origin main
   ```

2. **Create a Release on GitHub**:
   - Go to your GitHub repository
   - Click "Releases" → "Create a new release"
   - Tag version: `v1.0.0`
   - Release title: `Money Tracker v1.0.0`
   - Description: Add release notes
   - **Attach your APK**: Drag and drop `build/app/outputs/flutter-apk/app-release.apk`
   - Click "Publish release"

3. **Get the Download URL**:
   After publishing, right-click on the APK file → "Copy link address"

   It will look like:
   ```
   https://github.com/YOUR_USERNAME/budget-tracker/releases/download/v1.0.0/app-release.apk
   ```

4. **Update Your Landing Page**:
   In Lovable, update the download button href to this GitHub URL:
   ```jsx
   <a href="https://github.com/YOUR_USERNAME/budget-tracker/releases/download/v1.0.0/app-release.apk">
     Download for Android
   </a>
   ```

5. **Rebuild and Deploy**:
   ```bash
   # In Lovable project, rebuild
   # Then copy new dist to landing/
   cp -r path/to/lovable/dist/* landing/

   # Deploy to Firebase
   firebase deploy --only hosting
   ```

---

## ✅ Option 2: Google Drive

**Why?** Simple, no coding required.

### Setup Steps:

1. **Upload APK to Google Drive**
2. **Right-click → Share → Get link**
3. **Change to "Anyone with the link"**
4. **Copy the link**
5. **Update download button** in your landing page

**Note**: Google Drive links expire and have download limits. Not ideal for public apps.

---

## ✅ Option 3: Cloudflare R2 (Free Tier)

**Why?** 10GB free storage, unlimited requests.

### Setup Steps:

1. **Sign up**: https://cloudflare.com
2. **Create R2 bucket**: Dashboard → R2 → Create bucket
3. **Upload APK**
4. **Make it public**: Settings → Public access → Enable
5. **Get URL**: Copy the public URL
6. **Update landing page** with this URL

---

## ✅ Option 4: Firebase Storage (Paid Plan)

If you upgrade to Firebase Blaze plan (pay-as-you-go):

### Setup Steps:

1. **Upgrade to Blaze**: Firebase Console → Upgrade
2. **Enable Storage**: Build → Storage → Get started
3. **Upload APK**:
   ```bash
   firebase storage:upload build/app/outputs/flutter-apk/app-release.apk /downloads/money-tracker.apk
   ```
4. **Make public** and get download URL
5. **Update landing page**

**Note**: You'll pay for bandwidth, but first 5GB/month is free.

---

## 🎯 Recommended Solution: GitHub Releases

For most cases, **GitHub Releases is the best choice** because:

✅ **Free** with unlimited bandwidth
✅ **Reliable** and fast CDN
✅ **Version control** - track all your releases
✅ **Professional** - users expect apps on GitHub
✅ **Easy updates** - just create new releases

## Quick GitHub Release Setup

```bash
# 1. Build your APK
flutter build apk --release

# 2. Rename it (optional)
cd build/app/outputs/flutter-apk
mv app-release.apk money-tracker-v1.0.0.apk

# 3. Create GitHub release via CLI (optional)
gh release create v1.0.0 money-tracker-v1.0.0.apk --title "Money Tracker v1.0.0" --notes "Initial release"

# Or do it manually on GitHub.com
```

## Updating Your Landing Page

Once you have the APK URL (from GitHub or elsewhere), update your Lovable landing page:

```jsx
// Find the download button component and update href
<a
  href="https://github.com/YOUR_USERNAME/budget-tracker/releases/download/v1.0.0/money-tracker.apk"
  download
  className="download-button"
>
  Download for Android
</a>
```

Then rebuild in Lovable and copy to `landing/` folder.

---

## Current Status

✅ Landing page ready (without APK)
✅ Firebase configured correctly
⏳ Waiting for APK hosting URL
⏳ Update landing page with download link
⏳ Deploy to Firebase

## Next Steps

1. Choose your hosting option (GitHub recommended)
2. Upload your APK and get the download URL
3. Update the download button in Lovable with the URL
4. Copy updated landing page to `landing/`
5. Deploy: `firebase deploy --only hosting`

---

**Your landing page will work perfectly once you add the external APK URL!** 🚀
