# Sangh Ledger – Master Flutter Developer Taskbook (Tasks 01–18)

---

## Phase 1: Project Foundation & Localization

### TASK 01 – Project Configuration & Clean Architecture Setup
Read `AGENTS.md` completely before making changes.
1. Configure `pubspec.yaml` with stable versions of:
   - `flutter_riverpod`, `sqflite_sqlcipher`, `flutter_secure_storage`, `local_auth`, `cryptography`, `pdf`, `printing`, `archive`, `file_picker`, `image`, `intl`, `uuid`, `path_provider`, `path`, `timezone`.
   - `flutter_localizations` (sdk: flutter).
2. Update `android/app/build.gradle` (or `build.gradle.kts`):
   - Set `applicationId = "in.sanghledger.app"`.
   - Set `minSdk = 26`, `targetSdk = 34`.
   - Set app label in `AndroidManifest.xml` to `Sangh Ledger`.
3. Create folder architecture under `lib/`:
   - `core/` (`database/`, `security/`, `navigation/`, `localization/`, `theme/`, `utils/`, `validation/`)
   - `data/` (`models/`, `repositories/`)
   - `domain/` (`entities/`, `services/`, `usecases/`)
   - `features/` (`onboarding/`, `authentication/`, `dashboard/`, `members/`, `savings/`, `loans/`, `repayments/`, `transactions/`, `reports/`, `receipts/`, `settings/`)
4. Register `assets/fonts/NotoSansKannada-Regular.ttf` in `pubspec.yaml`.
5. Run `flutter pub get`, `flutter analyze`, and `flutter build apk --debug`.

---

### TASK 02 – Material 3 Design System & Navigation Shell
1. Create `lib/core/theme/app_theme.dart`:
   - Primary Navy Blue (`#0F294A`), Financial Teal/Emerald (`#00897B`), Light Neutral Surface (`#F5F7FA`), Pure White Cards (`#FFFFFF`), Error Crimson (`#D32F2F`).
   - High-contrast typography with tabular figures (`fontFeatures: [FontFeature.tabularFigures()]`) for readable INR amounts.
2. Build reusable widgets in `lib/core/ui/`:
   - `PrimaryButton`, `SecondaryButton`, `FinancialSummaryCard`, `MemberListItem`, `TransactionListItem`
   - `AmountInput` (accepts Rupee decimal text like `"500.50"` and outputs exact integer paise `50050` with zero floating-point math)
   - `SearchField`, `DateSelector`, `ConfirmationDialog`, `EmptyState`, `LoadingState`, `ErrorState`
3. Configure navigation routes (`Splash`, `Onboarding`, `Login`, `MainShell`, `MemberDetail`, `LoanDetail`, `Repayment`, `Transactions`, `Reports`, `Settings`) and 5-tab BottomNavigationBar (`Home`, `Members`, `Savings`, `Loans`, `More`).
4. Run `flutter analyze` and widget smoke tests.

---

### TASK 03 – English & Auto-Generated Kannada Localization
1. Enable `generate: true` in `pubspec.yaml` and create `l10n.yaml`.
2. Create `lib/l10n/app_en.arb` with keys for every screen, button, form label, validation error, receipt label, and accounting term.
3. Auto-generate `lib/l10n/app_kn.arb` with accurate, formal Kannada banking and Sangh terminology for every key in `app_en.arb`.
4. Implement `LocaleNotifier` (Riverpod) persisting chosen locale (`en` or `kn`) in local preferences, accessible on the first Onboarding screen and inside Settings.
5. Ensure zero hardcoded UI strings remain and Kannada glyphs render cleanly with `NotoSansKannada`.

---

## Phase 2: Onboarding, Security & Encrypted Database

### TASK 04 – Resumable 6-Step Organization Initialization Wizard
Implement first-launch detection and a 6-screen onboarding flow:
1. **Screen 1 (Language & Organization Profile):** Language toggle (`English` / `ಕನ್ನಡ`), Sangh Name, Logo picker (compress & resize to WebP under 200 KB saved in app documents dir), Address, Contact Number, Optional Registration Number, Financial Year Start.
2. **Screen 2 (Administrator Account):** Username, Strong Password, Confirm Password.
3. **Screen 3 (Security Setup):** Optional 4–6 digit PIN, Biometric (`local_auth`) opt-in, Security Recovery Question & Answer (hashed).
4. **Screen 4 (Financial Defaults):** Display locked/default parameters: INR (`₹`), 1% monthly (100 bps), Reducing Balance, Flexible Repayments, 365-day basis, Max 100 active members.
5. **Screen 5 (Review):** Summary of all entered settings before committing.
6. **Screen 6 (Commit & Complete):** Atomically create Organization + Admin records and mark initialization complete. Persist draft step progress so interrupted setup resumes cleanly without duplicate records.

---

### TASK 05 – Administrator Authentication & Security
1. Implement `AuthService` in `lib/core/security/`:
   - Argon2id password hashing + salt.
   - Optional PIN hashing.
   - Biometric authentication via `local_auth` with instant fallback to password.
   - Exponential login lockout delay after 3 failed attempts.
   - Auto-lock timer when app moves to background (`WidgetsBindingObserver`).
   - Change Password, Change PIN, and Recovery Question verification to reset forgotten password without wiping data.
2. Write unit tests for password/PIN hashing, lockout backoff, and recovery flow.

---

### TASK 06 – Encrypted SQLCipher Database & Migrations
1. Implement `DatabaseKeyManager` using `flutter_secure_storage` (Android Keystore) to generate and retrieve a 256-bit database encryption passphrase. If an existing encrypted DB fails to open, throw an explicit error—NEVER silently overwrite or recreate an empty database.
2. Implement `AppDatabase` using `sqflite_sqlcipher` with foreign keys enabled (`PRAGMA foreign_keys = ON`) and schema versioning.
3. Create tables with UUID primary keys, indexed query columns, and integer paise amounts:
   - `organizations`, `admins`, `app_settings`
   - `members` (unique `member_code` like `SGH001`)
   - `savings_accounts`
   - `loans`, `loan_disbursements`
   - `transactions`, `interest_accruals`, `repayments`, `transaction_allocations`
   - `accounting_accounts`, `journal_entries`, `journal_lines`
   - `audit_logs`, `backup_history`
4. Write database tests verifying encryption, schema constraints, and migration safety.

---

## Phase 3: Members, Double-Entry Ledger & Core Operations

### TASK 07 – Member Management Module (`SGH001`–`SGH100`)
1. Implement `MemberRepository` and UI screens: Directory with search/filter (Active/Inactive), Add/Edit Member form, and Member Profile with 4 tabs (`Overview`, `Savings`, `Loans`, `Transactions`).
2. Auto-generate sequential codes `SGH001`, `SGH002`, etc.
3. Enforce hard business rules:
   - Maximum **100 active members** (block activating or adding a 101st active member with clear localized error).
   - Never delete members who have any transaction history; allow Deactivate/Reactivate instead.
   - Block deposits, withdrawals, or new loans for Inactive members.
4. Write unit and repository tests verifying the 100-member cap and inactive member restrictions.

---

### TASK 08 – Double-Entry Accounting & Ledger Engine
1. Seed the 7 Chart of Accounts (`Cash`, `Bank`, `Member Savings Liabilities`, `Loan Principal Receivables`, `Interest Receivables`, `Interest Income`, `Authorized Adjustments`).
2. Implement `AccountingEngine` inside a single SQLite transaction (`db.transaction`):
   - Validate `SUM(debit_paise) == SUM(credit_paise)` before inserting `journal_entries` and `journal_lines`; reject unbalanced entries.
   - Build atomic posting templates for: Savings Deposit, Savings Withdrawal, Loan Disbursement, Principal Repayment, Interest Accrual, Interest Collection, and Reversal.
   - Derive all account and member balances from ledger/transaction records rather than editable balance fields.
3. Write comprehensive unit tests verifying every posting template balances to zero net difference.

---

### TASK 09 – Savings & Pigmy Management
1. Implement random-value **Savings Deposit** workflow: Select Active Member $\rightarrow$ Enter Amount & Mode (Cash/Bank) $\rightarrow$ Preview $\rightarrow$ Confirm $\rightarrow$ Atomic Transaction + Journal Entry + Audit Log.
2. Implement Administrator-Authorized **Savings Withdrawal** workflow: Display current ledger-derived balance $\rightarrow$ Enter Amount & Reason $\rightarrow$ Require Admin Password/Biometric confirmation $\rightarrow$ Validate `withdrawal <= available_balance` $\rightarrow$ Atomic posting.
3. Implement Member Savings Statement view with date filtering.
4. Write tests covering deposits, insufficient-balance rejection, and reversal handling.

---

### TASK 10 – Loan Creation & Disbursement
1. Implement multi-loan creation per active member:
   - Principal amount (paise), Monthly Interest Rate in basis points (default `100` bps = `1%`), Method (`Reducing Balance`), Day-Count (`365`), Loan Date (`Asia/Kolkata`), Optional Duration, Optional First Repayment Date, Remarks.
   - Generate unique readable Loan ID (e.g., `LN-2026-0001`).
   - Support `Draft` state (editable) $\rightarrow$ Confirmed `Disbursement` (posts accounting journal, records disbursement mode Cash/Bank, transitions loan to `Active`).
2. Enforce loan states: `Draft`, `Active`, `Partially Repaid`, `Closed`, `Restructured`, `Cancelled`. Block closing a loan if principal or interest > 0 paise.
3. Write unit tests for loan lifecycle and accounting entries.

---

## Phase 4: Interest Engine & Repayments

### TASK 11 – Daily Reducing-Balance Interest Calculation Engine
1. Build pure-Dart `InterestCalculator` in `lib/domain/services/`:
   - Compute exact elapsed days in `Asia/Kolkata` timezone between last accrual/disbursement date and target date.
   - Calculate interest using `BigInt` arithmetic:
     `interestPaise = roundHalfUp((outstandingPrincipalPaise * monthlyBps * 12 * days) / (10000 * 365))`
   - Non-compounding (interest accrues strictly on unpaid principal).
   - Support loan restructuring as a separate auditable record preserving original terms.
2. Write exhaustive unit tests: 1-paisa edge cases, ₹10,00,000 large loans, leap years (Feb 29), 0-day same-day checks, and multi-month intervals.

---

### TASK 12 – Flexible Loan Repayment Module
1. Build Repayment Screen: Select Member $\rightarrow$ Select Active Loan $\rightarrow$ Select Payment Date $\rightarrow$ Enter Arbitrary Payment Amount.
2. Live Allocation Preview before confirmation:
   - Dynamically accrue interest up to selected Payment Date.
   - Apply payment to **Accrued Interest FIRST**, then **Outstanding Principal SECOND**.
   - Display exact split (`Interest Paid`, `Principal Paid`, `Remaining Principal`, `Remaining Interest`).
   - Reject overpayments exceeding `total_principal + total_accrued_interest`.
3. Post repayment, allocations, interest accrual, and double-entry journal lines atomically. Automatically set loan status to `Closed` when both balances reach `0` paise.
4. Write unit tests for interest-only, partial-principal, exact-closure, and overpayment-rejection scenarios.

---

## Phase 5: Audit, Reports & Kannada PDF Receipts

### TASK 13 – Unified Transaction Ledger, Audit Trail & Reversals
1. Build centralized Transaction History screen searchable by Transaction ID, Receipt Number, Loan ID, or Member Name, and filterable by Date Range and Transaction Type.
2. Build Transaction Detail inspector showing linked double-entry `JournalLines` and `AuditLogs`.
3. Implement **Atomic Reversal Workflow**:
   - Require Admin confirmation + mandatory reason.
   - Mark original transaction as reversed (preventing duplicate reversals) and post equal-and-opposite reversal journal lines.
   - Recalculate affected savings or loan state cleanly.
4. Write tests verifying duplicate reversals are blocked and balances revert accurately.

---

### TASK 14 – Financial Reports Engine (12 Reports)
Implement real-time report generation strictly from underlying ledger/transaction queries with date-range, member, and status filters:
1. Member Register
2. Individual Member Ledger
3. Savings Register
4. Loan Register
5. Outstanding Principal Report
6. Outstanding Interest Report
7. Interest Collected Report
8. Repayment Report
9. Daily Cashbook
10. Monthly Summary
11. Trial Balance (verifying Total Debits == Total Credits)
12. Audit History Report
- Support English & Kannada headers, INR formatting, and PDF export.
- Write reconciliation unit tests confirming Trial Balance and registers match to the exact paisa.

---

### TASK 15 – Kannada & English PDF Receipts
1. Build `PdfReceiptService` using the `pdf` package with embedded `NotoSansKannada-Regular.ttf`:
   - Receipt templates for: Savings Deposit, Savings Withdrawal, Loan Disbursement, and Loan Repayment.
   - Include Sangh logo, Sangh name, address, Receipt #, Transaction ID, Member ID & Name, Date, Amount in INR, Updated Balance/Allocation breakdown, Remarks, and Admin Signature block.
   - Support both A4 and Compact receipt formats in English or Kannada.
2. Integrate Android Print & Share sheet (`printing` package) and allow non-destructive regeneration of past receipts from Transaction History.

---

## Phase 6: Backup, QA & Production APK

### TASK 16 – Password-Encrypted Local Backup & Restoration
1. Implement `BackupService`:
   - Export `SanghLedger_Backup_YYYYMMDD_HHMM.zip` via Android Storage Access Framework (`file_picker` / `share_plus`).
   - Bundle `manifest.json` (app version, schema version, organization UUID, SHA-256 checksums), `database.enc`, and `organization_logo.webp`.
   - Encrypt `database.enc` using **AES-256-GCM** with a key derived from the **Admin's login password** (PBKDF2/Argon2id with random salt stored in `manifest.json`).
   - Retain latest backup and 1 previous backup; never delete existing valid backups before verifying the new archive.
2. Implement `RestoreService`:
   - Prompt user to pick `.zip` backup and enter the **Admin's login password** to decrypt.
   - Verify SHA-256 checksum and schema compatibility in a temporary staging directory before atomically swapping the active database (protecting against corrupted files or wrong passwords).
3. Write automated backup/restore tests including wrong-password and tampered-zip rejection.

---

### TASK 17 – Full QA, Security & 10,000-Transaction Load Audit
Write and execute an automated integration/unit test suite validating:
1. **Financial Edge Cases:** 1-paisa rounding, ₹50,00,000 loans, leap-year Feb 29 interest, same-day multiple repayments, full reversal chains.
2. **Security:** Encrypted DB rejection without key, brute-force login delay, backup decryption failure on wrong password.
3. **Scale & Performance:** Seed 100 active members and 10,000 transactions in an automated test; verify search response, Trial Balance calculation, and PDF generation complete rapidly without memory leaks.
4. Fix all discovered defects and verify `flutter analyze` and `flutter test` pass 100%.

---

### TASK 18 – Production Split-ABI Release APK
1. Configure ProGuard/R8 rules in `android/app/proguard-rules.pro` to preserve `sqflite_sqlcipher` native JNI bindings.
2. Ensure all sensitive debug prints are stripped in release mode.
3. Run full test suite: `flutter test`.
4. Build production lean APK:
   ```powershell
   flutter build apk --release --split-per-abi
   ```
   Verify output at `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk`, generate `README.md` + Administrator User Guide, and verify installation on a physical Android phone offline.

