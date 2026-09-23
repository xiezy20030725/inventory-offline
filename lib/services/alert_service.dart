import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';
import '../models/models.dart';

/// 库存预警服务：不足/积压/临期/过期 四类规则，纯本地计算与本地通知。
class AlertService {
  final AppDatabase _dbHelper = AppDatabase.instance;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _pluginReady = false;

  Future<Database> get _db => _dbHelper.database;

  /// 计算某仓库全部预警（商品维度 + 批次临期维度）
  Future<List<AlertInfo>> computeAlerts(int warehouseId) async {
    final db = await _db;
    final today0 = _dayStart(DateTime.now());
    final result = <AlertInfo>[];
    final rows = await db.rawQuery('''
      SELECT p.*, SUM(IFNULL(s.quantity,0)) AS total_qty
      FROM product p
      LEFT JOIN stock s ON s.product_id = p.id AND s.warehouse_id = ?
      GROUP BY p.id ORDER BY p.id ASC
    ''', [warehouseId]);
    for (final m in rows) {
      final product = Product.fromMap(m);
      final qty = ((m['total_qty'] ?? 0) as num).toDouble();
      if (product.minStock > 0 && qty < product.minStock) {
        result.add(AlertInfo(
            type: AlertInfo.typeInsufficient, product: product, stock: qty, limitValue: product.minStock));
        continue; // 同商品优先展示不足
      }
      if (product.maxStock > 0 && qty > product.maxStock) {
        // 积压天数：按该商品最早库存行创建日估算
        final srows = await db.query('stock',
            columns: ['MIN(create_time) AS t'],
            where: 'product_id=? AND warehouse_id=? AND quantity>0',
            whereArgs: [product.id, warehouseId]);
        final firstT = srows.first['t'] as int?;
        final days = firstT == null ? 0 : ((today0 - _dayStart(DateTime.fromMillisecondsSinceEpoch(firstT))) / 86400000).round();
        result.add(AlertInfo(
            type: AlertInfo.typeOver, product: product, stock: qty,
            limitValue: product.maxStock, overdueDays: days));
        continue;
      }
      // 临期/过期：按批次有效期
      final brows = await db.query('stock',
          where: 'product_id=? AND warehouse_id=? AND quantity>0 AND expire_date IS NOT NULL',
          whereArgs: [product.id, warehouseId]);
      for (final b in brows) {
        final exp = b['expire_date'] as int;
        final remain = ((_dayStart(DateTime.fromMillisecondsSinceEpoch(exp)) - today0) / 86400000).floor();
        if (remain < 0) {
          result.add(AlertInfo(type: AlertInfo.typeExpired, product: product, stock: qty, overdueDays: -remain));
        } else if (remain <= product.warnDays) {
          result.add(AlertInfo(type: AlertInfo.typeExpiring, product: product, stock: qty, remainDays: remain));
        }
        break; // 每商品取最早到期批次
      }
    }
    return result;
  }

  static int _dayStart(DateTime d) => DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;

  Future<void> _initPlugin() async {
    if (_pluginReady) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
      _pluginReady = true;
    } catch (_) {
      _pluginReady = false; // 通知失败不影响业务
    }
  }

  /// 每日一次的预警扫描 + 本地通知推送（离线可用）
  Future<int> dailyScanAndNotify(int warehouseId) async {
    final db = await _db;
    final alerts = await computeAlerts(warehouseId);
    final today = _dayStart(DateTime.now()).toString();
    final last = await AppDatabase.kvGet(db, 'alert_notify_day');
    if (alerts.isNotEmpty && last != today) {
      await _initPlugin();
      if (_pluginReady) {
        try {
          await _plugin.show(
            1001,
            '库存预警提醒',
            '当前共 ${alerts.length} 条库存预警，请及时处理',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'stock_alerts', '库存预警',
                channelDescription: '离线本地预警通知',
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: const DarwinNotificationDetails(),
            ),
          );
          await AppDatabase.kvSet(db, 'alert_notify_day', today);
        } catch (_) {}
      }
    }
    return alerts.length;
  }
}
