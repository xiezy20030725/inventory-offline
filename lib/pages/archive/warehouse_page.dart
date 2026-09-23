import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/stock_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// 仓库与货位管理：多仓库 + 多级货位
class WarehousePage extends StatefulWidget {
  const WarehousePage({super.key});

  @override
  State<WarehousePage> createState() => _WarehousePageState();
}

class _WarehousePageState extends State<WarehousePage> {
  final StockService _svc = StockService();
  List<Warehouse> _warehouses = [];
  Map<int, List<Location>> _locs = {};
  int? _expanded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _warehouses = await _svc.warehouses();
    _locs = {};
    for (final w in _warehouses) {
      _locs[w.id!] = await _svc.locations(w.id!);
    }
    if (mounted) setState(() {});
  }

  Future<void> _editWarehouse([Warehouse? w]) async {
    final nameCtrl = TextEditingController(text: w?.name ?? '');
    final addrCtrl = TextEditingController(text: w?.address ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(w == null ? '新增仓库' : '编辑仓库', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: '仓库名称 *')),
          const SizedBox(height: 10),
          TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: '仓库地址')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _svc.saveWarehouse((w ?? Warehouse(name: '', createTime: now, updateTime: now))
      ..name = nameCtrl.text.trim()
      ..address = addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim()
      ..updateTime = now);
    _load();
  }

  Future<void> _editLocation(int warehouseId, [Location? l]) async {
    final codeCtrl = TextEditingController(text: l?.code ?? '');
    final nameCtrl = TextEditingController(text: l?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l == null ? '新增货位' : '编辑货位', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: codeCtrl, autofocus: true, decoration: const InputDecoration(labelText: '货位编码 *')),
          const SizedBox(height: 10),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '货位名称 *')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true || codeCtrl.text.trim().isEmpty) return;
    await _svc.saveLocation((l ?? Location(warehouseId: warehouseId, code: '', name: '', createTime: DateTime.now().millisecondsSinceEpoch))
      ..code = codeCtrl.text.trim()
      ..name = nameCtrl.text.trim().isEmpty ? codeCtrl.text.trim() : nameCtrl.text.trim());
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('仓库货位'), backgroundColor: AppColors.bg, actions: [
        IconButton(onPressed: () => _editWarehouse(), icon: const Icon(Icons.add)),
      ]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        for (final w in _warehouses)
          SectionCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _expanded = _expanded == w.id ? null : w.id),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: AppColors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.warehouse_outlined, color: AppColors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(w.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    if ((w.address ?? '').isNotEmpty)
                      Text(w.address!, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                  ])),
                  Text('${(_locs[w.id] ?? []).length} 货位', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                  Icon(_expanded == w.id ? Icons.expand_less : Icons.expand_more, color: AppColors.textSub),
                ]),
              ),
              if (_expanded == w.id) ...[
                const Divider(height: 18),
                for (final l in (_locs[w.id] ?? []))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.place_outlined, color: AppColors.orange, size: 20),
                    title: Text('${l.code}  ${l.name}', style: const TextStyle(fontSize: 14)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _editLocation(w.id!, l)),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.red),
                          onPressed: () async {
                            if (!await confirm(context, '删除货位', '确定删除货位 ${l.code}？')) return;
                            await _svc.deleteLocation(l.id!);
                            _load();
                          }),
                    ]),
                  ),
                if ((_locs[w.id] ?? []).isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('暂无货位', style: TextStyle(fontSize: 12, color: AppColors.textSub))),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _editLocation(w.id!),
                      icon: const Icon(Icons.add_location_alt_outlined, size: 18), label: const Text('添加货位'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red)),
                      onPressed: () async {
                        if (!await confirm(context, '删除仓库', '确定删除仓库 ${w.name}？有库存时将被拦截。')) return;
                        try {
                          await _svc.deleteWarehouse(w.id!);
                          _load();
                        } catch (e) {
                          if (context.mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 18), label: const Text('删除仓库'))),
                ]),
              ],
            ]),
          ),
        if (_warehouses.isEmpty) const EmptyView(text: '暂无仓库，点击右上角新增'),
      ]),
    );
  }
}
