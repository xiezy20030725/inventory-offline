import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/stock_service.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'product_list_page.dart';
import 'stock_query_page.dart';
import 'warehouse_page.dart';

/// 档案Tab：商品管理 / 仓库货位 / 库存查询
class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  final StockService _svc = StockService();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('档案'), backgroundColor: AppColors.bg),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
        _entry(context, Icons.inventory_2_outlined, AppColors.green, '商品管理', '条码建档 / 分类 / 预警参数',
            const ProductListPage()),
        _entry(context, Icons.map_outlined, AppColors.blue, '仓库货位', '多仓库 / 多级货位维护',
            const WarehousePage()),
        _entry(context, Icons.plagiarism_outlined, AppColors.indigo, '库存查询', '按仓库 / 货位 / 批次分布',
            const StockQueryPage()),
        const SizedBox(height: 6),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _svc.inTransitStock(state.currentWarehouseId),
          builder: (c, snap) {
            final rows = snap.data ?? const [];
            return SectionCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('在途库存（两步调拨未调入）',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  const Text('暂无在途商品', style: TextStyle(fontSize: 13, color: AppColors.textSub))
                else
                  for (final r in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('${r['name']}', style: const TextStyle(fontSize: 14)),
                        Text('${fmtQty(((r['qty'] ?? 0) as num).toDouble())} ${r['unit']}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.orange)),
                      ]),
                    ),
              ]),
            );
          },
        ),
      ]),
    );
  }

  Widget _entry(BuildContext context, IconData icon, Color color, String title, String sub, Widget page) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 3),
                Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
              ])),
              const Icon(Icons.chevron_right, color: AppColors.textSub),
            ]),
          ),
        ),
      ),
    );
  }
}
