import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../services/stock_service.dart';
import '../../../state/app_state.dart';
import '../../../theme.dart';
import '../../../widgets/common.dart';
import 'transfer_edit_page.dart';

/// 调拨单列表 + 详情（调出确认/调入确认/作废）
class TransferListPage extends StatefulWidget {
  const TransferListPage({super.key});

  @override
  State<TransferListPage> createState() => _TransferListPageState();
}

class _TransferListPageState extends State<TransferListPage> {
  final StockService _svc = StockService();
  List<TransferOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    _orders = await _svc.transferOrders(warehouseId: state.currentWarehouseId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('库存调拨'), backgroundColor: AppColors.bg),
      body: _orders.isEmpty
          ? const EmptyView(text: '暂无调拨单')
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _card(_orders[i]),
            ),
    );
  }

  Widget _card(TransferOrder o) {
    final statusColor = {1: AppColors.orange, 2: AppColors.green, 3: AppColors.textSub, 0: AppColors.orange}[o.status] ?? AppColors.textSub;
    return SectionCard(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => TransferDetailPage(orderId: o.id!)));
          _load();
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(o.orderNo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(o.statusName, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 8),
          Text('${o.outWarehouseName}  →  ${o.inWarehouseName}   ${o.stepMode == 1 ? "一步调拨" : "两步调拨"}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
          const Divider(height: 18),
          Row(children: [
            Text('数量 ${fmtQty(o.totalNum)}', style: const TextStyle(fontSize: 13)),
            const Spacer(),
            Text(DateTime.fromMillisecondsSinceEpoch(o.createTime).toString().substring(0, 16),
                style: const TextStyle(fontSize: 11, color: AppColors.textSub)),
          ]),
        ]),
      ),
    );
  }
}

class TransferDetailPage extends StatelessWidget {
  final int orderId;
  final StockService _svc = StockService();
  TransferDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('调拨单详情'), backgroundColor: AppColors.bg),
      body: FutureBuilder<TransferOrder>(
        future: _svc.transferDetail(orderId),
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
                    Text(o.statusName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 10),
                  _row('调出仓库', o.outWarehouseName ?? ''),
                  _row('调入仓库', o.inWarehouseName ?? ''),
                  _row('流程模式', o.stepMode == 1 ? '一步调拨' : '两步调拨'),
                  if (o.outTime != null) _row('调出时间', DateTime.fromMillisecondsSinceEpoch(o.outTime!).toString().substring(0, 19)),
                  if (o.inTime != null) _row('调入时间', DateTime.fromMillisecondsSinceEpoch(o.inTime!).toString().substring(0, 19)),
                ])),
                const SizedBox(height: 10),
                SectionCard(child: Column(children: [
                  for (final it in o.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Expanded(child: Text(it.product?.name ?? '商品${it.productId}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                        Text('×${fmtQty(it.quantity)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ])),
              ]),
            ),
            _buildActions(context, o),
          ]);
        },
      ),
    );
  }

  Widget _buildActions(BuildContext context, TransferOrder o) {
    final buttons = <Widget>[];
    if (o.status == 0 || o.status == 1) {
      final label = o.status == 0 ? (o.stepMode == 1 ? '确认调拨' : '确认调出') : '确认调入';
      buttons.add(ElevatedButton(
        onPressed: () async {
          final msg = o.status == 0
              ? (o.stepMode == 1 ? '一步调拨将同时扣减调出仓并增加调入仓库存' : '调出后商品计入在途库存，待调入仓确认收货')
              : '调入确认后正式增加调入仓库存';
          if (!await confirm(context, '确认操作', msg)) return;
          try {
            if (o.status == 0) {
              await _svc.confirmTransferOut(o.id!);
            } else {
              await _svc.confirmTransferIn(o.id!);
            }
            if (context.mounted) {
              toast(context, '操作成功');
              Navigator.pop(context);
            }
          } catch (e) {
            if (context.mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
          }
        },
        child: Text(label),
      ));
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return BottomActionBar(children: buttons);
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 70, child: Text(k, style: const TextStyle(fontSize: 13, color: AppColors.textSub))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
        ]),
      );
}
