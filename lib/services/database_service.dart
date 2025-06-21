import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/item.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'storage_master.db');
    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        image_path TEXT,
        group_id INTEGER,
        category TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE items ADD COLUMN image_path TEXT;');
      await db.execute('ALTER TABLE items ADD COLUMN group_id INTEGER;');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE items ADD COLUMN category TEXT;');
    }
    if (oldVersion < 5) {
      // 版本5: 重建表结构，移除位置、标签、备注字段
      await db.execute('''
        CREATE TABLE items_new(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          created_at TEXT NOT NULL,
          image_path TEXT,
          group_id INTEGER,
          category TEXT
        )
      ''');
      
      // 迁移数据
      await db.execute('''
        INSERT INTO items_new(id, name, created_at, image_path, group_id, category)
        SELECT id, name, created_at, image_path, group_id, category FROM items
      ''');
      
      // 删除旧表
      await db.execute('DROP TABLE items');
      
      // 重命名新表
      await db.execute('ALTER TABLE items_new RENAME TO items');
    }
  }

  // 添加物品
  Future<int> insertItem(Item item) async {
    final db = await database;
    return await db.insert('items', item.toMap());
  }

  // 批量添加物品（同一张照片的多个物品）
  Future<List<int>> insertMultipleItems(List<Item> items) async {
    final db = await database;
    List<int> ids = [];
    
    await db.transaction((txn) async {
      for (var item in items) {
        int id = await txn.insert('items', item.toMap());
        ids.add(id);
      }
    });
    
    return ids;
  }

  // 获取所有物品
  Future<List<Item>> getAllItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('items');
    return List.generate(maps.length, (i) => Item.fromMap(maps[i]));
  }

  // 获取单个物品
  Future<Item?> getItem(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Item.fromMap(maps.first);
    }
    return null;
  }

  // 根据分组ID获取物品
  Future<List<Item>> getItemsByGroupId(int groupId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    return List.generate(maps.length, (i) => Item.fromMap(maps[i]));
  }

  // 获取下一个可用的分组ID
  Future<int> getNextGroupId() async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(group_id) as max_id FROM items');
    int? maxId = result.first['max_id'] as int?;
    return (maxId ?? 0) + 1;
  }

  // 更新物品信息
  Future<int> updateItem(Item item) async {
    final db = await database;
    return await db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  // 删除物品
  Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 删除同一组的所有物品
  Future<int> deleteItemsByGroupId(int groupId) async {
    final db = await database;
    return await db.delete(
      'items',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }

  // 搜索物品（按名称或类别）
  Future<List<Item>> searchItems(String query) async {
    final db = await database;
    final String searchPattern = '%$query%';
    
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: 'name LIKE ? OR category LIKE ?',
      whereArgs: [searchPattern, searchPattern],
    );
    
    return List.generate(maps.length, (i) => Item.fromMap(maps[i]));
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
} 