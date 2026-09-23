import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/stock_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils/scanner.dart';
import '../widgets/common.dart';
import 'alerts_page.dart';
import 'archive/product_edit_page.dart';
import 'archive/product_list_page.dart';
import 'archive/stock_query_page.dart';
import 'archive/warehouse_page.dart';
import 'business/check/check_create_page.dart';
import 'business/transfer/transfer_edit_page.dart';
import 'business/stock_in/stock_in_edit_page.dart';
import 'business/stock_out/stock_out_edit_page.dart';

/// 首页：1:1 复刻设计稿
/// 结构：深蓝渐变头部（仓库切换/扫码/搜索/离线模式）→ 4张统计卡 → 库存预警 → 常用功能
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final StockService _svc = StockService();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.stats;
    return Scaffold(
      body: Stack(children: [
        // 顶部深蓝渐变背景
        const Positioned(
          top: 0, left: 0, right: 0, height: 300,
          child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.headerGradient)),
        ),
        SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildHeader(state),
              const SizedBox(height: 6),
              _buildStatCards(s),
              _buildDots(),
              _buildAlertCard(state),
              _buildFuncCard(context, state),
            ]),
          ),
        ),
      ]),
    );
  }

  // ---------- 头部：仓库切换 / 扫码 / 搜索 / 离线模式 ----------
  Widget _buildHeader(AppState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _switchWarehouse(state),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(state.currentWarehouseName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              const Icon(Icons.expand_more, color: Colors.white, size: 22),
            ]),
          ),
        ),
        const Spacer(),
        InkWell(onTap: _scanStock, child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24)),
        const SizedBox(width: 18),
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListPage())),
          child: const Icon(Icons.search, color: Colors.white, size: 25),
        ),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off, size: 13, color: Colors.white.withOpacity(0.85)),
            const SizedBox(width: 4),
            Text('离线模式', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85))),
          ]),
        ),
      ]),
    );
  }

  Future<void> _switchWarehouse(AppState state) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(14), child: Text('切换仓库', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          for (final w in state.warehouses)
            ListTile(
              title: Text(w.name),
              subtitle: (w.address ?? '').isEmpty ? null : Text(w.address!, style: const TextStyle(fontSize: 12)),
              trailing: w.id == state.currentWarehouseId ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
              onTap: () => Navigator.pop(c, w.id),
            ),
          const SizedBox(height: 6),
        ]),
      ),
    );
    if (picked != null) await state.switchWarehouse(picked);
  }

  // ---------- 扫码查库存 ----------
  Future<void> _scanStock() async {
    final code = await scan(context);
    if (code == null || code.isEmpty) return;
    final product = await _svc.productByBarcode(code);
    if (!mounted) return;
    if (product == null) {
      final create = await confirm(context, '未找到商品', '条码 $code 尚未建档，是否立即创建商品档案？');
      if (create && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductEditPage(initialBarcode: code)));
      }
      return;
    }
    final state = context.read<AppState>();
    final rows = await _svc.queryStock(null, keyword: product.barcode ?? product.name);
    final total = rows.fold<double>(0, (s, r) => s + r.stock.quantity);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(product.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('条码：${product.barcode ?? '-'}  规格：${product.spec ?? '-'}', style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
          const SizedBox(height: 10),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(r.warehouseName, style: const TextStyle(fontSize: 14)),
                  Text('${fmtQty(r.stock.quantity)} ${product.unit}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ]),
              )),
          if (rows.isEmpty) Text('当前无库存记录', style: const TextStyle(fontSize: 13, color: AppColors.textSub)),
          const Divider(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('合计', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text('${fmtQty(total)} ${product.unit}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ]),
        ]),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(c), child: const Text('知道了'))],
      ),
    );
    if (rows.isNotEmpty) {
      // 展示当前仓库分布后保持首页数据一致
      await context.read<AppState>().refreshHome();
    }
  }

  // ---------- 四张统计卡片 ----------
  Widget _buildStatCards(HomeStats s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Expanded(child: _statCard(
          bg: AppColors.blueBg, icon: Icons.currency_yuan, iconColor: AppColors.blue, circleIcon: true,
          value: NumberFormatDec().decFmt(s.totalValue), label: '总库存金额',
          delta: HomeStats.fmtPct(s.totalValueDelta), deltaColor: AppColors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _statCard(
          bg: AppColors.greenBg, icon: Icons.move_to_inbox, iconColor: AppColors.green,
          value: NumberFormatDec().intFmt(s.todayInNum), label: '今日入库',
          delta: HomeStats.fmtPct(s.todayInDelta), deltaColor: AppColors.green)),
        const SizedBox(width: 8),
        Expanded(child: _statCard(
          bg: AppColors.redBg, icon: Icons.outbox, iconColor: AppColors.red,
          value: NumberFormatDec().intFmt(s.todayOutNum), label: '今日出库',
          delta: HomeStats.fmtPct(s.todayOutDelta), deltaColor: AppColors.red)),
        const SizedBox(width: 8),
        Expanded(child: _statCard(
          bg: AppColors.orangeBg, icon: Icons.notifications, iconColor: AppColors.orange,
          value: NumberFormatDec().intFmt(s.alertCount.toDouble()), label: '预警数量',
          delta: HomeStats.fmtPct(s.alertDelta), deltaColor: AppColors.orange)),
      ]),
    );
  }

  Widget _statCard({
    required Color bg, required IconData icon, required Color iconColor, bool circleIcon = false,
    required String value, required String label, required String delta, required Color deltaColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      height: 138,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        circleIcon
            ? Container(
                width: 34, height: 34,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: iconColor, width: 1.6)),
                child: Icon(icon, size: 19, color: iconColor))
            : Icon(icon, size: 32, color: iconColor),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, maxLines: 1,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.1)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
        const SizedBox(height: 6),
        Row(children: [
          Text(delta, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: deltaColor)),
        ]),
      ]),
    );
  }

  Widget _buildDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (int i = 0; i < 4; i++)
          Container(
            width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == 0 ? const Color(0xFF2F6BFF) : const Color(0xFFC9CFDA),
            ),
          ),
      ]),
    );
  }

  // ---------- 库存预警卡片 ----------
  Widget _buildAlertCard(AppState state) {
    final alerts = state.alerts.take(3).toList();
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.report, color: AppColors.orange, size: 17),
          ),
          const SizedBox(width: 8),
          const Text('库存预警', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const Spacer(),
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsPage())),
            child: Row(children: const [
              Text('查看全部', style: TextStyle(fontSize: 13, color: Color(0xFF98A2B3))),
              Icon(Icons.chevron_right, size: 18, color: Color(0xFF98A2B3)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        if (alerts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: Text('暂无预警，库存状态良好', style: TextStyle(fontSize: 13, color: AppColors.textSub))),
          )
        else
          for (final a in alerts) _alertItem(a),
      ]),
    );
  }

  Widget _alertItem(AlertInfo a) {
    String? sub;
    if (a.type == AlertInfo.typeExpiring) sub = '剩余 ${a.remainDays ?? 0} 天';
    if (a.type == AlertInfo.typeOver) sub = '已积压 ${a.overdueDays ?? 0} 天';
    if (a.type == AlertInfo.typeExpired) sub = '已过期 ${a.overdueDays ?? 0} 天';
    if (a.type == AlertInfo.typeInsufficient) sub = '当前库存 ${fmtQty(a.stock)} ${a.product.unit}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.itemBg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        ProductThumb(path: a.product.imagePath, category: a.product.category ?? ''),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 3),
            Text(a.product.specText, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          AlertBadge(type: a.type),
          if (sub != null) Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSub)),
          ),
        ]),
      ]),
    );
  }

  // ---------- 常用功能 ----------
  Widget _buildFuncCard(BuildContext context, AppState state) {
    return SectionCard(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('常用功能', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 18,
          childAspectRatio: 0.86,
          children: [
            FuncItem(icon: Icons.qr_code_scanner_rounded, label: '扫码查库存', color: AppColors.blue, onTap: _scanStock),
            FuncItem(icon: Icons.move_to_inbox, label: '快速入库', color: AppColors.green, onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const StockInEditPage()));
              if (context.mounted) await context.read<AppState>().refreshHome();
            }),
            FuncItem(icon: Icons.outbox, label: '快速出库', color: AppColors.red, onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const StockOutEditPage()));
              if (context.mounted) await context.read<AppState>().refreshHome();
            }),
            FuncItem(icon: Icons.swap_horiz, label: '库存调拨', color: AppColors.orange, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferEditPage()));
            }),
            FuncItem(icon: Icons.assignment_outlined, label: '新建盘点', color: AppColors.blue, onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckCreatePage()));
              if (context.mounted) await context.read<AppState>().refreshHome();
            }),
            FuncItem(icon: Icons.inventory_2_outlined, label: '商品管理', color: AppColors.green, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListPage()));
            }),
            FuncItem(icon: Icons.map_outlined, label: '仓库货位', color: AppColors.blue, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehousePage()));
            }),
            FuncItem(icon: Icons.plagiarism_outlined, label: '库存查询', color: AppColors.indigo, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StockQueryPage()));
            }),
          ],
        ),
      ]),
    );
  }
}
