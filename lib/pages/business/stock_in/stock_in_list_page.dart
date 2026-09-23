import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../services/stock_service.dart';
import '../../../state/app_state.dart';
import '../../../theme.dart';
import '../../../widgets/common.dart';

/// 入库单列表：按类型/状态筛选，查看详情、确认、作废
class StockInListPage extends StatefulWidget {
  const StockInListPage({super.key});

  @override
  State<StockInListPage> createState() => _StockInListPageState();
}

class _StockInListPageState extends State<StockInListPage> {
  final StockService _svc = StockService();
  int? _type;
  int? _status;
  List<StockInOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    _orders = await _svc.stockInOrders(warehouseId: state.currentWarehouseId, type: _type, status: _status);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('入库管理'), backgroundColor: AppColors.bg),
      body: Column(children: [
        _buildFilter(),
        Expanded(
          child: _orders.isEmpty
              ? const EmptyView(text: '暂无入库单')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  itemCount: _orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _orderCard(_orders[i]),
                ),
        ),
      ]),
    );
  }

  Widget _buildFilter() {
    Widget chip(String label, bool active, VoidCallback onTap) {
      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? AppColors.primary : AppColors.line),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, color: active ? Colors.white : AppColors.textSub)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        height: 34,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          chip('全部类型', _type == null, () => setState(() { _type = null; _load(); })),
          for (final e in StockInOrder.typeNames.entries)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: chip(e.value, _type == e.key, () => setState(() { _type = e.key; _load(); })),
            ),
          const SizedBox(width: 16),
          chip('全部状态', _status == null, () => setState(() { _status = null; _load(); })),
          for (final e in StockInOrder.statusNames.entries)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: chip(e.value, _status == e.key, () => setState(() { _status = e.key; _load(); })),
            ),
        ]),
      ),
    );
  }

  Widget _orderCard(StockInOrder o) {
    return SectionCard(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(o),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(o.orderNo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const Spacer(),
            StatusChip(text: o.statusName, status: o.status),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _tag(o.typeName, AppColors.blue),
            const SizedBox(width: 8),
            Expanded(child: Text('${o.warehouseName ?? ''}  ${o.supplier ?? ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSub))),
          ]),
          const Divider(height: 18),
          Row(children: [
            Text('数量 ${fmtQty(o.totalNum)}', style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
            const SizedBox(width: 16),
            Text('金额 ¥${NumberFormatDec().decFmt(o.totalAmount)}',
                style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
            const Spacer(),
            Text(DateTime.fromMillisecondsSinceEpoch(o.createTime).toString().substring(0, 16),
                style: const TextStyle(fontSize: 11, color: AppColors.textSub)),
          ]),
        ]),
      ),
    );
  }

  Widget _tag(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
        child: Text(text, style: TextStyle(fontSize: 11, color: c)),
      );

  Future<void> _openDetail(StockInOrder o) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => StockInDetailPage(orderId: o.id!)));
    _load();
  }
}

/// 入库单详情
class StockInDetailPage extends StatelessWidget {
  final int orderId;
  final StockService _svc = StockService();
  StockInDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('入库单详情'), backgroundColor: AppColors.bg),
      body: FutureBuilder<StockInOrder>(
        future: _svc.stockInDetail(orderId),
        builder: (c, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final o = snap.data!;
          return Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(12), children: [
                SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(o.orderNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const Spacer(),
                    StatusChip(text: o.statusName, status: o.status),
                  ]),
                  const SizedBox(height: 10),
                  _row('入库类型', o.typeName),
                  _row('仓库', o.warehouseName ?? ''),
                  _row('供应商', o.supplier ?? '-'),
                  _row('创建时间', DateTime.fromMillisecondsSinceEpoch(o.createTime).toString().substring(0, 19)),
                  if (o.confirmTime != null)
                    _row('确认时间', DateTime.fromMillisecondsSinceEpoch(o.confirmTime!).toString().substring(0, 19)),
                  if ((o.remark ?? '').isNotEmpty) _row('备注', o.remark!),
                ])),
                const SizedBox(height: 10),
                SectionCard(child: Column(children: [
                  for (final it in o.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(it.product?.name ?? '商品${it.productId}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('批次 ${it.batchNo ?? '-'}  ¥${NumberFormatDec().decFmt(it.price)}/${it.product?.unit ?? ''}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                        ])),
                        Text('×${fmtQty(it.quantity)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 12),
                        Text('¥${NumberFormatDec().decFmt(it.amount)}',
                            style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('合计：${fmtQty(o.totalNum)} 件 / ¥${NumberFormatDec().decFmt(o.totalAmount)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  ]),
                ])),
              ]),
            ),
            if (o.status == 0)
              BottomActionBar(children: [
                OutlinedButton(
                  onPressed: () async {
                    if (!await confirm(context, '作废单据', '确定作废该入库单？作废后不可恢复。')) return;
                    try {
                      await _svc.voidStockIn(o.id!);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
                    }
                  },
                  child: const Text('作废'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!await confirm(context, '确认入库', '确认后自动增加对应仓库库存，是否继续？')) return;
                    try {
                      await _svc.confirmStockIn(o.id!);
                      if (context.mounted) {
                        toast(context, '入库成功');
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (context.mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
                    }
                  },
                  child: const Text('确认入库'),
                ),
              ]),
          ]);
        },
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 70, child: Text(k, style: const TextStyle(fontSize: 13, color: AppColors.textSub))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, color: AppColors.textDark))),
        ]),
      );
}
