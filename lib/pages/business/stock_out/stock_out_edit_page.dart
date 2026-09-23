import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../services/stock_service.dart';
import '../../../state/app_state.dart';
import '../../../theme.dart';
import '../../../utils/scanner.dart';
import '../../../widgets/common.dart';
import '../../archive/product_list_page.dart';

/// 出库开单：提交确认时校验库存充足性，不足弹窗拦截
class StockOutEditPage extends StatefulWidget {
  const StockOutEditPage({super.key});

  @override
  State<StockOutEditPage> createState() => _StockOutEditPageState();
}

class _StockOutEditPageState extends State<StockOutEditPage> {
  final StockService _svc = StockService();
  final TextEditingController _customerCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  int _type = 1;
  int? _warehouseId;
  List<Warehouse> _warehouses = [];
  List<StockOutItem> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _warehouses = await _svc.warehouses();
    final state = context.read<AppState>();
    setState(() => _warehouseId = state.currentWarehouseId > 0 ? state.currentWarehouseId : (_warehouses.isEmpty ? null : _warehouses.first.id));
  }

  @override
  void dispose() {
    _customerCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  double get _totalNum => _items.fold(0, (s, i) => s + i.quantity);

  Future<void> _addByScan() async {
    final code = await scan(context);
    if (code == null || code.isEmpty) return;
    final product = await _svc.productByBarcode(code);
    if (!mounted) return;
    if (product == null) return toast(context, '条码未建档：$code');
    _itemDialog(StockOutItem(productId: product.id!, product: product));
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
    if (product != null) _itemDialog(StockOutItem(productId: product.id!, product: product));
  }

  Future<void> _itemDialog(StockOutItem item) async {
    final state = context.read<AppState>();
    final rows = await _svc.queryStock(state.currentWarehouseId);
    final available = rows
        .where((r) => r.product.id == item.productId)
        .fold<double>(0, (s, r) => s + r.stock.quantity);
    final qtyCtrl = TextEditingController(text: item.quantity > 0 ? fmtQty(item.quantity) : '');
    final priceCtrl = TextEditingController(text: item.price > 0 ? item.price.toString() : (item.product?.salePrice ?? 0).toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(item.product?.name ?? '添加明细', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('当前可用库存：${fmtQty(available)} ${item.product?.unit ?? ''}',
              style: TextStyle(fontSize: 12, color: available > 0 ? AppColors.green : AppColors.red)),
          const SizedBox(height: 10),
          TextField(controller: qtyCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '出库数量 *')),
          const SizedBox(height: 10),
          TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '出库单价', helperText: '默认带出售价，成本按移动加权平均核算')),
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
      toast(context, '库存不足：可用 ${fmtQty(available)}，需 ${fmtQty(qty)}');
      return;
    }
    setState(() {
      item
        ..quantity = qty
        ..price = double.tryParse(priceCtrl.text) ?? 0
        ..amount = round2(qty * (double.tryParse(priceCtrl.text) ?? 0));
      if (!_items.contains(item)) _items.add(item);
    });
  }

  Future<void> _save({bool confirmNow = false}) async {
    if (_warehouseId == null) return toast(context, '请选择仓库');
    if (_items.isEmpty) return toast(context, '请添加出库明细');
    setState(() => _saving = true);
    try {
      final order = StockOutOrder(
        orderNo: '',
        orderType: _type,
        warehouseId: _warehouseId!,
        customer: _customerCtrl.text.trim(),
        remark: _remarkCtrl.text.trim(),
        createTime: DateTime.now().millisecondsSinceEpoch,
        items: List<StockOutItem>.from(_items.map((i) => StockOutItem(
            productId: i.productId, quantity: i.quantity, price: i.price, amount: i.amount))),
      );
      final id = await _svc.saveStockOut(order);
      if (confirmNow) await _svc.confirmStockOut(id);
      if (mounted) {
        toast(context, confirmNow ? '出库成功，库存已扣减' : '草稿已保存');
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
      appBar: AppBar(title: const Text('出库开单'), backgroundColor: AppColors.bg),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(12), children: [
            SectionCard(child: Column(children: [
              Row(children: [
                Expanded(child: DropdownButtonFormField<int>(
                  value: _type,
                  decoration: const InputDecoration(labelText: '出库类型'),
                  items: StockOutOrder.typeNames.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _type = v ?? 1),
                )),
                const SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField<int>(
                  value: _warehouseId,
                  decoration: const InputDecoration(labelText: '出库仓库'),
                  items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _warehouseId = v),
                )),
              ]),
              const SizedBox(height: 10),
              TextField(controller: _customerCtrl, decoration: const InputDecoration(labelText: '客户')),
            ])),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: ElevatedButton.icon(onPressed: _addByScan, icon: const Icon(Icons.qr_code_scanner, size: 20), label: const Text('扫码拣货'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: _addByPick, icon: const Icon(Icons.playlist_add, size: 20), label: const Text('选择商品'))),
            ]),
            const SizedBox(height: 10),
            if (_items.isEmpty)
              const SectionCard(margin: EdgeInsets.zero, child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('暂无明细，请扫码或选择商品', style: TextStyle(color: AppColors.textSub, fontSize: 13))),
              ))
            else
              ..._items.map(_itemCard),
            const SizedBox(height: 10),
            SectionCard(child: TextField(controller: _remarkCtrl, decoration: const InputDecoration(labelText: '备注'))),
          ]),
        ),
        BottomActionBar(children: [
          OutlinedButton(onPressed: _saving ? null : () => _save(), child: const Text('存草稿')),
          ElevatedButton(
            onPressed: _saving ? null : () async {
              if (!await confirm(context, '确认出库', '提交后将校验库存并自动扣减，是否继续？')) return;
              _save(confirmNow: true);
            },
            child: Text(_saving ? '处理中...' : '确认出库 ×${fmtQty(_totalNum)}'),
          ),
        ]),
      ]),
    );
  }

  Widget _itemCard(StockOutItem it) {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(it.product?.name ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('¥${NumberFormatDec().decFmt(it.price)} × ${fmtQty(it.quantity)} = ¥${NumberFormatDec().decFmt(it.amount)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
        ])),
        IconButton(onPressed: () => _itemDialog(it), icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSub)),
        IconButton(onPressed: () => setState(() => _items.remove(it)), icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.red)),
      ]),
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
