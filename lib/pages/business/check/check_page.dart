import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/models.dart';
import '../../../services/stock_service.dart';
import '../../../state/app_state.dart';
import '../../../theme.dart';
import '../../../widgets/common.dart';
import 'check_create_page.dart';
import 'check_detail_page.dart';

/// 盘点单列表
class CheckListPage extends StatefulWidget {
  const CheckListPage({super.key});

  @override
  State<CheckListPage> createState() => _CheckListPageState();
}

class _CheckListPageState extends State<CheckListPage> {
  final StockService _svc = StockService();
  List<CheckOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    _orders = await _svc.checkOrders(warehouseId: state.currentWarehouseId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('库存盘点'),
        backgroundColor: AppColors.bg,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckCreatePage()));
              _load();
            },
            icon: const Icon(Icons.add, size: 20),
            label: const Text('新建盘点'),
          ),
        ],
      ),
      body: _orders.isEmpty
          ? const EmptyView(text: '暂无盘点单')
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _card(_orders[i]),
            ),
    );
  }

  Widget _card(CheckOrder o) {
    final c = o.status == 1 ? AppColors.green : (o.status == 2 ? AppColors.textSub : AppColors.orange);
    return SectionCard(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => CheckDetailPage(orderId: o.id!)));
          _load();
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(o.orderNo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(o.statusName, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 8),
          Text('${o.warehouseName ?? ''} · ${o.rangeName}${o.rangeParam == null ? '' : '（${o.rangeParam}）'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
          const Divider(height: 18),
          Row(children: [
            Text('SKU ${o.totalSku}', style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 16),
            Text('差异 ${o.diffSku}', style: TextStyle(fontSize: 13, color: o.diffSku > 0 ? AppColors.red : AppColors.textDark)),
            const Spacer(),
            Text(DateTime.fromMillisecondsSinceEpoch(o.createTime).toString().substring(0, 16),
                style: const TextStyle(fontSize: 11, color: AppColors.textSub)),
          ]),
        ]),
      ),
    );
  }
}
