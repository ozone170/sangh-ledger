# Privacy Policy for Sangh Ledger

**Effective Date:** November 13, 2026  
**Application Name:** Sangh Ledger  
**Package Identifier:** `in.sanghledger.app`  
**Developer / Organization:** OZONE  
**Contact Email:** [ozoneadi170@gmail.com](mailto:ozoneadi170@gmail.com)  

---

## 1. Overview & Offline-First Architecture

Sangh Ledger is an offline-first financial record-keeping application designed for community self-help groups, cooperative societies, and village Sanghs. 

We respect your privacy and believe that your financial records belong exclusively to your organization. Unlike cloud-hosted financial services, **Sangh Ledger does not maintain any remote application servers, databases, or analytics trackers**. 

All data—including:
- Member personal profiles (names, member codes, phone numbers, addresses),
- Savings accounts, monthly contributions, and balances,
- Loan disbursements, repayment schedules, and daily interest calculations,
- Double-entry balanced accounting journal entries (`SUM(debits) == SUM(credits)`), and
- Generated PDF audit reports and payment receipts

are processed, computed, and stored **100% locally on your Android device** inside an encrypted database. At no point is your financial or member data transmitted to or collected by OZONE.

---

## 2. Google Drive API Usage & Google API Services User Data Policy

Sangh Ledger provides an optional, automated cloud backup capability enabling administrators to protect their ledger records against device theft, damage, or loss.

### 2.1 Scope Requested
The application requests only a single, narrow Google Drive OAuth scope:
- **`https://www.googleapis.com/auth/drive.file`** (Per-file access)

### 2.2 How We Use Your Google Drive Data
- **Restricted Access:** Sangh Ledger only reads, creates, and modifies files that **the application itself creates**. The application cannot see, search, read, modify, or delete any other existing documents, photos, spreadsheets, or files stored in your personal Google Drive.
- **Dedicated Folder:** Backups are stored strictly within a dedicated folder created by the app named `SanghLedger_Backups`.
- **Pre-Upload Encryption:** All backup archives (`SanghLedger_Backup_YYYYMMDD_HHMMSS.zip`) are encrypted on your device using **AES-256-GCM** with a cryptographic key derived from your Administrator password before being uploaded. Google Drive stores only cipher-text; neither Google nor any third party can inspect your ledger data.
- **2-Day Rolling Retention:** The app automatically retains only the two most recent backup archives in `SanghLedger_Backups` to preserve your cloud storage quota.

### 2.3 Compliance with Google API Services User Data Policy (Limited Use)
Sangh Ledger's use and transfer of information received from Google APIs adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the **Limited Use** requirements:
1. **No External Transfer:** Data retrieved from Google APIs (such as user email address and Google Drive folder references) is never transferred to any external servers or third parties.
2. **No Advertising Use:** User data is never used to serve personalized, retargeted, or interest-based advertising.
3. **No Data Selling or Brokerage:** We do not sell, rent, or monetize user data under any circumstances.
4. **No Human Reading:** No human at OZONE or any third party has access to or reads your Google Drive files or ledger records.

---

## 3. Cryptography & Data Security

We implement enterprise-grade security standards to ensure offline data security:
- **Local SQLCipher Database Encryption:** The primary SQLite database is encrypted with 256-bit AES encryption via SQLCipher.
- **Hardware-Backed Keystore:** Database encryption keys are generated randomly on the device and stored securely inside the Android Keystore (`flutter_secure_storage`).
- **Encrypted Backup Files:** Backup archives are encrypted with AES-256-GCM with authenticated tags to prevent tampering.
- **Secure Password Hashing:** Administrator passwords and authentication PINs are hashed locally using Argon2id / PBKDF2 with unique cryptographic salts. Passwords and PINs are never stored in plain text.

---

## 4. Device Permissions & Biometrics

Sangh Ledger requests only the minimum Android permissions necessary for offline functionality:
1. **Biometric Authentication (`USE_BIOMETRIC` / `USE_FINGERPRINT`):**
   - Used exclusively through Android's secure `BiometricPrompt` API to authenticate the administrator upon opening the app.
   - Sangh Ledger never accesses, processes, or stores your raw biometric data or fingerprint templates.
2. **Device Storage / Folder Access:**
   - Used when you explicitly select a visible folder (such as `Documents/SanghLedger_Backups`) to save local backup zip archives or export PDF reports.
3. **Sharing Intent (`WhatsApp` / `SMS`):**
   - Used only when the administrator explicitly taps the "Share Receipt" button to dispatch a transaction receipt to a member via their installed messaging apps.
4. **Internet Access (`INTERNET` / `ACCESS_NETWORK_STATE`):**
   - Used solely to communicate directly with Google Drive APIs (`googleapis.com`) for scheduled and manual cloud backup synchronization.

---

## 5. Data Retention, Control & Deletion

As an administrator, you maintain full control of your organizational data:
- **Local Data Deletion:** Uninstalling the application or selecting "Clear Data" in Android settings immediately and permanently deletes the SQLCipher database and Android Keystore encryption keys from your device.
- **Cloud Backup Deletion:** You can delete your encrypted backup archives at any time by navigating to your Google Drive and removing files inside the `SanghLedger_Backups` folder.
- **Revoking Google Account Access:** You can revoke Sangh Ledger's access to your Google account at any time by visiting:  
  [https://myaccount.google.com/permissions](https://myaccount.google.com/permissions)

---

## 6. Children's Privacy

Sangh Ledger is designed for adult financial administrators managing community self-help groups and does not knowingly collect or solicit any personal information from children under the age of 18.

---

## 7. Changes to this Privacy Policy

We may update this Privacy Policy from time to time. Any updates will be reflected in this document with a revised "Effective Date" and bundled with application release updates.

---

## 8. Developer Contact Information

If you have questions, feedback, or concerns regarding this Privacy Policy or Sangh Ledger's data practices, please contact:

- **Developer:** OZONE
- **Contact Person:** Adithya / OZONE Team
- **Email:** [ozoneadi170@gmail.com](mailto:ozoneadi170@gmail.com)
- **Repository:** [https://github.com/ozone170/sangh-ledger](https://github.com/ozone170/sangh-ledger)
- **Application Package:** `in.sanghledger.app`
