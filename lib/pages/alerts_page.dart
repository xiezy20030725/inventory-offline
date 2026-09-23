import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// 预警看板：按预警类型筛选，展示全部预警商品
class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final all = state.alerts;
    final list = _filter.isEmpty ? all : all.where((a) => a.type == _filter).toList();
    final counts = <String, int>{};
    for (final a in all) {
      counts[a.type] = (counts[a.type] ?? 0) + 1;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('库存预警'), backgroundColor: AppColors.bg),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            _chip('全部', all.length.toString(), ''),
            const SizedBox(width: 8),
            for (final t in AlertInfo.typeNames.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _chip(t.value, (counts[t.key] ?? 0).toString(), t.key),
              ),
          ]),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyView(text: '暂无预警，库存状态良好')
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final a = list[i];
                    String? sub;
                    if (a.type == AlertInfo.typeExpiring) sub = '剩余 ${a.remainDays ?? 0} 天到期';
                    if (a.type == AlertInfo.typeOver) sub = '已积压 ${a.overdueDays ?? 0} 天，上限 ${fmtQty(a.limitValue!)}';
                    if (a.type == AlertInfo.typeExpired) sub = '已过期 ${a.overdueDays ?? 0} 天';
                    if (a.type == AlertInfo.typeInsufficient) {
                      sub = '库存 ${fmtQty(a.stock)} ${a.product.unit}，下限 ${fmtQty(a.limitValue!)}';
                    }
                    return SectionCard(
                      margin: EdgeInsets.zero,
                      child: Row(children: [
                        ProductThumb(path: a.product.imagePath, category: a.product.category ?? ''),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.product.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text(a.product.specText, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                            if (sub != null)
                              Padding(padding: const EdgeInsets.only(top: 3),
                                  child: Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSub))),
                          ]),
                        ),
                        AlertBadge(type: a.type),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _chip(String label, String count, String value) {
    final active = _filter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AppColors.primary : AppColors.line),
        ),
        child: Text('$label $count',
            style: TextStyle(fontSize: 12, color: active ? Colors.white : AppColors.textSub,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}
