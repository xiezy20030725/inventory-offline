import 'dart:convert';
import 'dart:io';
import '../db/app_database.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 数据备份与恢复 + CSV 导出（全部本地文件操作，离线可用）
class BackupService {
  final AppDatabase _dbHelper = AppDatabase.instance;

  Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _exportDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 手动备份：复制数据库文件到应用文档目录
  Future<String> backup() async {
    final dbFile = File(await _dbHelper.dbPath());
    if (!await dbFile.exists()) throw Exception('数据库文件不存在');
    await _dbHelper.close();
    final ts = DateTime.now();
    final name = 'backup_${ts.year}${_p2(ts.month)}${_p2(ts.day)}_${_p2(ts.hour)}${_p2(ts.minute)}${_p2(ts.second)}.db';
    final target = p.join((await _backupDir()).path, name);
    await dbFile.copy(target);
    return target;
  }

  Future<List<FileSystemEntity>> backups() async {
    final dir = await _backupDir();
    final list = await dir.list().toList();
    list.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return list;
  }

  /// 恢复：恢复前先自动做一份安全备份，再覆盖当前数据库
  Future<void> restore(String backupPath) async {
    final dbFile = File(await _dbHelper.dbPath());
    if (await dbFile.exists()) {
      await backup();
      await _dbHelper.close();
      await dbFile.delete();
    } else {
      await _dbHelper.close();
    }
    await File(backupPath).copy(dbFile.path);
  }

  Future<void> deleteBackup(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  /// 导出商品档案 CSV
  Future<String> exportProductsCsv() async {
    final db = await _dbHelper.database;
    final rows = await db.query('product', orderBy: 'id ASC');
    final sb = StringBuffer('ID,条码,名称,规格,分类,单位,成本价,售价,库存下限,库存上限,临期天数\n');
    for (final r in rows) {
      sb.writeln([
        r['id'], _csv(r['barcode']), _csv(r['name']), _csv(r['spec']), _csv(r['category']), _csv(r['unit']),
        r['cost_price'] ?? 0, r['sale_price'] ?? 0, r['min_stock'] ?? 0, r['max_stock'] ?? 0, r['warn_days'] ?? 30,
      ].join(','));
    }
    return _write('products_${_stamp()}.csv', sb.toString());
  }

  /// 导出库存明细 CSV
  Future<String> exportStockCsv() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT w.name AS wn, p.name AS pn, p.barcode, p.spec, p.unit, p.cost_price, s.quantity, s.batch_no
      FROM stock s JOIN product p ON p.id=s.product_id JOIN warehouse w ON w.id=s.warehouse_id
      ORDER BY w.name, p.name
    ''');
    final sb = StringBuffer('仓库,商品,条码,规格,单位,成本价,库存数量,批次,库存金额\n');
    for (final r in rows) {
      final qty = (r['quantity'] ?? 0) as num;
      final cost = (r['cost_price'] ?? 0) as num;
      sb.writeln([
        _csv(r['wn']), _csv(r['pn']), _csv(r['barcode']), _csv(r['spec']), _csv(r['unit']),
        cost, qty, _csv(r['batch_no']), (qty * cost).toStringAsFixed(2),
      ].join(','));
    }
    return _write('stock_${_stamp()}.csv', sb.toString());
  }

  Future<String> _write(String name, String content) async {
    final file = File(p.join((await _exportDir()).path, name));
    // BOM 头保证 Excel 打开中文不乱码
    await file.writeAsString('\uFEFF$content', encoding: utf8);
    return file.path;
  }

  static String _csv(dynamic v) {
    final s = (v ?? '').toString();
    return s.contains(',') || s.contains('"') || s.contains('\n') ? '"${s.replaceAll('"', '""')}"' : s;
  }

  static String _p2(int v) => v.toString().padLeft(2, '0');
  static String _stamp() {
    final t = DateTime.now();
    return '${t.year}${_p2(t.month)}${_p2(t.day)}_${_p2(t.hour)}${_p2(t.minute)}${_p2(t.second)}';
  }
}
