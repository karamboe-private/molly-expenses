# Molly Expenses — Firebase Setup

Follow these steps to connect the app to your Firebase project.

## 1. Create Firebase project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create project `molly-expenses` (or your preferred name)
3. Enable **Blaze plan** (required for Cloud Functions + Gemini API)

## 2. Enable services

- **Authentication** → Email/Password
- **Cloud Firestore** → Create database (production mode)
- **Storage** → Enable
- **Functions** → Enable

## 3. Configure Flutter app

```bash
dart pub global activate flutterfire_cli
cd ~/git/molly_expenses
flutterfire configure
```

This generates:
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

## 4. Deploy rules and functions

```bash
firebase login
firebase use molly-expenses   # your project id
firebase deploy --only firestore:rules,firestore:indexes,storage

# Set Gemini API key secret
firebase functions:secrets:set GEMINI_API_KEY

cd functions && npm install && cd ..
firebase deploy --only functions
```

Get a Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey).

## 5. Run the app

```bash
flutter pub get
flutter run
```

## User roles

- **Parent/Owner**: Register without invite code → sees all expenses, can invite assistants, export reports
- **Assistant**: Register with invite code from parent → sees only their own expenses

## Receipt scanning

1. Tap **Scan** on home screen
2. Take photo of receipt
3. Cloud Function analyzes with Gemini Vision
4. Review pre-filled fields and save

If analysis fails, enter details manually.
