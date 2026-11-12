# AGENTS.md – Sangh Ledger (Flutter CLI Edition)

## 1. Project Identity
- **Application:** Sangh Ledger
- **Package:** `in.sanghledger.app`
- **Purpose:** Offline-first community/Sangh financial ledger application.
- **Scale & Constraints:** Maximum 100 active members, 1 administrator, English (`en`) and Kannada (`kn`), Currency `INR` (`₹`), Timezone `Asia/Kolkata`, 100% offline.

## 2. Technology Stack
- **Framework:** Flutter (Stable), Dart 3.x, Material 3
- **Architecture:** Clean Architecture (`core/`, `data/`, `domain/`, `features/`) + Riverpod (`flutter_riverpod`)
- **Database:** `sqflite_sqlcipher` (SQLite + SQLCipher encryption) + `flutter_secure_storage` (Android Keystore)
- **Authentication & Crypto:** `local_auth` (BiometricPrompt), `cryptography` (Argon2id + AES-256-GCM)
- **Localization:** `flutter_localizations` + `intl` (`app_en.arb`, `app_kn.arb` auto-generated with standard financial Kannada terms)
- **PDF & Backup:** `pdf`, `printing`, `archive`, `file_picker`, `image` (WebP compression)

## 3. Financial Implementation Rules (Non-Negotiable)
1. **Integer Paise Only:** Store and compute ALL money in `int` paise (`₹100.50` = `10050`). Never use `double` or `float` for monetary values.
2. **Basis Points:** Store interest rates as `int` basis points (`1%` = `100` bps). Default monthly rate = `100` bps.
3. **Reducing-Balance Daily Interest:**
   - Calculated on outstanding principal only (non-compounding).
   - Daily rate convention: `(monthly_bps / 10000) * 12 / 365`.
   - Formula using `BigInt` to avoid overflow: `((BigInt.from(principalPaise) * BigInt.from(monthlyBps) * BigInt.from(12) * BigInt.from(days)) / BigInt.from(3650000))` with `ROUND_HALF_UP`.
4. **Repayment Allocation Order:** Settle accrued interest FIRST, apply remaining payment to principal SECOND.
5. **Timezone:** Interpret all financial dates and day counts strictly in `Asia/Kolkata` (`UTC+05:30`).

## 4. Double-Entry Accounting & Immutability
- Maintain Chart of Accounts:
  1. `1001` Cash (Asset)
  2. `1002` Bank (Asset)
  3. `1101` Loan Principal Receivables (Asset)
  4. `1102` Interest Receivables (Asset)
  5. `2001` Member Savings Liabilities (Liability)
  6. `4001` Interest Income (Income)
  7. `5001` Authorized Adjustments (Equity/Adjustment)
- Every financial event MUST post an atomic `JournalEntry` where `SUM(debits) == SUM(credits)`.
- Never treat member savings as organizational income. Never treat accrued interest as collected interest.
- **Immutability:** Never delete or overwrite posted financial records. All corrections must post an atomic Reversal + Replacement entry.

## 5. Security & Backup Policy
- Hash admin password using Argon2id with random per-user salt.
- Generate a 256-bit SQLCipher database key stored exclusively in Android Keystore (`flutter_secure_storage`). Never hardcode keys. Never log passwords, PINs, or keys.
- Encrypt `SanghLedger_Backup_YYYYMMDD.zip` using AES-256-GCM with a key derived from the **Admin's login password** so backups restore seamlessly on a new device using the same Admin password.

## 6. Milestone Completion Standard
Before declaring any task complete:
1. Run `flutter analyze` (must pass with 0 errors).
2. Run `flutter test` (all unit & database tests must pass).
3. Never use mock/fake financial figures in production screens.
4. Provide a concise report of changed files, executed tests, and verification status.

