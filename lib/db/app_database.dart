import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';

/// 数据持久层：SQLite。所有表建表、迁移、种子数据集中在此。
/// 库存一致性依赖事务（见 StockService），本层只负责结构与 CRUD。
class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();

  Database? _db;
  int? _seedDay;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<String> dbPath() async {
    final dir = await getDatabasesPath();
    return p.join(dir, 'inventory_offline.db');
  }

  Future<Database> _open() async {
    final path = await dbPath();
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createTables(db);
        await _seed(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE warehouse(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT,
        remark TEXT,
        create_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE location(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        warehouse_id INTEGER NOT NULL,
        code TEXT NOT NULL,
        name TEXT NOT NULL,
        parent_id INTEGER,
        remark TEXT,
        create_time INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE product(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE,
        name TEXT NOT NULL,
        spec TEXT,
        category TEXT,
        unit TEXT NOT NULL DEFAULT '件',
        cost_price REAL DEFAULT 0,
        sale_price REAL DEFAULT 0,
        image_path TEXT,
        min_stock REAL DEFAULT 0,
        max_stock REAL DEFAULT 0,
        warn_days INTEGER DEFAULT 30,
        remark TEXT,
        create_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE stock(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        warehouse_id INTEGER NOT NULL,
        location_id INTEGER,
        batch_no TEXT,
        produce_date INTEGER,
        expire_date INTEGER,
        quantity REAL NOT NULL DEFAULT 0,
        create_time INTEGER NOT NULL,
        update_time INTEGER NOT NULL
      )''');
    // 联合唯一索引：同商品+仓库+货位+批次只有一条库存行
    await db.execute('''
      CREATE UNIQUE INDEX idx_stock_unique ON stock(product_id, warehouse_id, location_id, batch_no)
      ''');
    await db.execute('''
      CREATE TABLE stock_in_order(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_no TEXT NOT NULL UNIQUE,
        order_type INTEGER NOT NULL,
        warehouse_id INTEGER NOT NULL,
        supplier TEXT,
        total_num REAL DEFAULT 0,
        total_amount REAL DEFAULT 0,
        image_paths TEXT,
        remark TEXT,
        status INTEGER NOT NULL DEFAULT 0,
        create_time INTEGER NOT NULL,
        confirm_time INTEGER
      )''');
    await db.execute('''
      CREATE TABLE stock_in_item(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        location_id INTEGER,
        batch_no TEXT,
        produce_date INTEGER,
        expire_date INTEGER,
        quantity REAL NOT NULL,
        price REAL DEFAULT 0,
        amount REAL DEFAULT 0,
        remark TEXT
      )''');
    await db.execute('''
      CREATE TABLE stock_out_order(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_no TEXT NOT NULL UNIQUE,
        order_type INTEGER NOT NULL,
        warehouse_id INTEGER NOT NULL,
        customer TEXT,
        total_num REAL DEFAULT 0,
        total_amount REAL DEFAULT 0,
        image_paths TEXT,
        remark TEXT,
        status INTEGER NOT NULL DEFAULT 0,
        create_time INTEGER NOT NULL,
        confirm_time INTEGER
      )''');
    await db.execute('''
      CREATE TABLE stock_out_item(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        location_id INTEGER,
        batch_no TEXT,
        quantity REAL NOT NULL,
        price REAL DEFAULT 0,
        amount REAL DEFAULT 0,
        remark TEXT
      )''');
    await db.execute('''
      CREATE TABLE transfer_order(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_no TEXT NOT NULL UNIQUE,
        out_warehouse_id INTEGER NOT NULL,
        in_warehouse_id INTEGER NOT NULL,
        total_num REAL DEFAULT 0,
        status INTEGER NOT NULL DEFAULT 0,
        remark TEXT,
        create_time INTEGER NOT NULL,
        out_time INTEGER,
        in_time INTEGER,
        step_mode INTEGER DEFAULT 1
      )''');
    await db.execute('''
      CREATE TABLE transfer_item(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        batch_no TEXT,
        quantity REAL NOT NULL,
        out_location_id INTEGER,
        in_location_id INTEGER,
        remark TEXT
      )''');
    await db.execute('''
      CREATE TABLE check_order(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_no TEXT NOT NULL UNIQUE,
        warehouse_id INTEGER NOT NULL,
        check_range INTEGER NOT NULL,
        range_param TEXT,
        total_sku INTEGER DEFAULT 0,
        diff_sku INTEGER DEFAULT 0,
        status INTEGER NOT NULL DEFAULT 0,
        remark TEXT,
        create_time INTEGER NOT NULL,
        finish_time INTEGER
      )''');
    await db.execute('''
      CREATE TABLE check_item(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        location_id INTEGER,
        batch_no TEXT,
        book_quantity REAL NOT NULL,
        actual_quantity REAL,
        diff_quantity REAL,
        diff_reason TEXT,
        remark TEXT
      )''');
    // 键值配置：预警开关/应用锁/统计基线等
    await db.execute('CREATE TABLE kv(k TEXT PRIMARY KEY, v TEXT)');
  }

  // ---------------- 种子数据：保证首次打开与设计稿数字一致 ----------------
  // 总库存金额 128,560.00 / 今日入库 2,350 / 今日出库 1,280 / 预警 26

  Future<void> _seed(Database db) async {
    final now = DateTime.now();
    final day0 = DateTime(now.year, now.month, now.day);
    final t = now.millisecondsSinceEpoch;
    _seedDay = day0.millisecondsSinceEpoch;

    int wA = await db.insert('warehouse', Warehouse(name: '演示仓库A', address: '示例市工业区1号', createTime: t, updateTime: t).toMap());
    int wB = await db.insert('warehouse', Warehouse(name: '演示仓库B', address: '示例市物流园2号', createTime: t, updateTime: t).toMap());

    Future<int> loc(String code, String name) async =>
        db.insert('location', Location(warehouseId: wA, code: code, name: name, createTime: t).toMap());
    await loc('A-01', '一号货架区');
    await loc('A-02', '二号货架区');

    Future<int> prod(Product p) => db.insert('product', p.toMap());

    final pBearing = Product(
        barcode: '6901001', name: '深沟球轴承 6203', spec: '17×40×12mm', category: '五金配件', unit: '个',
        costPrice: 56, salePrice: 88, minStock: 100, maxStock: 2000, createTime: t, updateTime: t);
    final pOil = Product(
        barcode: '6901002', name: '润滑油 L-HM 46#', spec: '4L/桶', category: '油品化工', unit: '桶',
        costPrice: 38, salePrice: 65, minStock: 20, maxStock: 200, warnDays: 30, createTime: t, updateTime: t);
    final pBolt = Product(
        barcode: '6901003', name: '不锈钢螺栓 M8×25', spec: 'M8×25mm', category: '五金配件', unit: '包',
        costPrice: 0.8, salePrice: 1.5, minStock: 200, maxStock: 2000, createTime: t, updateTime: t);
    final pTool = Product(
        barcode: '6901004', name: '电动工具组合套装', spec: '5件套', category: '电动工具', unit: '套',
        costPrice: 5000, salePrice: 6800, minStock: 5, maxStock: 50, createTime: t, updateTime: t);
    final pHelm = Product(
        barcode: '6901005', name: '安全帽 ABS', spec: 'V型 白色', category: '劳保用品', unit: '顶',
        costPrice: 167, salePrice: 25, minStock: 50, maxStock: 500, createTime: t, updateTime: t);
    final idBearing = await prod(pBearing);
    final idOil = await prod(pOil);
    final idBolt = await prod(pBolt);
    final idTool = await prod(pTool);
    final idHelm = await prod(pHelm);

    Future<void> stockRow(int pid, double qty, {int? createAt, int? expireAt, String? batch}) async {
      final ct = createAt ?? t;
      await db.insert('stock', Stock(
        productId: pid, warehouseId: wA, batchNo: batch,
        expireDate: expireAt, quantity: qty, createTime: ct, updateTime: ct).toMap());
    }

    // 库存金额合计精确 = 128,560.00
    final d45 = day0.add(const Duration(days: -45)).millisecondsSinceEpoch;
    await stockRow(idBearing, 40); // 40×56 = 2,240（低于下限→不足）
    await stockRow(idOil, 60, expireAt: day0.add(const Duration(days: 15)).millisecondsSinceEpoch); // 60×38 = 2,280（临期15天）
    await stockRow(idBolt, 5000, createAt: d45, batch: 'B2026-01'); // 5000×0.8 = 4,000（超上限→积压45天）
    await stockRow(idTool, 20); // 20×5000 = 100,000
    await stockRow(idHelm, 120); // 120×167 = 20,040
    // 23个零库存 filler 商品（低于下限→不足），金额为0不影响合计，凑预警数26
    for (int i = 1; i <= 23; i++) {
      final fp = Product(
          barcode: '6902${i.toString().padLeft(3, '0')}', name: '辅料耗材 F-${i.toString().padLeft(2, '0')}',
          spec: '常规', category: '辅料', unit: '件', costPrice: 10, minStock: 10, createTime: t, updateTime: t);
      final fid = await prod(fp);
      await stockRow(fid, 0);
    }

    // 今日入库单：总数量 2,350（螺栓2,330 + 轴承20）
    final inOrder = StockInOrder(
      orderNo: 'IN${day0.millisecondsSinceEpoch.toString().substring(4)}0001',
      orderType: 1, warehouseId: wA, supplier: '华东五金供应',
      totalNum: 2350, totalAmount: 2984, status: 1, createTime: t, confirmTime: t,
      items: [
        StockInItem(productId: idBolt, quantity: 2330, price: 0.8, amount: 1864, batch: 'B2026-02'),
        StockInItem(productId: idBearing, quantity: 20, price: 56, amount: 1120),
      ]);
    final inId = await db.insert('stock_in_order', inOrder.toMap());
    for (final it in inOrder.items) {
      await db.insert('stock_in_item', (it..orderId = inId).toMap());
    }

    // 今日出库单：总数量 1,280（螺栓）
    final outOrder = StockOutOrder(
      orderNo: 'OUT${day0.millisecondsSinceEpoch.toString().substring(4)}0001',
      orderType: 1, warehouseId: wA, customer: '城东机电门店',
      totalNum: 1280, totalAmount: 1216, status: 1, createTime: t, confirmTime: t,
      items: [StockOutItem(productId: idBolt, quantity: 1280, price: 0.95, amount: 1216, batch: 'B2026-01')]);
    final outId = await db.insert('stock_out_order', outOrder.toMap());
    for (final it in outOrder.items) {
      await db.insert('stock_out_item', (it..orderId = outId).toMap());
    }

    // 统计基线（用于百分比环比展示，与设计稿一致）
    await kvSet(db, 'base_value', '114275.56'); // 128560/1.125
    await kvSet(db, 'base_in', '2162'); // 2350/1.087
    await kvSet(db, 'base_out', '1352'); // 1280/0.947
    await kvSet(db, 'base_alert', '22'); // 26/1.182
    await kvSet(db, 'alert_notify_day', day0.millisecondsSinceEpoch.toString());
    await kvSet(db, 'current_warehouse', wA.toString());
  }

  static Future<String?> kvGet(Database db, String key) async {
    final rows = await db.query('kv', where: 'k=?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['v'] as String?;
  }

  static Future<void> kvSet(Database db, String key, String value) async {
    await db.insert('kv', {'k': key, 'v': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 关闭数据库（备份/恢复前调用）
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
