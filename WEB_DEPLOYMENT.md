# Web Deployment Guide - Simple Expense Tracker PWA

This guide explains how to build and deploy your Flutter app as a Progressive Web App (PWA) that users can install directly from their browser.

## What is a PWA?

A Progressive Web App allows users to install your app on their Android or iOS device directly from a website, without going through Google Play Store or Apple App Store.

## Build the Web Version

### 1. Build for Production

```bash
flutter build web --release
```

This creates optimized production files in the `build/web/` directory.

### 2. Build with Custom Base Path (if hosting in subdirectory)

```bash
flutter build web --release --base-href "/expense-tracker/"
```

Replace `/expense-tracker/` with your actual subdirectory path.

## Hosting Options

### Option 1: Firebase Hosting (Recommended - Free & Easy)

1. Install Firebase CLI:
```bash
npm install -g firebase-tools
```

2. Login to Firebase:
```bash
firebase login
```

3. Initialize Firebase in your project:
```bash
firebase init hosting
```

4. When prompted:
   - Select your Firebase project or create a new one
   - Set public directory to: `build/web`
   - Configure as single-page app: Yes
   - Set up automatic builds: No

5. Deploy:
```bash
flutter build web --release
firebase deploy --only hosting
```

Your app will be live at: `https://your-project.web.app`

### Option 2: GitHub Pages (Free)

1. Build the web version:
```bash
flutter build web --release --base-href "/Simple-Expense-Tracker-App/"
```

2. Create a `gh-pages` branch and push the build folder:
```bash
cd build/web
git init
git add .
git commit -m "Deploy PWA"
git branch -M gh-pages
git remote add origin https://github.com/yourusername/Simple-Expense-Tracker-App.git
git push -f origin gh-pages
```

3. Enable GitHub Pages in repository settings, select `gh-pages` branch

Your app will be at: `https://yourusername.github.io/Simple-Expense-Tracker-App/`

### Option 3: Netlify (Free)

1. Create account at [netlify.com](https://netlify.com)
2. Drag and drop the `build/web` folder to Netlify
3. Your app will be deployed instantly with a custom URL

### Option 4: Vercel (Free)

1. Install Vercel CLI:
```bash
npm install -g vercel
```

2. Deploy:
```bash
cd build/web
vercel
```

Follow the prompts to complete deployment.

## Installation Instructions for Users

### On Android:

1. Open the website in Chrome
2. Look for the "Install" prompt at the bottom of the screen
3. Tap "Install" or tap the three-dot menu → "Install app"
4. The app will be added to your home screen

### On iOS (Safari):

1. Open the website in Safari
2. Tap the Share button (square with arrow pointing up)
3. Scroll down and tap "Add to Home Screen"
4. Tap "Add"
5. The app will appear on your home screen

## PWA Features Enabled

Your app now includes:

- **Offline Support**: Service worker caches essential files
- **Install Prompt**: Users can install the app to their home screen
- **App-like Experience**: Runs in fullscreen mode without browser UI
- **Fast Loading**: Cached resources load instantly
- **Responsive**: Works on all screen sizes
- **Material Design**: Native-like look and feel

## Testing Locally

You can test the PWA locally using a simple HTTP server:

```bash
# Using Python 3
cd build/web
python3 -m http.server 8000
```

Then open `http://localhost:8000` in your browser.

**Note**: For PWA features to work fully, you need HTTPS. Use one of the hosting options above for full PWA functionality.

## SSL/HTTPS Requirement

PWA features (like installation and service workers) require HTTPS. All the hosting options above provide free HTTPS certificates automatically.

## Updating Your PWA

1. Make changes to your Flutter code
2. Rebuild:
```bash
flutter build web --release
```
3. Redeploy using your chosen hosting method
4. Users will automatically get the update on their next visit

## Troubleshooting

### Install button doesn't appear:
- Ensure you're using HTTPS
- Clear browser cache
- Check browser console for errors
- Verify manifest.json is loading correctly

### App doesn't work offline:
- Service worker may not be registered
- Check browser console for service worker errors
- Ensure all required files are cached

### Icons not showing:
- Verify icon files exist in `web/icons/`
- Check manifest.json paths
- Clear cache and reload

## Additional Resources

- [Flutter Web Documentation](https://docs.flutter.dev/platform-integration/web)
- [PWA Checklist](https://web.dev/pwa-checklist/)
- [Firebase Hosting Docs](https://firebase.google.com/docs/hosting)

## Current Build Version

Version: 4.0.0+4 (from pubspec.yaml)
