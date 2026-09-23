import 'package:flutter/material.dart';
import '../../../models/models.dart';
import '../../../services/stock_service.dart';
import '../../../theme.dart';
import '../../../utils/scanner.dart';
import '../../../widgets/common.dart';

/// 盘点详情：扫码/手动录入实盘数量，展示差异，支持复盘与确认调整
class CheckDetailPage extends StatefulWidget {
  final int orderId;
  const CheckDetailPage({super.key, required this.orderId});

  @override
  State<CheckDetailPage> createState() => _CheckDetailPageState();
}

class _CheckDetailPageState extends State<CheckDetailPage> {
  final StockService _svc = StockService();
  CheckOrder? _order;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _order = await _svc.checkDetail(widget.orderId);
    if (mounted) setState(() {});
  }

  Future<void> _inputActual(CheckItem it) async {
    final ctrl = TextEditingController(text: it.actualQuantity != null ? fmtQty(it.actualQuantity!) : '');
    final reasonCtrl = TextEditingController(text: it.diffReason ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(it.product?.name ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('账面数量：${fmtQty(it.bookQuantity)} ${it.product?.unit ?? ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
          const SizedBox(height: 10),
          TextField(controller: ctrl, autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: '实盘数量 *')),
          const SizedBox(height: 10),
          TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: '差异原因（选填）')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('保存')),
        ],
      ),
    );
    final actual = double.tryParse(ctrl.text);
    if (ok != true || actual == null) return;
    await _svc.saveCheckActual(it.id!, actual, reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim());
    _load();
  }

  Future<void> _scanCount() async {
    final code = await scan(context);
    if (code == null || code.isEmpty || _order == null) return;
    final it = _order!.items.firstWhere((e) => e.product?.barcode == code, orElse: () => CheckItem(orderId: 0, productId: 0, bookQuantity: 0));
    if (it.id == null) {
      if (!mounted) return;
      toast(context, '该商品不在本次盘点范围：$code');
      return;
    }
    _inputActual(it);
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('盘点单'), backgroundColor: AppColors.bg),
      body: o == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SectionCard(
                  child: Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o.orderNo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('${o.warehouseName ?? ''} · ${o.rangeName}', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                    ]),
                    const Spacer(),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('SKU ${o.totalSku}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('差异 ${o.diffSku}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: o.diffSku > 0 ? AppColors.red : AppColors.green)),
                    ]),
                  ]),
                ),
              ),
              Expanded(
                child: o.items.isEmpty
                    ? const EmptyView(text: '范围内无账面库存')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: o.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _itemCard(o.items[i]),
                      ),
              ),
              if (o.status == 0)
                BottomActionBar(children: [
                  OutlinedButton.icon(
                    onPressed: _scanCount,
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: const Text('扫码盘点'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final done = o.items.where((e) => e.actualQuantity != null).length;
                      if (!await confirm(context, '确认盘点',
                          '已盘 ${done}/${o.items.length} 项，未盘项不调整库存。确认后自动按差异调整库存，是否继续？')) {
                        return;
                      }
                      try {
                        await _svc.confirmCheck(o.id!);
                        if (context.mounted) {
                          toast(context, '盘点完成，库存已按差异调整');
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (context.mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
                      }
                    },
                    child: const Text('确认盘点'),
                  ),
                ]),
            ]),
    );
  }

  Widget _itemCard(CheckItem it) {
    final diff = it.diffQuantity;
    final hasActual = it.actualQuantity != null;
    return SectionCard(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: it.id == null ? null : () => _inputActual(it),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it.product?.name ?? '商品${it.productId}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text('账面 ${fmtQty(it.bookQuantity)}  ${it.product?.spec ?? ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
            if (hasActual)
              Padding(padding: const EdgeInsets.only(top: 3), child: Text('实盘 ${fmtQty(it.actualQuantity!)}'
                  '${diff != null && diff != 0 ? '  差异 ${diff > 0 ? '+' : ''}${fmtQty(diff)}' : ''}'
                  '${(it.diffReason ?? '').isEmpty ? '' : '  原因:${it.diffReason}'}',
                  style: TextStyle(fontSize: 12, color: diff != null && diff != 0 ? AppColors.red : AppColors.green))),
          ])),
          hasActual
              ? Icon(Icons.check_circle, color: AppColors.green, size: 22)
              : Icon(Icons.radio_button_unchecked, color: const Color(0xFFC6CCD8), size: 22),
        ]),
      ),
    );
  }
}
