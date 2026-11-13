# Google Drive OAuth 2.0 Configuration Guide for Sangh Ledger

## Overview
Sangh Ledger (`in.sanghledger.app`) uses Google Drive to store automated, encrypted rolling backups of your community financial ledger.
Google Sign-In on Android requires an authorized **OAuth 2.0 Client ID** registered in the Google Cloud Console matching your app's package name and SHA-1 signing fingerprint.

If you encounter Google Sign-In errors:
- **Code 7 (`PlatformException(network_error, r2: 7, ...)`):** Google Play Services indicates **no internet connection** or missing SHA-1 fingerprint registration.
- **Code 10 (`PlatformException(sign_in_failed, r2: 10, ...)` / `DEVELOPER_ERROR`):** The SHA-1 fingerprint of the signing certificate used to build the APK does NOT match the Android OAuth Client in Google Cloud Console. For release builds, you MUST register the release SHA-1 below.

---

## Prerequisites & App Credentials
- **Package Name:** `in.sanghledger.app`
- **Required OAuth Scopes:**
  - `email`
  - `https://www.googleapis.com/auth/drive.file` (access strictly limited to files created by Sangh Ledger)

### Exact SHA-1 Certificate Fingerprints

#### 1. Production Release Keystore (Active in `sangh_v1_release.jks`):
- **Keystore Path:** `android/app/sangh_v1_release.jks`
- **Key Alias:** `sangh_v1`
- **SHA-1:** `5F:BF:49:2E:77:E7:A7:8F:D9:F0:0A:03:C4:F1:66:B6:A9:07:1E:0F`
- **SHA-256:** `BB:46:28:FD:01:7C:48:2B:DA:EE:76:9C:34:C2:5B:42:4E:EE:16:D6:BF:FA:88:61:21:B4:28:B2:03:1D:67:F9`

#### 2. Debug Keystore:
- **Keystore Path:** `C:\Users\hp\.android\debug.keystore`
- **SHA-1:** `B8:70:AB:5B:4D:08:E6:3B:E4:31:79:00:40:17:9D:A8:A5:DF:FD:CF`
- **SHA-256:** `C8:EE:A8:5E:78:16:B1:A5:B8:3D:F3:4A:54:96:D0:4D:69:4E:D5:1E:65:A2:B4:D5:D4:61:42:7F:39:66:23:4A`

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

