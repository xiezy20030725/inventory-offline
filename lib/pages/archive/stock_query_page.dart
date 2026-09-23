import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/stock_service.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/scanner.dart';
import '../../widgets/common.dart';

/// 库存查询：按当前仓库 + 关键字检索，扫码查询，底部显示合计金额
class StockQueryPage extends StatefulWidget {
  const StockQueryPage({super.key});

  @override
  State<StockQueryPage> createState() => _StockQueryPageState();
}

class _StockQueryPageState extends State<StockQueryPage> {
  final StockService _svc = StockService();
  final TextEditingController _kwCtrl = TextEditingController();
  List<StockRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _kwCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    _rows = await _svc.queryStock(state.currentWarehouseId, keyword: _kwCtrl.text);
    if (mounted) setState(() {});
  }

  Future<void> _scan() async {
    final code = await scan(context);
    if (code == null || code.isEmpty) return;
    setState(() => _kwCtrl.text = code);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final totalAmount = _rows.fold<double>(0, (s, r) => s + r.amount);
    final totalQty = _rows.fold<double>(0, (s, r) => s + r.stock.quantity);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('库存查询'), backgroundColor: AppColors.bg, actions: [
        IconButton(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner)),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _kwCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜索商品 / 条码 / 规格（${state.currentWarehouseName}）',
            ),
            onChanged: (_) => _load(),
          ),
        ),
        Expanded(
          child: _rows.isEmpty
              ? const EmptyView(text: '无库存记录')
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = _rows[i];
                    final low = r.product.minStock > 0 && r.stock.quantity < r.product.minStock;
                    final over = r.product.maxStock > 0 && r.stock.quantity > r.product.maxStock;
                    return SectionCard(
                      margin: EdgeInsets.zero,
                      child: Row(children: [
                        ProductThumb(path: r.product.imagePath, category: r.product.category ?? ''),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text('${r.stock.batchNo == null || r.stock.batchNo!.isEmpty ? '无批次' : '批次 ${r.stock.batchNo}'}'
                                  '  ¥${NumberFormatDec().decFmt(r.product.costPrice)}/${r.product.unit}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${fmtQty(r.stock.quantity)} ${r.product.unit}',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                                  color: low ? AppColors.orange : (over ? AppColors.red : AppColors.primary))),
                          const SizedBox(height: 3),
                          Text('¥${NumberFormatDec().decFmt(r.amount)}', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                          if (low || over)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: AlertBadge(type: low ? AlertInfo.typeInsufficient : AlertInfo.typeOver),
                            ),
                        ]),
                      ]),
                    );
                  },
                ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(color: Colors.white),
          child: Row(children: [
            Text('共 ${_rows.length} 种  合计 ${fmtQty(totalQty)} ${_rows.isEmpty ? '' : _rows.first.product.unit}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
            const Spacer(),
            const Text('库存总额 ', style: TextStyle(fontSize: 13, color: AppColors.textSub)),
            Text('¥${NumberFormatDec().decFmt(round2(totalAmount))}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ]),
        ),
      ]),
    );
  }
}
