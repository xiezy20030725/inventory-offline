import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'stock_in/stock_in_edit_page.dart';
import 'stock_in/stock_in_list_page.dart';
import 'stock_out/stock_out_edit_page.dart';
import 'stock_out/stock_out_list_page.dart';
import 'transfer/transfer_edit_page.dart';
import 'transfer/transfer_list_page.dart';
import 'check/check_create_page.dart';
import 'check/check_page.dart';

/// 业务Tab：出入库/调拨/盘点 入口 + 当前仓库最近单据
class BusinessPage extends StatelessWidget {
  const BusinessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('业务'), backgroundColor: AppColors.bg),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
        Row(children: [
          Expanded(child: _bigEntry(context, Icons.move_to_inbox, '入库管理', '采购/退货/盘盈', AppColors.green,
              (_) => const StockInListPage())),
          const SizedBox(width: 10),
          Expanded(child: _bigEntry(context, Icons.outbox, '出库管理', '销售/领料/盘亏', AppColors.red,
              (_) => const StockOutListPage())),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _bigEntry(context, Icons.swap_horiz, '库存调拨', '一步/两步调拨', AppColors.orange,
              (_) => const TransferListPage())),
          const SizedBox(width: 10),
          Expanded(child: _bigEntry(context, Icons.assignment_outlined, '库存盘点', '全盘/货位/分类', AppColors.blue,
              (_) => const CheckListPage())),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _quick(context, '新建入库单', Icons.post_add, AppColors.green, const StockInEditPage())),
          const SizedBox(width: 10),
          Expanded(child: _quick(context, '新建出库单', Icons.drive_file_move_outline, AppColors.red, const StockOutEditPage())),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _quick(context, '新建调拨单', Icons.alt_route, AppColors.orange, const TransferEditPage())),
          const SizedBox(width: 10),
          Expanded(child: _quick(context, '新建盘点单', Icons.checklist, AppColors.blue, const CheckCreatePage())),
        ]),
        const SizedBox(height: 14),
        SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('当前仓库：${state.currentWarehouseName}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 12),
          const Text('提示：所有单据保存在本机 SQLite 数据库，确认后自动更新库存，全程离线可用。',
              style: TextStyle(fontSize: 12, color: AppColors.textSub)),
        ])),
      ]),
    );
  }

  Widget _bigEntry(BuildContext context, IconData icon, String title, String sub, Color color,
      Widget Function(BuildContext) page) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: page)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFF1A2233).withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
        ),
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
    );
  }

  Widget _quick(BuildContext context, String label, IconData icon, Color color, Widget page) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.4)),
        backgroundColor: Colors.white,
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }
}
