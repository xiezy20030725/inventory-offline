import 'package:flutter/foundation.dart';
import '../db/app_database.dart';
import '../models/models.dart';
import '../services/alert_service.dart';
import '../services/stock_service.dart';

/// 全局状态：当前仓库、首页统计、预警列表。
/// 业务页面操作完成后调用 [refreshHome] 即可全局刷新。
class AppState extends ChangeNotifier {
  final StockService stock = StockService();
  final AlertService alert = AlertService();

  List<Warehouse> warehouses = [];
  int currentWarehouseId = 0;
  HomeStats stats = HomeStats();
  List<AlertInfo> alerts = [];

  String get currentWarehouseName =>
      warehouses.isEmpty ? '演示仓库A' : warehouses.firstWhere((w) => w.id == currentWarehouseId, orElse: () => warehouses.first).name;

  Future<void> init() async {
    warehouses = await stock.warehouses();
    final db = await AppDatabase.instance.database;
    final saved = await AppDatabase.kvGet(db, 'current_warehouse');
    currentWarehouseId = int.tryParse(saved ?? '') ?? (warehouses.isEmpty ? 0 : warehouses.first.id!);
    if (warehouses.isNotEmpty && !warehouses.any((w) => w.id == currentWarehouseId)) {
      currentWarehouseId = warehouses.first.id!;
    }
    await refreshHome();
    // 每次启动执行一次本地预警扫描（当日只通知一次）
    if (currentWarehouseId > 0) {
      await alert.dailyScanAndNotify(currentWarehouseId);
    }
  }

  Future<void> switchWarehouse(int id) async {
    currentWarehouseId = id;
    final db = await AppDatabase.instance.database;
    await AppDatabase.kvSet(db, 'current_warehouse', id.toString());
    await refreshHome();
  }

  /// 重新计算首页统计与预警（含与基线环比）
  Future<void> refreshHome() async {
    if (warehouses.isEmpty) {
      warehouses = await stock.warehouses();
      if (warehouses.isNotEmpty && currentWarehouseId == 0) currentWarehouseId = warehouses.first.id!;
    }
    if (currentWarehouseId == 0) return;
    final db = await AppDatabase.instance.database;

    // 总库存金额 = Σ(数量×成本价)，当前仓库
    final valueRows = await db.rawQuery('''
      SELECT SUM(s.quantity * p.cost_price) AS v FROM stock s JOIN product p ON p.id = s.product_id
      WHERE s.warehouse_id = ?
    ''', [currentWarehouseId]);
    final totalValue = ((valueRows.first['v'] ?? 0) as num).toDouble();

    // 今日出入库数量（当前仓库，已确认）
    final dayStart = DateTime.now(); final d0 = DateTime(dayStart.year, dayStart.month, dayStart.day).millisecondsSinceEpoch;
    final inRow = await db.rawQuery(
        'SELECT IFNULL(SUM(total_num),0) AS q FROM stock_in_order WHERE warehouse_id=? AND status=1 AND confirm_time>=?',
        [currentWarehouseId, d0]);
    final outRow = await db.rawQuery(
        'SELECT IFNULL(SUM(total_num),0) AS q FROM stock_out_order WHERE warehouse_id=? AND status=1 AND confirm_time>=?',
        [currentWarehouseId, d0]);
    final todayIn = ((inRow.first['q'] ?? 0) as num).toDouble();
    final todayOut = ((outRow.first['q'] ?? 0) as num).toDouble();

    alerts = await alert.computeAlerts(currentWarehouseId);
    final alertCount = alerts.length;

    double baseValue = 0, baseIn = 0, baseOut = 0, baseAlert = 0;
    double? bv = double.tryParse(await AppDatabase.kvGet(db, 'base_value') ?? '');
    double? bi = double.tryParse(await AppDatabase.kvGet(db, 'base_in') ?? '');
    double? bo = double.tryParse(await AppDatabase.kvGet(db, 'base_out') ?? '');
    double? ba = double.tryParse(await AppDatabase.kvGet(db, 'base_alert') ?? '');
    baseValue = bv ?? 0; baseIn = bi ?? 0; baseOut = bo ?? 0; baseAlert = ba ?? 0;

    stats = HomeStats(
      totalValue: round2(totalValue),
      totalValueDelta: HomeStats.pct(totalValue, baseValue),
      todayInNum: todayIn,
      todayInDelta: HomeStats.pct(todayIn, baseIn),
      todayOutNum: todayOut,
      todayOutDelta: HomeStats.pct(todayOut, baseOut),
      alertCount: alertCount,
      alertDelta: HomeStats.pct(alertCount.toDouble(), baseAlert),
    );
    notifyListeners();
  }
}
