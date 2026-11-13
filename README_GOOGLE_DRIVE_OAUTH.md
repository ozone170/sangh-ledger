# Google Drive OAuth 2.0 Configuration Guide for Sangh Ledger

## Overview
Sangh Ledger (`in.sanghledger.app`) uses Google Drive to store automated, encrypted rolling backups of your community financial ledger.
Google Sign-In on Android requires an authorized **OAuth 2.0 Client ID** registered in the Google Cloud Console matching your app's package name and SHA-1 signing fingerprint.

If you encounter `PlatformException(network_error, r2: 7, ...)`:
- Status code **7 (`NETWORK_ERROR`)** in Google Play Services indicates either **no internet connection** or that the **OAuth 2.0 Android Client ID / SHA-1 fingerprint is not registered** in Google Cloud Console for package `in.sanghledger.app`.

---

## Prerequisites & App Credentials
- **Package Name:** `in.sanghledger.app`
- **Required OAuth Scopes:**
  - `email`
  - `https://www.googleapis.com/auth/drive.file` (access strictly limited to files created by Sangh Ledger)

### Extracted SHA-1 Fingerprints
From `./gradlew signingReport`:

#### Debug Keystore Fingerprint:
- **Keystore Path:** `C:\Users\hp\.android\debug.keystore`
- **SHA-1:** `B8:70:AB:5B:4D:08:E6:3B:E4:31:79:00:40:17:9D:A8:A5:DF:FD:CF`
- **SHA-256:** `C8:EE:A8:5E:78:16:B1:A5:B8:3D:F3:4A:54:96:D0:4D:69:4E:D5:1E:65:A2:B4:D5:D4:61:42:7F:39:66:23:4A`

#### Release Keystore Fingerprint:
If building with a custom release keystore (e.g., `android/app/key.jks`), run:
```powershell
cd android
./gradlew signingReport
```
Locate `Variant: releaseAndroidTest` or `Variant: release` and copy its SHA-1.

---

## Step-by-Step Google Cloud Console Setup

### Step 1: Create or Select a Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Click the project dropdown at the top and click **New Project**.
3. Name it **Sangh Ledger** and click **Create**.

### Step 2: Enable the Google Drive API
1. Navigate to **APIs & Services $\rightarrow$ Library**.
2. Search for **Google Drive API**.
3. Click **Enable**.

### Step 3: Configure the OAuth Consent Screen
1. Navigate to **APIs & Services $\rightarrow$ OAuth consent screen**.
2. Choose User Type: **External** $\rightarrow$ click **Create**.
3. Fill in:
   - **App name:** `Sangh Ledger`
   - **User support email:** (Your Gmail address)
   - **Developer contact information:** (Your Gmail address)
4. Under **Scopes**, click **Add or Remove Scopes**:
   - Add `.../auth/userinfo.email`
   - Add `.../auth/drive.file`
5. Under **Test Users**, add the Google email addresses you plan to use for backing up during development/testing.
6. Click **Save and Continue**.

### Step 4: Create Android OAuth 2.0 Client ID
1. Navigate to **APIs & Services $\rightarrow$ Credentials**.
2. Click **+ CREATE CREDENTIALS** $\rightarrow$ **OAuth client ID**.
3. Select Application Type: **Android**.
4. Fill in:
   - **Name:** `Sangh Ledger Android Client`
   - **Package name:** `in.sanghledger.app`
   - **SHA-1 certificate fingerprint:**
     ```text
     B8:70:AB:5B:4D:08:E6:3B:E4:31:79:00:40:17:9D:A8:A5:DF:FD:CF
     ```
5. Click **CREATE**.
   *(Note: If you have a separate Release keystore, create a second Android OAuth Client ID using the release SHA-1).*

---

## Verification
1. Ensure the Android device / emulator has internet connectivity.
2. In Sangh Ledger Step 6 (or Settings $\rightarrow$ Backup & Restore), tap **Connect Google Drive Backup**.
3. The Google Account chooser will open and bind cleanly.

