# Gemini AI Volunteer Matching — Setup Guide

This document explains how to activate the Gemini AI matching system in eMADAD.

---

## 1. Get a Gemini API Key

1. Go to → [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Click **Create API key**
3. Copy the key — it looks like `AIzaSy...`

---

## 2. Run / Build with the Key

The key is injected at **build time** using `--dart-define`.  
It is **never stored in source code.**

### Run on emulator / device
```bash
flutter run --dart-define=GEMINI_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### Build APK
```bash
flutter build apk --dart-define=GEMINI_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### Build App Bundle (Play Store)
```bash
flutter build appbundle --dart-define=GEMINI_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

---

## 3. (Optional) VS Code Launch Configuration

Add to `.vscode/launch.json` so you never have to type it manually:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "eMADAD (with Gemini)",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=GEMINI_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
      ]
    }
  ]
}
```

> ⚠️ **Do NOT commit `.vscode/launch.json`** if it contains the real key.  
> Add it to `.gitignore` or use environment variable substitution.

---

## 4. How the Hybrid Matching Works

```
"Find Best Match" tapped
         │
         ▼
 AllocationService.rankVolunteers()
 ─ Filter: available=true, skill match, distance ≤ 10 km
 ─ Returns top-5 candidates (fast, local, no network)
         │
         ▼
 GeminiMatchingService._callGemini()
 ─ Sends structured JSON prompt to Gemini 1.5 Flash
 ─ Hard 4-second timeout
         │
    ┌────┴────┐
 Success     Fail / Timeout
    │             │
    ▼             ▼
 Parse IDs    Fallback sort
 Re-rank      (distance + reliability)
    │             │
    └─────┬───────┘
          ▼
 Best volunteer assigned → Firestore
 UI updated (AI Pick 🤖 badge shown)
```

---

## 5. What Gets Written to Firestore

When the AI picks a volunteer, the emergency document is updated:

```json
{
  "assignedVolunteerId": "vol_abc123",
  "status": "accepted",
  "aiMatched": true,
  "matchedAt": "<server timestamp>"
}
```

If the fallback was used: `"aiMatched": false`

---

## 6. Performance Guarantees

| Concern | Guarantee |
|---|---|
| UI blocked while AI runs | ❌ Never — async, non-blocking |
| Repeated Gemini calls | ❌ Prevented by session cache |
| App crash on API failure | ❌ Never — silent fallback |
| Max wait for AI | ≤ 4 seconds, then instant fallback |
| Cold load (no AI yet) | AllocationService list shown immediately |

---

## 7. Run without a Key (Fallback mode)

Simply omit `--dart-define`. The app runs 100% normally using the  
AllocationService composite score (distance + reliability + response rate).  
The "AI Matching Enabled" badge stays visible as intent indicator.
