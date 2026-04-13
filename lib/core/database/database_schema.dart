import 'package:sqflite/sqflite.dart';

class DatabaseSchema {
  const DatabaseSchema._();

  static const version = 11;

  static Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        notes TEXT,
        time_label TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'normal',
        slot TEXT NOT NULL,
        repeat_pattern TEXT NOT NULL DEFAULT 'none',
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        next_reminder_at TEXT NOT NULL,
        reminder_interval_minutes INTEGER NOT NULL DEFAULT 180,
        reminder_intensity TEXT NOT NULL DEFAULT 'normal',
        ignored_count INTEGER NOT NULL DEFAULT 0,
        completion_rate REAL NOT NULL DEFAULT 0,
        last_reminder_at TEXT
      )
    ''');

    await _createShoppingSessionsTable(db);
    await _createShoppingItemsTable(db);

    await _createTaskLogsTable(db);
    await _createUserStatsTable(db);
    await _createAchievementsTable(db);
    await _ensureUserStatsRow(db);
  }

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN next_reminder_at TEXT NOT NULL DEFAULT '1970-01-01T00:00:00.000'",
      );
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN reminder_interval_minutes INTEGER NOT NULL DEFAULT 180",
      );
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN reminder_intensity TEXT NOT NULL DEFAULT 'normal'",
      );
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN ignored_count INTEGER NOT NULL DEFAULT 0",
      );
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN completion_rate REAL NOT NULL DEFAULT 0",
      );
      await db.execute("ALTER TABLE tasks ADD COLUMN last_reminder_at TEXT");
    }

    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN time_label TEXT NOT NULL DEFAULT '08:00'",
      );
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN repeat_pattern TEXT NOT NULL DEFAULT 'none'",
      );
    }

    if (oldVersion < 4) {
      await _recreateTaskLogsTableWithForeignKey(db);
    }

    if (oldVersion < 5) {
      await _createUserStatsTable(db);
      await _createAchievementsTable(db);
      await _ensureUserStatsRow(db);
    }

    if (oldVersion < 6) {
      await db.execute(
        "ALTER TABLE tasks ADD COLUMN type TEXT NOT NULL DEFAULT 'normal'",
      );
    }

    if (oldVersion < 7) {
      await _createShoppingItemsTable(db);
    }

    if (oldVersion < 8) {
      await _recreateTaskLogsTableForShoppingEvents(db);
    }

    if (oldVersion < 9) {
      await _createShoppingSessionsTable(db);
    }

    if (oldVersion < 10) {
      await _recreateShoppingItemsTableWithSessionLink(db);
    }

    if (oldVersion < 11) {
      await db.execute(
        'ALTER TABLE shopping_items ADD COLUMN quantity INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute('ALTER TABLE shopping_items ADD COLUMN unit_price REAL');
    }
  }

  static Future<void> _createShoppingItemsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL,
        is_completed INTEGER DEFAULT 0,
        linked_task_id TEXT,
        session_id TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(session_id) REFERENCES shopping_sessions(id) ON DELETE SET NULL
      )
    ''');
  }

  static Future<void> _createShoppingSessionsTable(
    DatabaseExecutor db,
  ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_sessions (
        id TEXT PRIMARY KEY,
        date DATE NOT NULL,
        title TEXT,
        status TEXT DEFAULT 'active',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  static Future<void> _recreateShoppingItemsTableWithSessionLink(
    Database db,
  ) async {
    await db.transaction((txn) async {
      await txn.execute('ALTER TABLE shopping_items RENAME TO shopping_items_old');
      await _createShoppingItemsTable(txn);
      await txn.execute('''
        INSERT INTO shopping_items (
          id,
          name,
          category,
          quantity,
          unit_price,
          is_completed,
          linked_task_id,
          session_id,
          created_at
        )
        SELECT
          id,
          name,
          category,
          1,
          NULL,
          is_completed,
          linked_task_id,
          NULL,
          created_at
        FROM shopping_items_old
      ''');
      await txn.execute('DROP TABLE shopping_items_old');
    });
  }

  static Future<void> _createTaskLogsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE task_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER,
        shopping_item_id TEXT,
        action TEXT NOT NULL,
        logged_at TEXT NOT NULL,
        metadata TEXT,
        FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _recreateTaskLogsTableForShoppingEvents(
    Database db,
  ) async {
    await db.transaction((txn) async {
      await txn.execute('ALTER TABLE task_logs RENAME TO task_logs_old');
      await _createTaskLogsTable(txn);
      await txn.execute('''
        INSERT INTO task_logs (id, task_id, shopping_item_id, action, logged_at, metadata)
        SELECT old.id, old.task_id, NULL, old.action, old.logged_at, old.metadata
        FROM task_logs_old old
        WHERE old.task_id IS NOT NULL
      ''');
      await txn.execute('DROP TABLE task_logs_old');
    });
  }

  static Future<void> _createUserStatsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_stats (
        id INTEGER PRIMARY KEY,
        current_streak INTEGER NOT NULL DEFAULT 0,
        longest_streak INTEGER NOT NULL DEFAULT 0,
        last_completed_date TEXT
      )
    ''');
  }

  static Future<void> _createAchievementsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS achievements (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        unlocked_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _ensureUserStatsRow(DatabaseExecutor db) async {
    await db.insert(
      'user_stats',
      {
        'id': 1,
        'current_streak': 0,
        'longest_streak': 0,
        'last_completed_date': null,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  static Future<void> _recreateTaskLogsTableWithForeignKey(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('ALTER TABLE task_logs RENAME TO task_logs_old');
      await _createTaskLogsTable(txn);
      await txn.execute('''
        INSERT INTO task_logs (id, task_id, action, logged_at, metadata)
        SELECT old.id, old.task_id, old.action, old.logged_at, old.metadata
        FROM task_logs_old old
        INNER JOIN tasks t ON t.id = old.task_id
      ''');
      await txn.execute('DROP TABLE task_logs_old');
    });
  }
}
