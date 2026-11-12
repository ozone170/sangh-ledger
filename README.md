# Sangh Ledger (ಸಂಘ ಲೆಡ್ಜರ್)

An offline-first, mathematically immutable community/Sangh financial ledger application built with Flutter, Clean Architecture, SQLCipher 256-bit AES encryption, and Material 3.

---

## 🏛️ Project Identity & Core Constraints

- **Package:** `in.sanghledger.app`
- **Primary Scale:** Up to 100 active members (`SGH001`–`SGH100`), 1 master administrator
- **Supported Languages:** English (`en`) & Kannada (`kn`) with formal financial terminology
- **Currency:** Indian Rupee (`₹` / `INR`) stored and computed exclusively in **integer paise** (`₹100.50` = `10050`)
- **Interest Convention:** Daily reducing-balance non-compounding interest at `1%` monthly (`100` basis points) on a 365-day basis in `Asia/Kolkata` (`UTC+05:30`)
- **Accounting Architecture:** Strict double-entry ledger where `SUM(debits) == SUM(credits)` atomically
- **Data Security:** Encrypted local SQLite via `sqflite_sqlcipher`, Android Keystore key management, Argon2id password hashing, and AES-256-GCM encrypted backup archives

---

## 📊 Chart of Accounts

| Account Code | Account Name | Type | Normal Balance |
|:---:|:---|:---:|:---:|
| `1001` | Cash in Hand | Asset | Debit |
| `1002` | Bank Balance | Asset | Debit |
| `1101` | Loan Principal Receivables | Asset | Debit |
| `1102` | Interest Receivables | Asset | Debit |
| `2001` | Member Savings Liabilities | Liability | Credit |
| `4001` | Interest Income | Income | Credit |
| `5001` | Authorized Adjustments | Equity | Credit |

---

## ⚡ Financial Implementation Rules

1. **Integer Paise Only:** Never use floating-point types (`double`/`float`) for money to prevent IEEE 754 precision drift.
2. **Basis Points:** 1% = 100 bps. Formula with `ROUND_HALF_UP`:
   $$\text{interestPaise} = \left\lfloor\frac{(\text{principalPaise} \times \text{monthlyBps} \times 12 \times \text{days}) + 1825000}{3650000}\right\rfloor$$
3. **Repayment Order:** Settle accrued interest **FIRST**, apply remaining payment to outstanding principal **SECOND**.
4. **Immutability:** Never overwrite posted financial records; adjustments require an atomic reversal transaction.

---

## 🚀 Building & Testing

### Run All Unit & Integration Tests:
```powershell
flutter test
```

### Static Analysis:
```powershell
flutter analyze
```

### Build Production Split-ABI APKs:
```powershell
flutter build apk --release --split-per-abi
```
Generated APKs:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (Modern 64-bit phones)
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (Older 32-bit phones)
- `build/app/outputs/flutter-apk/app-x86_64-release.apk` (Emulators/tablets)

---

## 🔐 Administrator User Guide

1. **First-Time Setup (6-Step Wizard):**
   - Step 1: Select preferred language (English/Kannada) and enter Sangh details.
   - Step 2: Create Administrator credentials.
   - Step 3: Configure optional 4–6 digit PIN, Biometrics, and security recovery question.
   - Step 4: Verify non-negotiable financial parameters.
   - Step 5: Review settings.
   - Step 6: Commit initialization.
2. **Member Operations:**
   - Add new members up to 100 active members max (`SGH001`–`SGH100`).
   - Inactive members are restricted from deposits, withdrawals, or new loans.
3. **Savings & Pigmy:**
   - Record deposits via Cash or Bank with automatic receipt generation.
   - Withdrawals validate available ledger-derived balance before payout.
4. **Loans & Reducing Interest:**
   - Create loan drafts $\rightarrow$ Disburse loan to active members.
   - Interest accrues strictly on remaining unpaid principal.
   - Repayments allocate to interest first, principal second.
5. **Backups & PDF Receipts:**
   - Create AES-256-GCM encrypted `.zip` backups with the Admin password.
   - Print or export Kannada & English PDF receipts directly from transaction history.
