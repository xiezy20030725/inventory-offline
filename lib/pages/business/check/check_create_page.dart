import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../services/stock_service.dart';
import '../../../state/app_state.dart';
import '../../../theme.dart';
import '../../../widgets/common.dart';
import 'check_detail_page.dart';

/// 盘点建单：选择范围（全盘/按货位/按分类），创建时锁定账面快照
class CheckCreatePage extends StatefulWidget {
  const CheckCreatePage({super.key});

  @override
  State<CheckCreatePage> createState() => _CheckCreatePageState();
}

class _CheckCreatePageState extends State<CheckCreatePage> {
  final StockService _svc = StockService();
  int _range = 1;
  String? _rangeParam;
  int? _warehouseId;
  List<Warehouse> _warehouses = [];
  List<Location> _locations = [];
  List<String> _categories = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _warehouses = await _svc.warehouses();
    final state = context.read<AppState>();
    _warehouseId = state.currentWarehouseId > 0 ? state.currentWarehouseId : (_warehouses.isEmpty ? null : _warehouses.first.id);
    await _loadScope();
    if (mounted) setState(() {});
  }

  Future<void> _loadScope() async {
    if (_warehouseId == null) return;
    _locations = await _svc.locations(_warehouseId!);
    final all = await _svc.products();
    _categories = all.map((e) => e.category ?? '').where((e) => e.isNotEmpty).toSet().toList();
    _rangeParam = null;
  }

  Future<void> _create() async {
    if (_warehouseId == null) return toast(context, '请选择仓库');
    if (_range > 1 && (_rangeParam ?? '').isEmpty) return toast(context, '请选择盘点范围参数');
    setState(() => _saving = true);
    try {
      final order = CheckOrder(
        orderNo: '',
        warehouseId: _warehouseId!,
        checkRange: _range,
        rangeParam: _rangeParam,
        createTime: DateTime.now().millisecondsSinceEpoch,
      );
      final id = await _svc.createCheckOrder(order);
      if (mounted) {
        toast(context, '盘点单已创建，账面库存已锁定');
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => CheckDetailPage(orderId: id)));
      }
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('新建盘点'), backgroundColor: AppColors.bg),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(12), children: [
            SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('盘点仓库', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _warehouseId,
                decoration: const InputDecoration(labelText: '仓库'),
                items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                onChanged: (v) async {
                  setState(() => _warehouseId = v);
                  await _loadScope();
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 14),
              const Text('盘点范围', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(children: [
                _rangeChip(1, '全盘'),
                const SizedBox(width: 8),
                _rangeChip(2, '按货位'),
                const SizedBox(width: 8),
                _rangeChip(3, '按分类'),
              ]),
              if (_range == 2) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _rangeParam,
                  decoration: const InputDecoration(labelText: '选择货位'),
                  items: _locations.map((l) => DropdownMenuItem(value: l.id.toString(), child: Text('${l.code} ${l.name}', style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _rangeParam = v),
                ),
              ],
              if (_range == 3) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _rangeParam,
                  decoration: const InputDecoration(labelText: '选择分类'),
                  items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _rangeParam = v),
                ),
              ],
              const SizedBox(height: 10),
              Text('创建后将锁定当前账面库存作为盘点基准，盘点确认后按差异自动调整库存并生成盘盈/盘亏单。',
                  style: TextStyle(fontSize: 12, color: AppColors.textSub.withOpacity(0.9))),
            ])),
          ]),
        ),
        BottomActionBar(children: [
          ElevatedButton(
            onPressed: _saving ? null : _create,
            child: Text(_saving ? '创建中...' : '创建盘点单'),
          ),
        ]),
      ]),
    );
  }

  Widget _rangeChip(int v, String label) {
    final active = _range == v;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _range = v),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withOpacity(0.1) : AppColors.itemBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? AppColors.primary : Colors.transparent),
          ),
          child: Center(child: Text(label, style: TextStyle(
              fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.primary : AppColors.textSub))),
        ),
      ),
    );
  }
}
