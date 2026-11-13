import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'database_key_manager.dart';

class AppDatabase {
  static const String _dbFileName = 'sangh_ledger_encrypted.db';
  static const int _dbVersion = 1;

  final DatabaseKeyManager _keyManager;
  static Database? _sharedDb;
  static Future<Database>? _dbInitFuture;

  static final AppDatabase _instance = AppDatabase._internal();

  factory AppDatabase({DatabaseKeyManager? keyManager}) {
    if (keyManager != null) {
      return AppDatabase._withKeyManager(keyManager);
    }
    return _instance;
  }

  AppDatabase._internal() : _keyManager = DatabaseKeyManager();
  AppDatabase._withKeyManager(this._keyManager);

  /// Provides singleton access to the active encrypted database instance,
  /// protected by a memoized initialization future lock to eliminate concurrency races.
  Future<Database> get database async {
    if (_sharedDb != null && _sharedDb!.isOpen) return _sharedDb!;
    _dbInitFuture ??= _initDatabase();
    try {
      _sharedDb = await _dbInitFuture!;
      return _sharedDb!;
    } catch (e) {
      _dbInitFuture = null;
      rethrow;
    }
  }

  Future<String> getDatabasePath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, _dbFileName);
  }

  Future<bool> doesDatabaseFileExist() async {
    final path = await getDatabasePath();
    return await File(path).exists();
  }

  /// Closes database connection and clears singleton future lock
  Future<void> close() async {
    if (_sharedDb != null && _sharedDb!.isOpen) {
      await _sharedDb!.close();
      _sharedDb = null;
    }
    _dbInitFuture = null;
  }

  /// Completely resets an orphaned or unrecoverable database file and reinitializes fresh
  Future<Database> resetOrReinitializeDatabase() async {
    await close();
    final path = await getDatabasePath();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    final journal = File('$path-journal');
    if (await journal.exists()) await journal.delete();
    final wal = File('$path-wal');
    if (await wal.exists()) await wal.delete();
    final shm = File('$path-shm');
    if (await shm.exists()) await shm.delete();

    // Reset secure storage key
    await _keyManager.deleteKey();

    _sharedDb = null;
    _dbInitFuture = null;
    return await database;
  }

  Future<Database> _initDatabase({String? overridePassword}) async {
    final path = await getDatabasePath();
    final password = overridePassword ?? await _keyManager.getOrCreateEncryptionKey();

    try {
      final db = await openDatabase(
        path,
        password: password,
        version: _dbVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
          await db.execute('PRAGMA busy_timeout = 5000;');
        },
        onOpen: (db) async {
          await db.execute('PRAGMA busy_timeout = 5000;');
        },
        onCreate: (db, version) async {
          await _createTables(db);
          await _seedChartOfAccounts(db);
          await _seedDefaultOrganization(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // Future migrations
        },
      );
      return db;
    } catch (e) {
      // Never silently wipe an existing encrypted DB! Throw explicit error.
      final exists = await File(path).exists();
      if (exists) {
        throw StateError(
          'Failed to open encrypted database with key. '
          'Aborting to prevent data loss. Error: $e',
        );
      }
      rethrow;
    }
  }

  Future<void> _createTables(Database db) async {
    // 1. organizations
    await db.execute('''
      CREATE TABLE organizations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        logo_path TEXT,
        address TEXT NOT NULL,
        contact_phone TEXT NOT NULL,
        registration_number TEXT,
        financial_year_start TEXT NOT NULL,
        currency TEXT NOT NULL DEFAULT 'INR',
        monthly_interest_bps INTEGER NOT NULL DEFAULT 100,
        max_members INTEGER NOT NULL DEFAULT 100,
        is_initialized INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 2. admins
    await db.execute('''
      CREATE TABLE admins (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        pin_hash TEXT,
        biometric_enabled INTEGER NOT NULL DEFAULT 0,
        recovery_question TEXT NOT NULL,
        recovery_answer_hash TEXT NOT NULL,
        failed_attempts INTEGER NOT NULL DEFAULT 0,
        locked_until TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (organization_id) REFERENCES organizations (id)
      );
    ''');

    // 3. app_settings
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 4. members
    await db.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        member_code TEXT NOT NULL UNIQUE,
        full_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (organization_id) REFERENCES organizations (id)
      );
    ''');
    await db.execute('CREATE INDEX idx_members_code ON members (member_code);');
    await db.execute('CREATE INDEX idx_members_active ON members (is_active);');

    // 5. savings_accounts
    await db.execute('''
      CREATE TABLE savings_accounts (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        member_id TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (organization_id) REFERENCES organizations (id),
        FOREIGN KEY (member_id) REFERENCES members (id)
      );
    ''');

    // 6. loans
    await db.execute('''
      CREATE TABLE loans (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        member_id TEXT NOT NULL,
        loan_code TEXT NOT NULL UNIQUE,
        principal_paise INTEGER NOT NULL,
        monthly_interest_bps INTEGER NOT NULL DEFAULT 100,
        calculation_method TEXT NOT NULL DEFAULT 'reducing_balance',
        day_count_basis INTEGER NOT NULL DEFAULT 365,
        issue_date TEXT NOT NULL,
        duration_months INTEGER,
        first_repayment_date TEXT,
        status TEXT NOT NULL DEFAULT 'Draft',
        remarks TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (organization_id) REFERENCES organizations (id),
        FOREIGN KEY (member_id) REFERENCES members (id)
      );
    ''');
    await db.execute('CREATE INDEX idx_loans_member ON loans (member_id);');
    await db.execute('CREATE INDEX idx_loans_status ON loans (status);');

    // 7. loan_disbursements
    await db.execute('''
      CREATE TABLE loan_disbursements (
        id TEXT PRIMARY KEY,
        loan_id TEXT NOT NULL,
        amount_paise INTEGER NOT NULL,
        payment_mode TEXT NOT NULL,
        disbursement_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (loan_id) REFERENCES loans (id)
      );
    ''');

    // 8. transactions
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        organization_id TEXT NOT NULL,
        member_id TEXT NOT NULL,
        transaction_type TEXT NOT NULL,
        payment_mode TEXT NOT NULL,
        amount_paise INTEGER NOT NULL,
        transaction_date TEXT NOT NULL,
        receipt_number TEXT NOT NULL UNIQUE,
        remarks TEXT,
        is_reversed INTEGER NOT NULL DEFAULT 0,
        reversal_reason TEXT,
        reversed_transaction_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (organization_id) REFERENCES organizations (id),
        FOREIGN KEY (member_id) REFERENCES members (id)
      );
    ''');
    await db.execute('CREATE INDEX idx_transactions_date ON transactions (transaction_date);');
    await db.execute('CREATE INDEX idx_transactions_member ON transactions (member_id);');
    await db.execute('CREATE INDEX idx_transactions_receipt ON transactions (receipt_number);');

    // 9. interest_accruals
    await db.execute('''
      CREATE TABLE interest_accruals (
        id TEXT PRIMARY KEY,
        loan_id TEXT NOT NULL,
        from_date TEXT NOT NULL,
        to_date TEXT NOT NULL,
        days_accrued INTEGER NOT NULL,
        principal_paise INTEGER NOT NULL,
        interest_paise INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (loan_id) REFERENCES loans (id)
      );
    ''');

    // 10. repayments
    await db.execute('''
      CREATE TABLE repayments (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        loan_id TEXT NOT NULL,
        payment_date TEXT NOT NULL,
        total_paid_paise INTEGER NOT NULL,
        interest_portion_paise INTEGER NOT NULL,
        principal_portion_paise INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id),
        FOREIGN KEY (loan_id) REFERENCES loans (id)
      );
    ''');

    // 11. transaction_allocations
    await db.execute('''
      CREATE TABLE transaction_allocations (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        allocation_type TEXT NOT NULL,
        amount_paise INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id)
      );
    ''');

    // 12. accounting_accounts (Chart of Accounts)
    await db.execute('''
      CREATE TABLE accounting_accounts (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        account_type TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      );
    ''');

    // 13. journal_entries
    await db.execute('''
      CREATE TABLE journal_entries (
        id TEXT PRIMARY KEY,
        transaction_id TEXT,
        entry_date TEXT NOT NULL,
        description TEXT NOT NULL,
        is_reversal INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id)
      );
    ''');

    // 14. journal_lines
    await db.execute('''
      CREATE TABLE journal_lines (
        id TEXT PRIMARY KEY,
        journal_entry_id TEXT NOT NULL,
        account_code TEXT NOT NULL,
        debit_paise INTEGER NOT NULL DEFAULT 0,
        credit_paise INTEGER NOT NULL DEFAULT 0,
        description TEXT,
        FOREIGN KEY (journal_entry_id) REFERENCES journal_entries (id),
        FOREIGN KEY (account_code) REFERENCES accounting_accounts (code)
      );
    ''');
    await db.execute('CREATE INDEX idx_journal_lines_entry ON journal_lines (journal_entry_id);');
    await db.execute('CREATE INDEX idx_journal_lines_account ON journal_lines (account_code);');

    // 15. audit_logs
    await db.execute('''
      CREATE TABLE audit_logs (
        id TEXT PRIMARY KEY,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        details_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute('CREATE INDEX idx_audit_created ON audit_logs (created_at);');

    // 16. backup_history
    await db.execute('''
      CREATE TABLE backup_history (
        id TEXT PRIMARY KEY,
        backup_path TEXT NOT NULL,
        backup_date TEXT NOT NULL,
        checksum_sha256 TEXT NOT NULL,
        is_auto INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');
  }

  Future<void> _seedChartOfAccounts(Database db) async {
    final accounts = [
      {'code': '1001', 'name': 'Cash in Hand', 'account_type': 'Asset'},
      {'code': '1002', 'name': 'Bank Balance', 'account_type': 'Asset'},
      {'code': '1101', 'name': 'Loan Principal Receivables', 'account_type': 'Asset'},
      {'code': '1102', 'name': 'Interest Receivables', 'account_type': 'Asset'},
      {'code': '2001', 'name': 'Member Savings Liabilities', 'account_type': 'Liability'},
      {'code': '4001', 'name': 'Interest Income', 'account_type': 'Income'},
      {'code': '5001', 'name': 'Authorized Adjustments', 'account_type': 'Equity'},
    ];

    for (final acc in accounts) {
      await db.insert('accounting_accounts', acc,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _seedDefaultOrganization(DatabaseExecutor db) async {
    final orgResults = await db.query('organizations', limit: 1);
    if (orgResults.isEmpty) {
      final now = DateTime.now().toIso8601String();
      await db.insert('organizations', {
        'id': 'org_default_sangh',
        'name': 'Sangh Ledger',
        'address': 'Karnataka, India',
        'contact_phone': '0000000000',
        'financial_year_start': '04-01',
        'currency': 'INR',
        'monthly_interest_bps': 100,
        'max_members': 100,
        'is_initialized': 0,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// Retrieves active organization ID, prioritizing initialized user organizations
  Future<String> getActiveOrganizationId([DatabaseExecutor? executor]) async {
    final db = executor ?? await database;
    final orgResults = await db.query(
      'organizations',
      orderBy: 'is_initialized DESC, updated_at DESC, created_at DESC',
      limit: 1,
    );
    if (orgResults.isNotEmpty) {
      return orgResults.first['id'] as String;
    }

    const defaultOrgId = 'org_default_sangh';
    final now = DateTime.now().toIso8601String();
    await db.insert('organizations', {
      'id': defaultOrgId,
      'name': 'Sangh Ledger',
      'address': 'Karnataka, India',
      'contact_phone': '0000000000',
      'financial_year_start': '04-01',
      'currency': 'INR',
      'monthly_interest_bps': 100,
      'max_members': 100,
      'is_initialized': 0,
      'created_at': now,
      'updated_at': now,
    });
    return defaultOrgId;
  }
}

/// Alias for AppDatabase conforming to naming conventions
typedef DatabaseHelper = AppDatabase;

