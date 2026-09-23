import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../services/stock_service.dart';
import '../../../state/app_state.dart';
import '../../../theme.dart';
import '../../../utils/scanner.dart';
import '../../../widgets/common.dart';
import '../../archive/product_list_page.dart';

/// 调拨开单：支持一步/两步模式
class TransferEditPage extends StatefulWidget {
  const TransferEditPage({super.key});

  @override
  State<TransferEditPage> createState() => _TransferEditPageState();
}

class _TransferEditPageState extends State<TransferEditPage> {
  final StockService _svc = StockService();
  int _mode = 1;
  int? _outWh;
  int? _inWh;
  List<Warehouse> _warehouses = [];
  List<TransferItem> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _warehouses = await _svc.warehouses();
    final state = context.read<AppState>();
    setState(() {
      _outWh = state.currentWarehouseId > 0 ? state.currentWarehouseId : (_warehouses.isEmpty ? null : _warehouses.first.id);
      _inWh = _warehouses.length > 1 ? _warehouses[1].id : _outWh;
    });
  }

  double get _totalNum => _items.fold(0, (s, i) => s + i.quantity);

  Future<void> _addByScan() async {
    final code = await scan(context);
    if (code == null || code.isEmpty) return;
    final product = await _svc.productByBarcode(code);
    if (!mounted) return;
    if (product == null) return toast(context, '条码未建档：$code');
    _itemDialog(TransferItem(productId: product.id!, product: product));
  }

  Future<void> _addByPick() async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SizedBox(
        height: MediaQuery.of(c).size.height * 0.75,
        child: _ProductPicker(onPick: (p) => Navigator.pop(c, p)),
      ),
    );
    if (product != null) _itemDialog(TransferItem(productId: product.id!, product: product));
  }

  Future<void> _itemDialog(TransferItem item) async {
    if (_outWh == null) return;
    final rows = await _svc.queryStock(_outWh!);
    final available = rows.where((r) => r.product.id == item.productId).fold<double>(0, (s, r) => s + r.stock.quantity);
    final qtyCtrl = TextEditingController(text: item.quantity > 0 ? fmtQty(item.quantity) : '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(item.product?.name ?? '添加明细', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('调出仓可用：${fmtQty(available)} ${item.product?.unit ?? ''}',
              style: TextStyle(fontSize: 12, color: available > 0 ? AppColors.green : AppColors.red)),
          const SizedBox(height: 10),
          TextField(controller: qtyCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '调拨数量 *')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('添加')),
        ],
      ),
    );
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    if (ok != true || qty <= 0) return;
    if (qty > available + 1e-9) {
      toast(context, '调出仓库存不足：可用 ${fmtQty(available)}');
      return;
    }
    setState(() {
      item.quantity = qty;
      if (!_items.contains(item)) _items.add(item);
    });
  }

  Future<void> _save({bool confirmNow = false}) async {
    if (_outWh == null || _inWh == null) return toast(context, '请选择仓库');
    if (_outWh == _inWh) return toast(context, '调出与调入仓库不能相同');
    if (_items.isEmpty) return toast(context, '请添加调拨明细');
    setState(() => _saving = true);
    try {
      final order = TransferOrder(
        orderNo: '',
        outWarehouseId: _outWh!,
        inWarehouseId: _inWh!,
        stepMode: _mode,
        createTime: DateTime.now().millisecondsSinceEpoch,
        items: List<TransferItem>.from(_items.map((i) => TransferItem(productId: i.productId, quantity: i.quantity))),
      );
      final id = await _svc.saveTransfer(order);
      if (confirmNow) {
        await _svc.confirmTransferOut(id);
        if (_mode == 1) {
          // 一步调拨已完成调入
        } else {
          toast(context, '已调出，商品进入在途，请在调入仓确认收货');
        }
      }
      if (mounted) {
        toast(context, confirmNow ? (_mode == 1 ? '调拨完成' : '已调出') : '草稿已保存');
        Navigator.pop(context);
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
      appBar: AppBar(title: const Text('调拨开单'), backgroundColor: AppColors.bg),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(12), children: [
            SectionCard(child: Column(children: [
              Row(children: [
                Expanded(child: DropdownButtonFormField<int>(
                  value: _outWh,
                  decoration: const InputDecoration(labelText: '调出仓库'),
                  items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _outWh = v),
                )),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 18, color: AppColors.textSub)),
                Expanded(child: DropdownButtonFormField<int>(
                  value: _inWh,
                  decoration: const InputDecoration(labelText: '调入仓库'),
                  items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _inWh = v),
                )),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _modeChip(1, '一步调拨')),
                const SizedBox(width: 10),
                Expanded(child: _modeChip(2, '两步调拨（经在途）')),
              ]),
            ])),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: ElevatedButton.icon(onPressed: _addByScan, icon: const Icon(Icons.qr_code_scanner, size: 20), label: const Text('扫码添加'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: _addByPick, icon: const Icon(Icons.playlist_add, size: 20), label: const Text('选择商品'))),
            ]),
            const SizedBox(height: 10),
            if (_items.isEmpty)
              const SectionCard(margin: EdgeInsets.zero, child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('暂无调拨明细', style: TextStyle(color: AppColors.textSub, fontSize: 13))),
              ))
            else
              ..._items.map((it) => SectionCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: Text(it.product?.name ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                  Text('×${fmtQty(it.quantity)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  IconButton(onPressed: () => setState(() => _items.remove(it)),
                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.red)),
                ]),
              )),
          ]),
        ),
        BottomActionBar(children: [
          OutlinedButton(onPressed: _saving ? null : () => _save(), child: const Text('存草稿')),
          ElevatedButton(
            onPressed: _saving ? null : () async {
              if (!await confirm(context, '确认调拨', _mode == 1 ? '将同时变动两个仓库库存' : '调出后计入在途库存')) return;
              _save(confirmNow: true);
            },
            child: Text(_saving ? '处理中...' : '确认调拨 ×${fmtQty(_totalNum)}'),
          ),
        ]),
      ]),
    );
  }

  Widget _modeChip(int mode, String label) {
    final active = _mode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _mode = mode),
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
    );
  }
}

class _ProductPicker extends StatefulWidget {
  final void Function(Product) onPick;
  const _ProductPicker({required this.onPick});

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  final StockService _svc = StockService();
  List<Product> _list = [];

  @override
  void initState() {
    super.initState();
    _search('');
  }

  Future<void> _search(String kw) async {
    _list = await _svc.products(keyword: kw);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '搜索名称/条码/规格'),
          onChanged: _search,
        ),
      ),
      Expanded(child: _list.isEmpty
          ? const EmptyView(text: '未找到商品')
          : ListView.builder(
              itemCount: _list.length,
              itemBuilder: (_, i) => ListTile(
                leading: ProductThumb(path: _list[i].imagePath, category: _list[i].category ?? ''),
                title: Text(_list[i].name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('${_list[i].barcode ?? '-'}  ${_list[i].spec ?? ''}', style: const TextStyle(fontSize: 12)),
                onTap: () { widget.onPick(_list[i]); },
              ),
            )),
    ]);
  }
}
