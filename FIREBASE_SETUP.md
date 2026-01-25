# Firebase Hosting Setup Guide

This guide will help you deploy your Budget Tracker app to Firebase Hosting so users can access and install it as a Progressive Web App (PWA).

## Prerequisites

- Node.js installed (https://nodejs.org/)
- Google account for Firebase Console

## Step 1: Install Firebase CLI

Open your terminal and run:

```bash
npm install -g firebase-tools
```

## Step 2: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" or "Create a project"
3. Enter project name: `budget-tracker` (or your preferred name)
4. Disable Google Analytics (optional, not needed for hosting)
5. Click "Create project"
6. Wait for the project to be created

## Step 3: Login to Firebase

In your terminal:

```bash
firebase login
```

This will open a browser window. Log in with your Google account.

## Step 4: Initialize Firebase in Your Project

Navigate to your project directory:

```bash
cd C:\Users\leooa\develop\budget_tracker
```

Run:

```bash
firebase init hosting
```

When prompted:
- **"Are you ready to proceed?"** → Yes
- **"What do you want to use as your public directory?"** → `build/web`
- **"Configure as a single-page app?"** → Yes
- **"Set up automatic builds and deploys with GitHub?"** → No (unless you want CI/CD)
- **"File build/web/index.html already exists. Overwrite?"** → No

## Step 5: Link Your Firebase Project

Edit the `.firebaserc` file and replace `your-project-id-here` with your actual Firebase project ID:

```json
{
  "projects": {
    "default": "budget-tracker"
  }
}
```

Or run:

```bash
firebase use --add
```

Then select your project from the list.

## Step 6: Build Your Flutter Web App

```bash
flutter build web --release
```

This creates optimized production files in `build/web/`.

## Step 7: Deploy to Firebase

```bash
firebase deploy --only hosting
```

Wait for deployment to complete. You'll see output like:

```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/budget-tracker/overview
Hosting URL: https://budget-tracker.web.app
```

## Step 8: Access Your App

Your app is now live at:
- `https://your-project-id.web.app`
- `https://your-project-id.firebaseapp.com`

## Installing as PWA

### On Desktop (Chrome/Edge):
1. Visit your hosted URL
2. Look for the install icon in the address bar (⊕ or computer icon)
3. Click "Install"

### On Mobile (Android):
1. Visit your hosted URL in Chrome
2. Tap the menu (⋮) → "Add to Home screen"
3. Tap "Add"

### On Mobile (iOS/Safari):
1. Visit your hosted URL in Safari
2. Tap the Share button
3. Scroll down and tap "Add to Home Screen"
4. Tap "Add"

## Updating Your App

When you make changes:

1. Build the updated web app:
   ```bash
   flutter build web --release
   ```

2. Deploy to Firebase:
   ```bash
   firebase deploy --only hosting
   ```

## Optional: Custom Domain

1. Go to Firebase Console → Hosting
2. Click "Add custom domain"
3. Follow the instructions to verify and connect your domain

## Tips

- **Test locally before deploying:**
  ```bash
  flutter run -d chrome
  ```

- **Preview deployment before going live:**
  ```bash
  firebase hosting:channel:deploy preview
  ```

- **View deployment history:**
  ```bash
  firebase hosting:clone
  ```

- **Set up environment variables:** Use `--dart-define` flags during build:
  ```bash
  flutter build web --release --dart-define=ENV=production
  ```

## PWA Features Included

✅ **Offline support** - Service worker caches assets
✅ **Installable** - Add to home screen on mobile/desktop
✅ **Standalone mode** - Runs like a native app
✅ **Responsive** - Works on all screen sizes
✅ **Fast loading** - Optimized assets and caching

## Troubleshooting

### Issue: "Command not found: firebase"
- Reinstall Firebase CLI: `npm install -g firebase-tools`

### Issue: Build fails
- Run `flutter clean` then `flutter pub get`
- Check Flutter version: `flutter --version`
- Update Flutter: `flutter upgrade`

### Issue: App not updating after deployment
- Clear browser cache (Ctrl+Shift+Delete)
- Hard refresh (Ctrl+Shift+R)
- Check service worker is updated in DevTools

### Issue: PWA not installable
- Must be served over HTTPS (Firebase Hosting provides this)
- Check manifest.json is accessible at `/manifest.json`
- Check service worker is registered in DevTools → Application

## Cost

Firebase Hosting **free tier** includes:
- 10 GB storage
- 360 MB/day data transfer
- Free SSL certificate

This is more than enough for a personal finance app!

## Support

- Firebase Documentation: https://firebase.google.com/docs/hosting
- Flutter Web Documentation: https://docs.flutter.dev/platform-integration/web
- PWA Documentation: https://web.dev/progressive-web-apps/

---

**Your app is now ready to be deployed! Users can install it on their devices like a native app.** 🎉
