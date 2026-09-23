import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../services/stock_service.dart';
import '../../../state/app_state.dart';
import '../../../theme.dart';
import '../../../utils/scanner.dart';
import '../../../widgets/common.dart';
import '../../archive/product_list_page.dart';

/// 入库开单：选择类型/仓库/供应商，扫码或搜索添加明细，支持凭证拍照，草稿/直接确认
class StockInEditPage extends StatefulWidget {
  final int? editId;
  const StockInEditPage({super.key, this.editId});

  @override
  State<StockInEditPage> createState() => _StockInEditPageState();
}

class _StockInEditPageState extends State<StockInEditPage> {
  final StockService _svc = StockService();
  final TextEditingController _supplierCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  int _type = 1;
  int? _warehouseId;
  List<Warehouse> _warehouses = [];
  List<StockInItem> _items = [];
  List<String> _images = [];
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
    if (widget.editId != null) {
      final o = await _svc.stockInDetail(widget.editId!);
      setState(() {
        _type = o.orderType;
        _warehouseId = o.warehouseId;
        _supplierCtrl.text = o.supplier ?? '';
        _remarkCtrl.text = o.remark ?? '';
        _items = o.items;
        _images = (o.imagePaths ?? '').isEmpty ? [] : o.imagePaths!.split(';');
      });
    }
  }

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  double get _totalNum => _items.fold(0, (s, i) => s + i.quantity);
  double get _totalAmount => _items.fold(0, (s, i) => s + i.amount);

  Future<void> _addByScan() async {
    final code = await scan(context);
    if (code == null || code.isEmpty) return;
    final product = await _svc.productByBarcode(code);
    if (!mounted) return;
    if (product == null) {
      toast(context, '条码未建档：$code');
      return;
    }
    _itemDialog(StockInItem(productId: product.id!, product: product));
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
    if (product != null) _itemDialog(StockInItem(productId: product.id!, product: product));
  }

  Future<void> _itemDialog(StockInItem item) async {
    final qtyCtrl = TextEditingController(text: item.quantity > 0 ? fmtQty(item.quantity) : '');
    final priceCtrl = TextEditingController(text: item.price > 0 ? item.price.toString() : (item.product?.costPrice ?? 0).toString());
    final batchCtrl = TextEditingController(text: item.batchNo ?? '');
    DateTime? expire = item.expireDate == null ? null : DateTime.fromMillisecondsSinceEpoch(item.expireDate!);

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(
        title: Text(item.product?.name ?? '添加明细', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: qtyCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '入库数量 *')),
          const SizedBox(height: 10),
          TextField(controller: priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '入库单价', helperText: '同商品上次单价自动带出')),
          const SizedBox(height: 10),
          TextField(controller: batchCtrl, decoration: const InputDecoration(labelText: '批次号')),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: c, initialDate: expire ?? DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime(2020), lastDate: DateTime(2077));
              if (d != null) setD(() => expire = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: '有效期（用于临期预警）'),
              child: Text(expire == null ? '选择日期' : expire.toString().substring(0, 10),
                  style: TextStyle(fontSize: 14, color: expire == null ? AppColors.textSub : AppColors.textDark)),
            ),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('添加')),
        ],
      )),
    );

    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final price = double.tryParse(priceCtrl.text) ?? 0;
    if (ok != true || qty <= 0) return;
    setState(() {
      item
        ..quantity = qty
        ..price = price
        ..amount = round2(qty * price)
        ..batchNo = batchCtrl.text.trim().isEmpty ? null : batchCtrl.text.trim()
        ..expireDate = expire?.millisecondsSinceEpoch;
      if (!_items.contains(item)) _items.add(item);
    });
  }

  Future<void> _pickVoucher() async {
    try {
      final picker = ImagePicker();
      final photos = await picker.pickMultiImage(imageQuality: 60);
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'vouchers'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final saved = <String>[];
      for (final f in photos) {
        final target = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_${p.basename(f.path)}');
        await File(f.path).copy(target);
        saved.add(target);
      }
      setState(() => _images.addAll(saved));
    } catch (_) {
      toast(context, '拍照/选图不可用或已取消');
    }
  }

  Future<void> _save({bool confirmNow = false}) async {
    if (_warehouseId == null) return toast(context, '请选择仓库');
    if (_items.isEmpty) return toast(context, '请添加入库明细');
    setState(() => _saving = true);
    try {
      final order = StockInOrder(
        orderNo: '',
        orderType: _type,
        warehouseId: _warehouseId!,
        supplier: _supplierCtrl.text.trim(),
        imagePaths: _images.join(';'),
        remark: _remarkCtrl.text.trim(),
        createTime: DateTime.now().millisecondsSinceEpoch,
        items: List<StockInItem>.from(_items.map((i) => StockInItem(
            productId: i.productId, quantity: i.quantity, price: i.price, amount: i.amount,
            batchNo: i.batchNo, expireDate: i.expireDate))),
      );
      final id = await _svc.saveStockIn(order);
      if (confirmNow) {
        await _svc.confirmStockIn(id);
      }
      if (mounted) {
        toast(context, confirmNow ? '入库成功，库存已更新' : '草稿已保存');
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
      appBar: AppBar(title: const Text('入库开单'), backgroundColor: AppColors.bg),
      body: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(12), children: [
            SectionCard(child: Column(children: [
              Row(children: [
                Expanded(child: DropdownButtonFormField<int>(
                  value: _type,
                  decoration: const InputDecoration(labelText: '入库类型'),
                  items: StockInOrder.typeNames.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _type = v ?? 1),
                )),
                const SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField<int>(
                  value: _warehouseId,
                  decoration: const InputDecoration(labelText: '入库仓库'),
                  items: _warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name, style: const TextStyle(fontSize: 14)))).toList(),
                  onChanged: (v) => setState(() => _warehouseId = v),
                )),
              ]),
              const SizedBox(height: 10),
              TextField(controller: _supplierCtrl, decoration: const InputDecoration(labelText: '供应商')),
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
                child: Center(child: Text('暂无明细，请扫码或选择商品', style: TextStyle(color: AppColors.textSub, fontSize: 13))),
              ))
            else
              ..._items.map(_itemCard),
            const SizedBox(height: 10),
            SectionCard(child: Column(children: [
              TextField(controller: _remarkCtrl, decoration: const InputDecoration(labelText: '备注')),
              const SizedBox(height: 10),
              Row(children: [
                Text('凭证留证（${_images.length}）', style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
                const Spacer(),
                TextButton.icon(onPressed: _pickVoucher, icon: const Icon(Icons.camera_alt_outlined, size: 18), label: const Text('拍照/相册')),
              ]),
              if (_images.isNotEmpty)
                SizedBox(height: 64, child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final path in _images)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(path), width: 64, height: 64, fit: BoxFit.cover)),
                    ),
                ])),
            ])),
          ]),
        ),
        BottomActionBar(children: [
          OutlinedButton(onPressed: _saving ? null : () => _save(), child: const Text('存草稿')),
          ElevatedButton(
            onPressed: _saving ? null : () async {
              if (!await confirm(context, '确认入库', '确认后自动增加库存，是否继续？')) return;
              _save(confirmNow: true);
            },
            child: Text(_saving ? '处理中...' : '确认入库 ¥${NumberFormatDec().decFmt(_totalAmount)}'),
          ),
        ]),
      ]),
    );
  }

  Widget _itemCard(StockInItem it) {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(it.product?.name ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('¥${NumberFormatDec().decFmt(it.price)} × ${fmtQty(it.quantity)} = ¥${NumberFormatDec().decFmt(it.amount)}'
                  '${it.batchNo == null ? '' : '  批次:${it.batchNo}'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
        ])),
        IconButton(onPressed: () => _itemDialog(it), icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSub)),
        IconButton(onPressed: () => setState(() => _items.remove(it)), icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.red)),
      ]),
    );
  }
}

/// 商品选择器（搜索列表）
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
          autofocus: false,
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
