import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/clock.dart';

/// Table name constants — used by repositories so no raw strings are
/// scattered around the codebase.
class Tables {
  Tables._();
  static const users = 'users';
  static const wallets = 'wallets';
  static const categories = 'categories';
  static const transactions = 'transactions';
  static const savingGoals = 'saving_goals';
  static const transfers = 'transfers';
  static const monthlyBudgets = 'monthly_budgets';
  static const pets = 'pets';
  static const savingStreaks = 'saving_streaks';
  static const aiSuggestions = 'ai_suggestions';
  static const syncQueue = 'sync_queue';
  static const pendingTransactions = 'pending_transactions';
}

const _systemCategoryIds = {
  'Lương': '00000000-0000-4000-8000-000000000001',
  'Thưởng': '00000000-0000-4000-8000-000000000002',
  'Ăn uống': '00000000-0000-4000-8000-000000000003',
  'Di chuyển': '00000000-0000-4000-8000-000000000004',
  'Mua sắm': '00000000-0000-4000-8000-000000000005',
  'Hóa đơn': '00000000-0000-4000-8000-000000000006',
  'Giải trí': '00000000-0000-4000-8000-000000000007',
  'Sức khỏe': '00000000-0000-4000-8000-000000000008',
};

const _ddlPendingTransactions = '''
CREATE TABLE ${Tables.pendingTransactions} (
  id TEXT PRIMARY KEY, user_id TEXT NOT NULL,
  source TEXT NOT NULL CHECK (source IN ('SMS','IMAGE','TEXT')),
  masked_content TEXT, amount INTEGER,
  type TEXT CHECK (type IN ('INCOME','EXPENSE')),
  transaction_date TEXT, note TEXT, suggested_category_id TEXT, confidence REAL,
  source_hash TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'NEEDS_AI' CHECK (status IN ('NEEDS_AI','PENDING','CONFIRMED','REJECTED')),
  updated_at TEXT, UNIQUE (user_id, source_hash),
  FOREIGN KEY (user_id) REFERENCES ${Tables.users}(id),
  FOREIGN KEY (suggested_category_id) REFERENCES ${Tables.categories}(id)
)''';

/// Singleton SQLite handle. Schema is a direct translation of the SQL in
/// `DB_Flutter_Idea.md` (§3), including the local-only `sync_queue` table.
class DbHelper {
  DbHelper._internal();
  static final DbHelper instance = DbHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'personal_finance.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE ${Tables.wallets} ADD COLUMN opening_balance INTEGER NOT NULL DEFAULT 0');
      // Recover the original balance from the cached balance and its ledger.
      await db.execute('''UPDATE ${Tables.wallets}
             SET opening_balance = current_balance
               - COALESCE((SELECT SUM(amount) FROM ${Tables.transactions}
                   WHERE wallet_id = ${Tables.wallets}.id AND type = 'INCOME' AND is_deleted = 0), 0)
               + COALESCE((SELECT SUM(amount) FROM ${Tables.transactions}
                   WHERE wallet_id = ${Tables.wallets}.id AND type = 'EXPENSE' AND is_deleted = 0), 0)
               + COALESCE((SELECT SUM(amount) FROM ${Tables.transfers}
                   WHERE source_wallet_id = ${Tables.wallets}.id AND is_deleted = 0), 0)
               - COALESCE((SELECT SUM(amount) FROM ${Tables.transfers}
                   WHERE destination_wallet_id = ${Tables.wallets}.id AND is_deleted = 0), 0)''');
    }
    if (oldVersion < 3) {
      // Chuẩn hóa updated_at cũ (giờ local UTC+7, không có Z) sang UTC.
      for (final t in [
        Tables.users,
        Tables.wallets,
        Tables.categories,
        Tables.transactions,
        Tables.savingGoals,
        Tables.transfers,
        Tables.monthlyBudgets,
        Tables.pets,
        Tables.savingStreaks,
      ]) {
        await db.execute('''
          UPDATE $t SET updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', updated_at, '-7 hours')
          WHERE updated_at IS NOT NULL AND updated_at NOT LIKE '%Z'
        ''');
      }
      // Keep the newest active budget for each user/category/month tuple.
      // Sync sends the current row snapshot, including is_deleted, so no queue
      // entry is needed for these migration updates.
      await db.execute('''
        UPDATE ${Tables.monthlyBudgets} SET is_deleted = 1, updated_at = ?
        WHERE is_deleted = 0 AND EXISTS (
          SELECT 1 FROM ${Tables.monthlyBudgets} b2
          WHERE b2.user_id = ${Tables.monthlyBudgets}.user_id
            AND b2.category_id = ${Tables.monthlyBudgets}.category_id
            AND b2.month = ${Tables.monthlyBudgets}.month
            AND b2.is_deleted = 0 AND b2.id <> ${Tables.monthlyBudgets}.id
            AND (COALESCE(b2.updated_at, '') > COALESCE(${Tables.monthlyBudgets}.updated_at, '')
              OR (COALESCE(b2.updated_at, '') = COALESCE(${Tables.monthlyBudgets}.updated_at, '')
                  AND b2.id > ${Tables.monthlyBudgets}.id))
        )
      ''', [nowUtcIso()]);
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE ${Tables.transactions} ADD COLUMN source TEXT NOT NULL DEFAULT 'MANUAL' CHECK (source IN ('MANUAL','SMS','IMAGE','TEXT'))");
      await db.execute(_ddlPendingTransactions);
      await db.execute('UPDATE OR IGNORE ${Tables.users} SET email = lower(trim(email)) WHERE email IS NOT NULL');
    }
    await _createIndexes(db);
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    // Chỉ chặn trùng ở local; server hợp nhất theo khóa tự nhiên riêng.
    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS ux_budget_active ON ${Tables.monthlyBudgets}(user_id, category_id, month) WHERE is_deleted = 0');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS ix_tx_wallet ON ${Tables.transactions}(wallet_id, is_deleted)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS ix_tx_user_date ON ${Tables.transactions}(user_id, transaction_date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS ix_tf_src ON ${Tables.transfers}(source_wallet_id, is_deleted)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS ix_tf_dst ON ${Tables.transfers}(destination_wallet_id, is_deleted)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS ix_tf_goal ON ${Tables.transfers}(goal_id, is_deleted)');
    await db.execute('CREATE INDEX IF NOT EXISTS ix_pending_user_status ON ${Tables.pendingTransactions}(user_id, status)');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE ${Tables.users} (
        id TEXT PRIMARY KEY,
        full_name TEXT NOT NULL,
        email TEXT UNIQUE,
        password_hash TEXT NOT NULL,
        monthly_income INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE ${Tables.wallets} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        wallet_name TEXT NOT NULL,
        wallet_type TEXT NOT NULL,
        current_balance INTEGER DEFAULT 0,
        opening_balance INTEGER NOT NULL DEFAULT 0,
        color TEXT,
        icon TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES ${Tables.users}(id)
      )
    ''');

    batch.execute('''
      CREATE TABLE ${Tables.categories} (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        category_name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('INCOME','EXPENSE')),
        color TEXT,
        icon TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES ${Tables.users}(id)
      )
    ''');

    batch.execute('''
      CREATE TABLE ${Tables.transactions} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        wallet_id TEXT NOT NULL,
        category_id TEXT,
        type TEXT NOT NULL CHECK (type IN ('INCOME','EXPENSE')),
        amount INTEGER NOT NULL CHECK (amount > 0),
        note TEXT,
        transaction_date TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'MANUAL' CHECK (source IN ('MANUAL','SMS','IMAGE','TEXT')),
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES ${Tables.users}(id),
        FOREIGN KEY (wallet_id) REFERENCES ${Tables.wallets}(id),
        FOREIGN KEY (category_id) REFERENCES ${Tables.categories}(id)
      )
    ''');

    batch.execute('''
      CREATE TABLE ${Tables.savingGoals} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        wallet_id TEXT,
        goal_name TEXT NOT NULL,
        target_amount INTEGER NOT NULL,
        saved_amount INTEGER DEFAULT 0,
        expected_completion_date TEXT,
        status TEXT DEFAULT 'IN_PROGRESS',
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES ${Tables.users}(id),
        FOREIGN KEY (wallet_id) REFERENCES ${Tables.wallets}(id)
      )
    ''');

    batch.execute('''
      CREATE TABLE ${Tables.transfers} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        source_wallet_id TEXT NOT NULL,
        destination_wallet_id TEXT NOT NULL,
        goal_id TEXT,
        amount INTEGER NOT NULL CHECK (amount > 0),
        transfer_date TEXT NOT NULL,
        note TEXT,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES ${Tables.users}(id),
        FOREIGN KEY (source_wallet_id) REFERENCES ${Tables.wallets}(id),
        FOREIGN KEY (destination_wallet_id) REFERENCES ${Tables.wallets}(id),
        FOREIGN KEY (goal_id) REFERENCES ${Tables.savingGoals}(id)
      )
    ''');

    batch.execute('''
      CREATE TABLE ${Tables.monthlyBudgets} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        month TEXT NOT NULL,
        spending_limit INTEGER NOT NULL,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES ${Tables.users}(id),
        FOREIGN KEY (category_id) REFERENCES ${Tables.categories}(id)
      )
    ''');

    batch.execute('''
      CREATE TABLE ${Tables.pets} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        pet_name TEXT DEFAULT 'Mam Nho',
        level INTEGER DEFAULT 1,
        experience_points INTEGER DEFAULT 0,
        shape TEXT DEFAULT 'MEDIUM',
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES ${Tables.users}(id)
      )
    ''');

    batch.execute('''
      CREATE TABLE ${Tables.savingStreaks} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL UNIQUE,
        current_streak_days INTEGER DEFAULT 0,
        longest_streak INTEGER DEFAULT 0,
        last_saved_date TEXT,
        updated_at TEXT,
        FOREIGN KEY (user_id) REFERENCES ${Tables.users}(id)
      )
    ''');

    batch.execute('''
      CREATE TABLE ${Tables.aiSuggestions} (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        month TEXT NOT NULL,
        suggestion_content TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES ${Tables.users}(id)
      )
    ''');

    // Local-only table, never synced itself — tracks pending offline writes.
    batch.execute('''
      CREATE TABLE ${Tables.syncQueue} (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        record_id TEXT NOT NULL,
        action TEXT NOT NULL CHECK (action IN ('CREATE','UPDATE','DELETE')),
        is_synced INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    batch.execute(_ddlPendingTransactions);

    await batch.commit(noResult: true);
    await _createIndexes(db);
    await _seedDefaultCategories(db);
  }

  /// Seeds the system default categories (user_id = NULL, per design doc).
  Future<void> _seedDefaultCategories(Database db) async {
    const now = '2026-01-01T00:00:00.000Z';
    final defaults = <Map<String, dynamic>>[
      {
        'name': 'Lương',
        'type': 'INCOME',
        'icon': 'payments',
        'color': '#2E9E5B'
      },
      {
        'name': 'Thưởng',
        'type': 'INCOME',
        'icon': 'card_giftcard',
        'color': '#2E9E5B'
      },
      {
        'name': 'Ăn uống',
        'type': 'EXPENSE',
        'icon': 'restaurant',
        'color': '#E0554F'
      },
      {
        'name': 'Di chuyển',
        'type': 'EXPENSE',
        'icon': 'directions_car',
        'color': '#4C7DF0'
      },
      {
        'name': 'Mua sắm',
        'type': 'EXPENSE',
        'icon': 'shopping_bag',
        'color': '#F2A65A'
      },
      {
        'name': 'Hóa đơn',
        'type': 'EXPENSE',
        'icon': 'receipt_long',
        'color': '#9B59B6'
      },
      {
        'name': 'Giải trí',
        'type': 'EXPENSE',
        'icon': 'movie',
        'color': '#16A085'
      },
      {
        'name': 'Sức khỏe',
        'type': 'EXPENSE',
        'icon': 'favorite',
        'color': '#E67E22'
      },
    ];
    final batch = db.batch();
    for (final c in defaults) {
      batch.insert(Tables.categories, {
        'id':
            _systemCategoryIds[c['name']],
        'user_id': null,
        'category_name': c['name'],
        'type': c['type'],
        'color': c['color'],
        'icon': c['icon'],
        'updated_at': now,
        'is_deleted': 0,
      });
    }
    await batch.commit(noResult: true);
  }
}
