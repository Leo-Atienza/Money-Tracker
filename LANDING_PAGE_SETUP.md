# Landing Page Setup Guide

Your Lovable landing page has been integrated with Firebase Hosting!

## What Changed

1. ✅ **Landing page copied** to `landing/` folder
2. ✅ **Firebase config updated** to serve landing page instead of Flutter web
3. ✅ **Meta tags updated** with Money Tracker branding
4. ✅ **Downloads folder created** at `landing/downloads/`

## Next Steps

### 1. Build Your Android APK

To create the APK file users will download:

```bash
cd C:\Users\leooa\develop\budget_tracker
flutter build apk --release
```

This creates: `build/app/outputs/flutter-apk/app-release.apk`

### 2. Copy APK to Landing Page

```bash
copy build\app\outputs\flutter-apk\app-release.apk landing\downloads\money-tracker.apk
```

### 3. Update Landing Page Content

Since the Lovable landing page is a compiled React app, you have two options:

#### Option A: Edit in Lovable (Recommended)

1. Go back to Lovable where you created the landing page
2. Add a download button with this link: `/downloads/money-tracker.apk`
3. Example button code in React:
   ```jsx
   <a href="/downloads/money-tracker.apk" download>
     <button>Download for Android</button>
   </a>
   ```
4. Rebuild the project in Lovable
5. Copy the new `dist` folder contents to `landing/`

#### Option B: Add Download Link Manually

Create a simple download page at `landing/download.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Download Money Tracker</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .container {
            text-align: center;
            background: white;
            padding: 3rem;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 400px;
        }
        h1 {
            color: #333;
            margin-bottom: 1rem;
        }
        p {
            color: #666;
            margin-bottom: 2rem;
        }
        .download-btn {
            display: inline-block;
            padding: 15px 40px;
            background: #667eea;
            color: white;
            text-decoration: none;
            border-radius: 50px;
            font-weight: bold;
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .download-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.4);
        }
        .info {
            margin-top: 2rem;
            font-size: 0.9rem;
            color: #999;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 Money Tracker</h1>
        <p>Track your expenses, manage budgets, and take control of your finances</p>
        <a href="/downloads/money-tracker.apk" download class="download-btn">
            Download for Android
        </a>
        <p class="info">
            Version 1.0<br>
            File size: ~20MB<br>
            Android 5.0+
        </p>
    </div>
</body>
</html>
```

Then users can visit: `https://money-tracker-app-e7f37.web.app/download.html`

### 4. Deploy to Firebase

```bash
firebase deploy --only hosting
```

## File Structure

```
budget_tracker/
├── landing/                    # Landing page (what users see)
│   ├── index.html             # Main page
│   ├── assets/                # React app files
│   ├── downloads/             # APK files
│   │   └── money-tracker.apk  # Your Android app
│   ├── favicon.ico
│   └── placeholder.svg
├── build/web/                 # Flutter web (not used anymore)
└── firebase.json              # Updated to serve landing/
```

## URLs After Deployment

- **Main site**: https://money-tracker-app-e7f37.web.app
- **Download page** (if you add it): https://money-tracker-app-e7f37.web.app/download.html
- **Direct APK link**: https://money-tracker-app-e7f37.web.app/downloads/money-tracker.apk

## Customizing Your Landing Page

### Method 1: Edit Source in Lovable

1. Go to your Lovable project
2. Make changes to the landing page
3. Build the project
4. Copy new `dist/` contents to `landing/`
5. Deploy: `firebase deploy --only hosting`

### Method 2: Edit the React Source (Advanced)

If you have the source code (not just the `dist` folder):

1. Navigate to your Lovable project source
2. Edit the React components
3. Build: `npm run build`
4. Copy `dist/` to `landing/`
5. Deploy

## Adding More Download Options

Create additional download links in your landing page:

```html
<!-- iOS (when available) -->
<a href="https://apps.apple.com/your-app">Download for iOS</a>

<!-- Google Play (when available) -->
<a href="https://play.google.com/store/apps/details?id=your.package">Get it on Google Play</a>

<!-- Direct APK -->
<a href="/downloads/money-tracker.apk" download>Download APK</a>
```

## Important Notes

### For Android Users

When users download the APK, they'll need to:
1. Allow installation from unknown sources
2. Download the APK file
3. Open it and tap "Install"

Add this info to your landing page!

### Updating Your App

When you release a new version:

1. Build new APK: `flutter build apk --release`
2. Copy to landing: `copy build\app\outputs\flutter-apk\app-release.apk landing\downloads\money-tracker.apk`
3. Update version number on landing page
4. Deploy: `firebase deploy --only hosting`

### File Size Optimization

To reduce APK size:

```bash
# Build with --split-per-abi flag
flutter build apk --release --split-per-abi
```

This creates separate APKs for different architectures (smaller file sizes).

## Testing Locally

Before deploying, test locally:

```bash
# Serve landing page locally
firebase serve --only hosting
```

Visit: http://localhost:5000

## Troubleshooting

### Issue: APK download doesn't work

Make sure:
- APK file is in `landing/downloads/`
- File permissions are correct
- Firebase hosting deployed successfully

### Issue: Landing page shows old content

- Clear browser cache (Ctrl+Shift+R)
- Check that you copied the latest `dist/` files
- Verify `firebase.json` points to `landing/` not `build/web`

### Issue: Download link not working

Add this to your Firebase hosting config:

```json
"headers": [{
  "source": "**/*.apk",
  "headers": [{
    "key": "Content-Type",
    "value": "application/vnd.android.package-archive"
  }]
}]
```

## Next Steps

1. ✅ Build your APK
2. ✅ Add it to `landing/downloads/`
3. ✅ Update landing page with download button
4. ✅ Deploy to Firebase
5. ✅ Test on your phone
6. ✅ Share with users!

---

**Your landing page is ready! Users will now see a professional website instead of a buggy web app.** 🎉
