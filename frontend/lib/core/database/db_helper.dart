import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
}

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
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
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

    await batch.commit(noResult: true);
    await _seedDefaultCategories(db);
  }

  /// Seeds the system default categories (user_id = NULL, per design doc).
  Future<void> _seedDefaultCategories(Database db) async {
    final now = DateTime.now().toIso8601String();
    final defaults = <Map<String, dynamic>>[
      {'name': 'Lương', 'type': 'INCOME', 'icon': 'payments', 'color': '#2E9E5B'},
      {'name': 'Thưởng', 'type': 'INCOME', 'icon': 'card_giftcard', 'color': '#2E9E5B'},
      {'name': 'Ăn uống', 'type': 'EXPENSE', 'icon': 'restaurant', 'color': '#E0554F'},
      {'name': 'Di chuyển', 'type': 'EXPENSE', 'icon': 'directions_car', 'color': '#4C7DF0'},
      {'name': 'Mua sắm', 'type': 'EXPENSE', 'icon': 'shopping_bag', 'color': '#F2A65A'},
      {'name': 'Hóa đơn', 'type': 'EXPENSE', 'icon': 'receipt_long', 'color': '#9B59B6'},
      {'name': 'Giải trí', 'type': 'EXPENSE', 'icon': 'movie', 'color': '#16A085'},
      {'name': 'Sức khỏe', 'type': 'EXPENSE', 'icon': 'favorite', 'color': '#E67E22'},
    ];
    final batch = db.batch();
    for (final c in defaults) {
      batch.insert(Tables.categories, {
        'id': 'default-${c['name'].toString().toLowerCase().replaceAll(' ', '-')}',
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
