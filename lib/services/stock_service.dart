import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/models.dart';

/// 库存业务逻辑层：所有库存变动均通过数据库事务完成，异常自动回滚。
/// 出库成本按移动加权平均法核算。
class StockService {
  final AppDatabase _dbHelper = AppDatabase.instance;

  Future<Database> get _db => _dbHelper.database;

  // ---------------- 单号生成 ----------------

  Future<String> _nextNo(DatabaseExecutor tx, String prefix) async {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return '$prefix$stamp${now.millisecond.toString().padLeft(3, '0')}';
  }

  // ---------------- 商品/仓库 基础查询 ----------------

  Future<List<Product>> products({String keyword = ''}) async {
    final db = await _db;
    final rows = await db.query('product',
        where: keyword.isEmpty
            ? null
            : '(name LIKE ? OR IFNULL(barcode,"") LIKE ? OR IFNULL(spec,"") LIKE ? OR IFNULL(category,"") LIKE ?)',
        whereArgs: keyword.isEmpty ? null : List.filled(4, '%$keyword%'),
        orderBy: 'id DESC');
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> productByBarcode(String barcode) async {
    final db = await _db;
    final rows = await db.query('product', where: 'barcode=?', whereArgs: [barcode], limit: 1);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<Product?> productById(int id) async {
    final db = await _db;
    final rows = await db.query('product', where: 'id=?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<int> saveProduct(Product p) async {
    final db = await _db;
    if (p.id == null) return db.insert('product', p.toMap());
    await db.update('product', p.toMap(), where: 'id=?', whereArgs: [p.id]);
    return p.id!;
  }

  Future<void> deleteProduct(int id) async {
    final db = await _db;
    final rows = await db.query('stock', where: 'product_id=? AND quantity>0', whereArgs: [id], limit: 1);
    if (rows.isNotEmpty) throw Exception('该商品存在库存，不能删除');
    await db.transaction((tx) async {
      await tx.delete('product', where: 'id=?', whereArgs: [id]);
    });
  }

  Future<List<Warehouse>> warehouses() async {
    final db = await _db;
    final rows = await db.query('warehouse', orderBy: 'id ASC');
    return rows.map(Warehouse.fromMap).toList();
  }

  Future<int> saveWarehouse(Warehouse w) async {
    final db = await _db;
    if (w.id == null) return db.insert('warehouse', w.toMap());
    await db.update('warehouse', w.toMap(), where: 'id=?', whereArgs: [w.id]);
    return w.id!;
  }

  Future<void> deleteWarehouse(int id) async {
    final db = await _db;
    final rows = await db.query('stock', where: 'warehouse_id=? AND quantity>0', whereArgs: [id], limit: 1);
    if (rows.isNotEmpty) throw Exception('该仓库存在库存，不能删除');
    await db.transaction((tx) async {
      await tx.delete('location', where: 'warehouse_id=?', whereArgs: [id]);
      await tx.delete('warehouse', where: 'id=?', whereArgs: [id]);
    });
  }

  Future<List<Location>> locations(int warehouseId) async {
    final db = await _db;
    final rows = await db.query('location', where: 'warehouse_id=?', whereArgs: [warehouseId], orderBy: 'code ASC');
    return rows.map(Location.fromMap).toList();
  }

  Future<int> saveLocation(Location l) async {
    final db = await _db;
    if (l.id == null) return db.insert('location', l.toMap());
    await db.update('location', l.toMap(), where: 'id=?', whereArgs: [l.id]);
    return l.id!;
  }

  Future<void> deleteLocation(int id) async {
    final db = await _db;
    await db.delete('location', where: 'id=?', whereArgs: [id]);
  }

  // ---------------- 库存查询 ----------------

  /// 库存（含商品信息），warehouseId 为 null 时查询全部仓库；keyword 过滤商品
  Future<List<StockRow>> queryStock(int? warehouseId, {String keyword = ''}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT s.*, p.name AS p_name, p.unit AS p_unit, p.barcode AS p_barcode, p.spec AS p_spec,
             p.cost_price AS p_cost, p.min_stock AS p_min, p.max_stock AS p_max, p.image_path AS p_img,
             w.name AS w_name
      FROM stock s
      JOIN product p ON p.id = s.product_id
      JOIN warehouse w ON w.id = s.warehouse_id
      WHERE (? IS NULL OR s.warehouse_id = ?) AND s.quantity != 0
        AND (? = '' OR p.name LIKE ? OR IFNULL(p.barcode,'') LIKE ? OR IFNULL(p.spec,'') LIKE ?)
      ORDER BY p.name ASC
    ''', [warehouseId, warehouseId, keyword, '%$keyword%', '%$keyword%', '%$keyword%']);
    return rows.map((m) {
      final stock = Stock.fromMap(m);
      final product = Product(
        id: m['product_id'] as int,
        name: (m['p_name'] ?? '') as String,
        unit: (m['p_unit'] ?? '件') as String,
        barcode: m['p_barcode'] as String?,
        spec: m['p_spec'] as String?,
        costPrice: (m['p_cost'] ?? 0) is num ? (m['p_cost'] as num).toDouble() : 0,
        minStock: (m['p_min'] ?? 0) is num ? (m['p_min'] as num).toDouble() : 0,
        maxStock: (m['p_max'] ?? 0) is num ? (m['p_max'] as num).toDouble() : 0,
        imagePath: m['p_img'] as String?,
        createTime: 0,
        updateTime: 0,
      );
      return StockRow(stock, product, (m['w_name'] ?? '') as String,
          round2(stock.quantity * product.costPrice));
    }).toList();
  }

  /// 商品在某仓库的可用库存总量
  Future<double> availableQty(DatabaseExecutor tx, int productId, int warehouseId) async {
    final rows = await tx.query('stock',
        columns: ['SUM(quantity) AS q'],
        where: 'product_id=? AND warehouse_id=?',
        whereArgs: [productId, warehouseId]);
    final v = rows.first['q'] as num?;
    return v?.toDouble() ?? 0;
  }

  /// 商品全仓库总量
  Future<double> totalQtyAll(DatabaseExecutor tx, int productId) async {
    final rows = await tx.query('stock', columns: ['SUM(quantity) AS q'], where: 'product_id=?', whereArgs: [productId]);
    final v = rows.first['q'] as num?;
    return v?.toDouble() ?? 0;
  }

  // ---------------- 库存行原子增减 ----------------

  Future<void> _changeStock(DatabaseExecutor tx, StockInItem e, int warehouseId, double delta) async {
    final rows = await tx.query('stock',
        where: 'product_id=? AND warehouse_id=? AND IFNULL(location_id,-1)=? AND IFNULL(batch_no,"")=?',
        whereArgs: [e.productId, warehouseId, e.locationId ?? -1, e.batchNo ?? ''],
        limit: 1);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (rows.isEmpty) {
      if (delta <= 0) throw Exception('库存记录不存在，无法扣减');
      await tx.insert('stock', Stock(
        productId: e.productId, warehouseId: warehouseId, locationId: e.locationId,
        batchNo: e.batchNo, produceDate: e.produceDate, expireDate: e.expireDate,
        quantity: delta, createTime: now, updateTime: now).toMap());
    } else {
      final cur = (rows.first['quantity'] as num).toDouble();
      final next = cur + delta;
      if (next < -1e-9) throw Exception('库存不足，操作已回滚');
      await tx.update('stock', {'quantity': next, 'update_time': now},
          where: 'id=?', whereArgs: [rows.first['id'] as int]);
    }
  }

  // ---------------- 入库 ----------------

  Future<int> saveStockIn(StockInOrder order) async {
    final db = await _db;
    return db.transaction((tx) async {
      var no = order.orderNo;
      if (no.isEmpty) no = await _nextNo(tx, 'IN');
      final totalNum = order.items.fold<double>(0, (s, i) => s + i.quantity);
      final totalAmount = order.items.fold<double>(0, (s, i) => s + i.amount);
      final map = order..orderNo = no..totalNum = totalNum..totalAmount = round2(totalAmount);
      int id;
      if (order.id == null) {
        id = await tx.insert('stock_in_order', map.toMap());
      } else {
        id = order.id!;
        await tx.update('stock_in_order', map.toMap(), where: 'id=?', whereArgs: [id]);
        await tx.delete('stock_in_item', where: 'order_id=?', whereArgs: [id]);
      }
      for (final it in order.items) {
        await tx.insert('stock_in_item', (it..orderId = id).toMap());
      }
      return id;
    });
  }

  /// 确认入库：库存增加 + 采购类入库更新商品移动加权成本
  Future<void> confirmStockIn(int orderId) async {
    final db = await _db;
    await db.transaction((tx) async {
      final orows = await tx.query('stock_in_order', where: 'id=?', whereArgs: [orderId], limit: 1);
      if (orows.isEmpty) throw Exception('入库单不存在');
      final order = StockInOrder.fromMap(orows.first);
      if (order.status != 0) throw Exception('单据状态不允许确认');
      final irows = await tx.query('stock_in_item', where: 'order_id=?', whereArgs: [orderId]);
      final items = irows.map(StockInItem.fromMap).toList();
      for (final it in items) {
        await _changeStock(tx, it, order.warehouseId, it.quantity);
        // 移动加权平均成本：仅采购/退货入库且单价>0时更新
        if (it.price > 0 && (order.orderType == 1 || order.orderType == 2)) {
          final totalBefore = await totalQtyAll(tx, it.productId);
          final before = totalBefore - it.quantity;
          final prows = await tx.query('product', where: 'id=?', whereArgs: [it.productId], limit: 1);
          if (prows.isNotEmpty) {
            final oldCost = (prows.first['cost_price'] ?? 0) as num;
            final newCost = before + it.quantity > 0
                ? (before * oldCost.toDouble() + it.quantity * it.price) / (before + it.quantity)
                : it.price;
            await tx.update('product', {'cost_price': round2(newCost)},
                where: 'id=?', whereArgs: [it.productId]);
          }
        }
      }
      await tx.update('stock_in_order', {'status': 1, 'confirm_time': DateTime.now().millisecondsSinceEpoch},
          where: 'id=?', whereArgs: [orderId]);
    });
  }

  Future<void> voidStockIn(int orderId) async {
    final db = await _db;
    await db.transaction((tx) async {
      final orows = await tx.query('stock_in_order', where: 'id=?', whereArgs: [orderId], limit: 1);
      if (orows.isEmpty) throw Exception('入库单不存在');
      final status = orows.first['status'] as int;
      if (status == 1) throw Exception('已确认单据不能作废，请使用其他出库调整');
      await tx.update('stock_in_order', {'status': 2}, where: 'id=?', whereArgs: [orderId]);
    });
  }

  Future<List<StockInOrder>> stockInOrders({int? warehouseId, int? type, int? status, String keyword = ''}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT o.*, w.name AS warehouse_name FROM stock_in_order o
      JOIN warehouse w ON w.id = o.warehouse_id
      WHERE (? IS NULL OR o.warehouse_id = ?) AND (? IS NULL OR o.order_type = ?) AND (? IS NULL OR o.status = ?)
        AND (? = '' OR o.order_no LIKE ? OR IFNULL(o.supplier,'') LIKE ?)
      ORDER BY o.create_time DESC LIMIT 200
    ''', [
      warehouseId, warehouseId, type, type, status, status,
      keyword, '%$keyword%', '%$keyword%'
    ]);
    return rows.map(StockInOrder.fromMap).toList();
  }

  Future<StockInOrder> stockInDetail(int id) async {
    final db = await _db;
    final orows = await db.rawQuery(
        'SELECT o.*, w.name AS warehouse_name FROM stock_in_order o JOIN warehouse w ON w.id=o.warehouse_id WHERE o.id=?', [id]);
    if (orows.isEmpty) throw Exception('入库单不存在');
    final order = StockInOrder.fromMap(orows.first);
    final irows = await db.rawQuery('''
      SELECT i.*, p.name AS p_name, p.unit AS p_unit, p.spec AS p_spec FROM stock_in_item i
      JOIN product p ON p.id = i.product_id WHERE i.order_id=? ORDER BY i.id ASC
    ''', [id]);
    order.items = irows.map((m) {
      final it = StockInItem.fromMap(m);
      it.product = Product(
          id: it.productId,
          name: (m['p_name'] ?? '') as String,
          unit: (m['p_unit'] ?? '') as String,
          spec: m['p_spec'] as String?,
          createTime: 0, updateTime: 0);
      return it;
    }).toList();
    return order;
  }

  // ---------------- 出库 ----------------

  Future<int> saveStockOut(StockOutOrder order) async {
    final db = await _db;
    return db.transaction((tx) async {
      var no = order.orderNo;
      if (no.isEmpty) no = await _nextNo(tx, 'OUT');
      final totalNum = order.items.fold<double>(0, (s, i) => s + i.quantity);
      final totalAmount = order.items.fold<double>(0, (s, i) => s + i.amount);
      final map = order..orderNo = no..totalNum = totalNum..totalAmount = round2(totalAmount);
      int id;
      if (order.id == null) {
        id = await tx.insert('stock_out_order', map.toMap());
      } else {
        id = order.id!;
        await tx.update('stock_out_order', map.toMap(), where: 'id=?', whereArgs: [id]);
        await tx.delete('stock_out_item', where: 'order_id=?', whereArgs: [id]);
      }
      for (final it in order.items) {
        await tx.insert('stock_out_item', (it..orderId = id).toMap());
      }
      return id;
    });
  }

  /// 确认出库：库存校验 → 按批次先进先出扣减 → 移动加权成本核算金额
  Future<void> confirmStockOut(int orderId) async {
    final db = await _db;
    await db.transaction((tx) async {
      final orows = await tx.query('stock_out_order', where: 'id=?', whereArgs: [orderId], limit: 1);
      if (orows.isEmpty) throw Exception('出库单不存在');
      final order = StockOutOrder.fromMap(orows.first);
      if (order.status != 0) throw Exception('单据状态不允许确认');
      final irows = await tx.query('stock_out_item', where: 'order_id=?', whereArgs: [orderId]);
      final items = irows.map(StockOutItem.fromMap).toList();

      for (final it in items) {
        final available = await availableQty(tx, it.productId, order.warehouseId);
        final prows = await tx.query('product', where: 'id=?', whereArgs: [it.productId], limit: 1);
        final pname = prows.isEmpty ? it.productId.toString() : (prows.first['name'] ?? '') as String;
        if (available + 1e-9 < it.quantity) {
          throw Exception('库存不足：$pname 可用 ${fmtQty(available)}，需 ${fmtQty(it.quantity)}');
        }
        final cost = prows.isEmpty ? 0.0 : ((prows.first['cost_price'] ?? 0) as num).toDouble();
        it.price = it.price > 0 ? it.price : round2(cost);
        it.amount = round2(it.price * it.quantity);
        // 先指定批次扣减，不足部分按先进先出（有效期优先）继续扣
        double remain = it.quantity;
        if ((it.batchNo ?? '').isNotEmpty) {
          final bRows = await tx.query('stock',
              where: 'product_id=? AND warehouse_id=? AND IFNULL(batch_no,"")=? AND quantity>0',
              whereArgs: [it.productId, order.warehouseId, it.batchNo],
              orderBy: '(expire_date IS NULL) ASC, expire_date ASC, create_time ASC');
          remain = await _deductRows(tx, bRows, remain, order.warehouseId);
        }
        if (remain > 1e-9) {
          final rows = await tx.query('stock',
              where: 'product_id=? AND warehouse_id=? AND quantity>0',
              whereArgs: [it.productId, order.warehouseId],
              orderBy: '(expire_date IS NULL) ASC, expire_date ASC, create_time ASC');
          remain = await _deductRows(tx, rows, remain, order.warehouseId);
        }
      }
      await tx.update('stock_out_order',
          {'status': 1, 'confirm_time': DateTime.now().millisecondsSinceEpoch}, where: 'id=?', whereArgs: [orderId]);
    });
  }

  /// 按 FIFO 依次扣减库存行，返回剩余未扣数量
  Future<double> _deductRows(DatabaseExecutor tx, List<Map<String, Object?>> rows, double remain, int warehouseId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final r in rows) {
      if (remain <= 1e-9) break;
      final q = (r['quantity'] as num).toDouble();
      final cut = q >= remain ? remain : q;
      await tx.update('stock', {'quantity': q - cut, 'update_time': now},
          where: 'id=?', whereArgs: [r['id'] as int]);
      remain -= cut;
    }
    return remain;
  }

  Future<void> voidStockOut(int orderId) async {
    final db = await _db;
    await db.transaction((tx) async {
      final orows = await tx.query('stock_out_order', where: 'id=?', whereArgs: [orderId], limit: 1);
      if (orows.isEmpty) throw Exception('出库单不存在');
      if ((orows.first['status'] as int) == 1) throw Exception('已确认单据不能作废');
      await tx.update('stock_out_order', {'status': 2}, where: 'id=?', whereArgs: [orderId]);
    });
  }

  Future<List<StockOutOrder>> stockOutOrders({int? warehouseId, int? type, int? status, String keyword = ''}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT o.*, w.name AS warehouse_name FROM stock_out_order o
      JOIN warehouse w ON w.id = o.warehouse_id
      WHERE (? IS NULL OR o.warehouse_id = ?) AND (? IS NULL OR o.order_type = ?) AND (? IS NULL OR o.status = ?)
        AND (? = '' OR o.order_no LIKE ? OR IFNULL(o.customer,'') LIKE ?)
      ORDER BY o.create_time DESC LIMIT 200
    ''', [
      warehouseId, warehouseId, type, type, status, status,
      keyword, '%$keyword%', '%$keyword%'
    ]);
    return rows.map(StockOutOrder.fromMap).toList();
  }

  Future<StockOutOrder> stockOutDetail(int id) async {
    final db = await _db;
    final orows = await db.rawQuery(
        'SELECT o.*, w.name AS warehouse_name FROM stock_out_order o JOIN warehouse w ON w.id=o.warehouse_id WHERE o.id=?', [id]);
    if (orows.isEmpty) throw Exception('出库单不存在');
    final order = StockOutOrder.fromMap(orows.first);
    final irows = await db.rawQuery('''
      SELECT i.*, p.name AS p_name, p.unit AS p_unit, p.spec AS p_spec FROM stock_out_item i
      JOIN product p ON p.id = i.product_id WHERE i.order_id=? ORDER BY i.id ASC
    ''', [id]);
    order.items = irows.map((m) {
      final it = StockOutItem.fromMap(m);
      it.product = Product(
          id: it.productId,
          name: (m['p_name'] ?? '') as String,
          unit: (m['p_unit'] ?? '') as String,
          spec: m['p_spec'] as String?,
          createTime: 0, updateTime: 0);
      return it;
    }).toList();
    return order;
  }

  // ---------------- 调拨 ----------------

  Future<int> saveTransfer(TransferOrder order) async {
    final db = await _db;
    return db.transaction((tx) async {
      var no = order.orderNo;
      if (no.isEmpty) no = await _nextNo(tx, 'TR');
      final totalNum = order.items.fold<double>(0, (s, i) => s + i.quantity);
      final map = order..orderNo = no..totalNum = totalNum;
      int id;
      if (order.id == null) {
        id = await tx.insert('transfer_order', map.toMap());
      } else {
        id = order.id!;
        await tx.update('transfer_order', map.toMap(), where: 'id=?', whereArgs: [id]);
        await tx.delete('transfer_item', where: 'order_id=?', whereArgs: [id]);
      }
      for (final it in order.items) {
        await tx.insert('transfer_item', (it..orderId = id).toMap());
      }
      return id;
    });
  }

  /// 调拨确认：一步调拨直接完成双向变动；两步调拨先扣调出仓（在途），再确认调入
  Future<void> confirmTransferOut(int orderId) async {
    final db = await _db;
    await db.transaction((tx) async {
      final order = await _transferOrThrow(tx, orderId, expectStatus: 0);
      final items = await _transferItems(tx, orderId);
      for (final it in items) {
        final available = await availableQty(tx, it.productId, order.outWarehouseId);
        if (available + 1e-9 < it.quantity) {
          final prows = await tx.query('product', where: 'id=?', whereArgs: [it.productId], limit: 1);
          final pname = prows.isEmpty ? '?' : (prows.first['name'] ?? '') as String;
          throw Exception('调出仓库存不足：$pname');
        }
        await _changeStock(tx, StockInItem(productId: it.productId, quantity: it.quantity,
            locationId: it.outLocationId, batchNo: it.batchNo), order.outWarehouseId, -it.quantity);
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final nextStatus = order.stepMode == 1 ? 2 : 1;
      await tx.update('transfer_order',
          {'status': nextStatus, 'out_time': now, if (order.stepMode == 1) 'in_time': now},
          where: 'id=?', whereArgs: [orderId]);
    });
  }

  Future<void> confirmTransferIn(int orderId) async {
    final db = await _db;
    await db.transaction((tx) async {
      final order = await _transferOrThrow(tx, orderId, expectStatus: 1);
      final items = await _transferItems(tx, orderId);
      for (final it in items) {
        await _changeStock(tx, StockInItem(productId: it.productId, quantity: it.quantity,
            locationId: it.inLocationId, batchNo: it.batchNo,
            produceDate: null, expireDate: null), order.inWarehouseId, it.quantity);
      }
      await tx.update('transfer_order', {'status': 2, 'in_time': DateTime.now().millisecondsSinceEpoch},
          where: 'id=?', whereArgs: [orderId]);
    });
  }

  Future<TransferOrder> _transferOrThrow(DatabaseExecutor tx, int id, {required int expectStatus}) async {
    final rows = await tx.query('transfer_order', where: 'id=?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw Exception('调拨单不存在');
    final order = TransferOrder.fromMap(rows.first);
    final allowed = order.stepMode == 1 ? [0] : [expectStatus];
    if (!allowed.contains(order.status)) throw Exception('调拨单状态不允许该操作');
    return order;
  }

  Future<List<TransferItem>> _transferItems(DatabaseExecutor tx, int orderId) async {
    final rows = await tx.query('transfer_item', where: 'order_id=?', whereArgs: [orderId]);
    return rows.map(TransferItem.fromMap).toList();
  }

  Future<void> voidTransfer(int orderId) async {
    final db = await _db;
    await db.transaction((tx) async {
      final rows = await tx.query('transfer_order', where: 'id=?', whereArgs: [orderId], limit: 1);
      if (rows.isEmpty) throw Exception('调拨单不存在');
      if ((rows.first['status'] as int) >= 1) throw Exception('已调出单据不能作废');
      await tx.update('transfer_order', {'status': 3}, where: 'id=?', whereArgs: [orderId]);
    });
  }

  Future<List<TransferOrder>> transferOrders({int? warehouseId, int? status}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT o.*, wo.name AS out_wh_name, wi.name AS in_wh_name FROM transfer_order o
      JOIN warehouse wo ON wo.id = o.out_warehouse_id
      JOIN warehouse wi ON wi.id = o.in_warehouse_id
      WHERE (? IS NULL OR o.out_warehouse_id = ? OR o.in_warehouse_id = ?) AND (? IS NULL OR o.status = ?)
      ORDER BY o.create_time DESC LIMIT 200
    ''', [warehouseId, warehouseId, warehouseId, status, status]);
    return rows.map(TransferOrder.fromMap).toList();
  }

  Future<TransferOrder> transferDetail(int id) async {
    final db = await _db;
    final orows = await db.rawQuery('''
      SELECT o.*, wo.name AS out_wh_name, wi.name AS in_wh_name FROM transfer_order o
      JOIN warehouse wo ON wo.id=o.out_warehouse_id JOIN warehouse wi ON wi.id=o.in_warehouse_id WHERE o.id=?
    ''', [id]);
    if (orows.isEmpty) throw Exception('调拨单不存在');
    final order = TransferOrder.fromMap(orows.first);
    final irows = await db.rawQuery('''
      SELECT i.*, p.name AS p_name, p.unit AS p_unit FROM transfer_item i
      JOIN product p ON p.id = i.product_id WHERE i.order_id=? ORDER BY i.id ASC
    ''', [id]);
    order.items = irows.map((m) {
      final it = TransferItem.fromMap(m);
      it.product = Product(
          id: it.productId,
          name: (m['p_name'] ?? '') as String,
          unit: (m['p_unit'] ?? '') as String,
          createTime: 0, updateTime: 0);
      return it;
    }).toList();
    return order;
  }

  /// 在途库存：两步调拨已调出未调入的商品
  Future<List<Map<String, dynamic>>> inTransitStock(int warehouseId) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT i.product_id, p.name, p.unit, SUM(i.quantity) AS qty
      FROM transfer_item i
      JOIN transfer_order o ON o.id = i.order_id AND o.status = 1
      JOIN product p ON p.id = i.product_id
      WHERE o.out_warehouse_id = ?
      GROUP BY i.product_id ORDER BY qty DESC
    ''', [warehouseId]);
  }

  // ---------------- 盘点 ----------------

  /// 创建盘点单：锁定账面库存快照（按范围过滤）
  Future<int> createCheckOrder(CheckOrder order) async {
    final db = await _db;
    return db.transaction((tx) async {
      final no = await _nextNo(tx, 'CK');
      final o = order..orderNo = no;
      final id = await tx.insert('check_order', o.toMap());
      final where = ['s.warehouse_id = ?', 's.quantity != 0'];
      final args = <Object?>[order.warehouseId];
      if (order.checkRange == 2 && (order.rangeParam ?? '').isNotEmpty) {
        where.add('IFNULL(s.location_id,-1) = ?');
        args.add(int.tryParse(order.rangeParam!) ?? -1);
      }
      if (order.checkRange == 3 && (order.rangeParam ?? '').isNotEmpty) {
        where.add('p.category = ?');
        args.add(order.rangeParam);
      }
      final rows = await tx.rawQuery('''
        SELECT s.product_id, s.location_id, s.batch_no, s.quantity FROM stock s
        JOIN product p ON p.id = s.product_id
        WHERE ${where.join(' AND ')}
      ''', args);
      // 同商品聚合为一行账面快照（保留首批次信息）
      final Map<int, Map<String, Object?>> agg = {};
      for (final r in rows) {
        final pid = r['product_id'] as int;
        if (agg.containsKey(pid)) {
          agg[pid]!['book_quantity'] = (agg[pid]!['book_quantity']! as num).toDouble() + (r['quantity']! as num).toDouble();
        } else {
          agg[pid] = {
            'product_id': pid,
            'location_id': r['location_id'],
            'batch_no': r['batch_no'],
            'book_quantity': (r['quantity']! as num).toDouble(),
          };
        }
      }
      for (final e in agg.entries) {
        await tx.insert('check_item', CheckItem(
          orderId: id, productId: e.value['product_id'] as int,
          locationId: e.value['location_id'] as int?, batchNo: e.value['batch_no'] as String?,
          bookQuantity: (e.value['book_quantity']! as num).toDouble()).toMap());
      }
      await tx.update('check_order', {'total_sku': agg.length}, where: 'id=?', whereArgs: [id]);
      return id;
    });
  }

  Future<void> saveCheckActual(int itemId, double actual, {String? reason}) async {
    final db = await _db;
    final rows = await db.query('check_item', where: 'id=?', whereArgs: [itemId], limit: 1);
    if (rows.isEmpty) throw Exception('盘点明细不存在');
    final book = (rows.first['book_quantity'] as num).toDouble();
    await db.update('check_item',
        {'actual_quantity': actual, 'diff_quantity': round2(actual - book), 'diff_reason': reason},
        where: 'id=?', whereArgs: [itemId]);
  }

  /// 盘点确认：按差异调整库存，并自动生成盘盈/盘亏单据留痕
  Future<void> confirmCheck(int orderId) async {
    final db = await _db;
    await db.transaction((tx) async {
      final orows = await tx.query('check_order', where: 'id=?', whereArgs: [orderId], limit: 1);
      if (orows.isEmpty) throw Exception('盘点单不存在');
      final order = CheckOrder.fromMap(orows.first);
      if (order.status != 0) throw Exception('盘点单状态不允许确认');
      final irows = await tx.query('check_item', where: 'order_id=?', whereArgs: [orderId]);
      final items = irows.map(CheckItem.fromMap).toList();
      int diffSku = 0;
      final gains = <StockInItem>[];
      final losses = <StockOutItem>[];
      for (final it in items) {
        if (it.actualQuantity == null) continue; // 未盘商品不动库存
        final diff = round2(it.actualQuantity! - it.bookQuantity);
        if (diff.abs() > 1e-9) {
          diffSku++;
          await _changeStock(tx, StockInItem(
              productId: it.productId, quantity: 0, locationId: it.locationId, batchNo: it.batchNo),
              order.warehouseId, diff);
          if (diff > 0) {
            gains.add(StockInItem(productId: it.productId, quantity: diff));
          } else {
            losses.add(StockOutItem(productId: it.productId, quantity: -diff));
          }
        }
      }
      await tx.update('check_order',
          {'status': 1, 'diff_sku': diffSku, 'finish_time': DateTime.now().millisecondsSinceEpoch},
          where: 'id=?', whereArgs: [orderId]);
      // 生成盘盈/盘亏留痕单据
      if (gains.isNotEmpty) {
        final o = StockInOrder(
            orderNo: '', orderType: 3, warehouseId: order.warehouseId,
            supplier: '盘点单${order.orderNo}', status: 1,
            createTime: DateTime.now().millisecondsSinceEpoch,
            confirmTime: DateTime.now().millisecondsSinceEpoch,
            remark: '盘点盘盈自动生成',
            items: gains);
        await tx.insert('stock_in_order', (o..totalNum = gains.fold(0.0, (s, i) => s + i.quantity)).toMap());
        final oid = (await tx.query('stock_in_order', orderBy: 'id DESC', limit: 1)).first['id'] as int;
        for (final i in gains) {
          await tx.insert('stock_in_item', (i..orderId = oid).toMap());
        }
      }
      if (losses.isNotEmpty) {
        final o = StockOutOrder(
            orderNo: '', orderType: 4, warehouseId: order.warehouseId,
            customer: '盘点单${order.orderNo}', status: 1,
            createTime: DateTime.now().millisecondsSinceEpoch,
            confirmTime: DateTime.now().millisecondsSinceEpoch,
            remark: '盘点盘亏自动生成',
            items: losses);
        await tx.insert('stock_out_order', (o..totalNum = losses.fold(0.0, (s, i) => s + i.quantity)).toMap());
        final oid = (await tx.query('stock_out_order', orderBy: 'id DESC', limit: 1)).first['id'] as int;
        for (final i in losses) {
          await tx.insert('stock_out_item', (i..orderId = oid).toMap());
        }
      }
    });
  }

  Future<void> voidCheck(int orderId) async {
    final db = await _db;
    await db.transaction((tx) async {
      final rows = await tx.query('check_order', where: 'id=?', whereArgs: [orderId], limit: 1);
      if (rows.isEmpty) throw Exception('盘点单不存在');
      if ((rows.first['status'] as int) != 0) throw Exception('仅进行中的盘点单可作废');
      await tx.update('check_order', {'status': 2}, where: 'id=?', whereArgs: [orderId]);
    });
  }

  Future<List<CheckOrder>> checkOrders({int? warehouseId, int? status}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT o.*, w.name AS warehouse_name FROM check_order o
      JOIN warehouse w ON w.id = o.warehouse_id
      WHERE (? IS NULL OR o.warehouse_id = ?) AND (? IS NULL OR o.status = ?)
      ORDER BY o.create_time DESC LIMIT 200
    ''', [warehouseId, warehouseId, status, status]);
    return rows.map(CheckOrder.fromMap).toList();
  }

  Future<CheckOrder> checkDetail(int id) async {
    final db = await _db;
    final orows = await db.rawQuery(
        'SELECT o.*, w.name AS warehouse_name FROM check_order o JOIN warehouse w ON w.id=o.warehouse_id WHERE o.id=?', [id]);
    if (orows.isEmpty) throw Exception('盘点单不存在');
    final order = CheckOrder.fromMap(orows.first);
    final irows = await db.rawQuery('''
      SELECT i.*, p.name AS p_name, p.unit AS p_unit, p.spec AS p_spec FROM check_item i
      JOIN product p ON p.id = i.product_id WHERE i.order_id=? ORDER BY i.id ASC
    ''', [id]);
    order.items = irows.map((m) {
      final it = CheckItem.fromMap(m);
      it.product = Product(
          id: it.productId,
          name: (m['p_name'] ?? '') as String,
          unit: (m['p_unit'] ?? '') as String,
          spec: m['p_spec'] as String?,
          createTime: 0, updateTime: 0);
      return it;
    }).toList();
    return order;
  }
}
