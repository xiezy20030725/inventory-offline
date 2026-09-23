import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/stock_service.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/scanner.dart';
import '../../widgets/common.dart';
import 'product_edit_page.dart';

/// 商品管理：条码/名称/分类模糊搜索，扫码搜索，库存列
class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key, this.pickMode = false});

  final bool pickMode;

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final StockService _svc = StockService();
  final TextEditingController _kwCtrl = TextEditingController();
  List<Product> _list = [];
  Map<int, double> _stockMap = {};

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _kwCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String kw) async {
    _list = await _svc.products(keyword: kw);
    final state = context.read<AppState>();
    final rows = await _svc.queryStock(state.currentWarehouseId);
    _stockMap = {};
    for (final r in rows) {
      _stockMap[r.product.id] = (_stockMap[r.product.id] ?? 0) + r.stock.quantity;
    }
    if (mounted) setState(() {});
  }

  Future<void> _scanSearch() async {
    final code = await scan(context);
    if (code != null && code.isNotEmpty) {
      _kwCtrl.text = code;
      _search(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('商品管理'), backgroundColor: AppColors.bg, actions: [
        IconButton(onPressed: _scanSearch, icon: const Icon(Icons.qr_code_scanner)),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductEditPage()));
            _search(_kwCtrl.text);
          },
        ),
      ]),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _kwCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜索条码 / 名称 / 规格 / 分类',
              suffixIcon: _kwCtrl.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () { _kwCtrl.clear(); _search(''); }),
            ),
            onChanged: _search,
          ),
        ),
        Expanded(
          child: _list.isEmpty
              ? const EmptyView(text: '未找到商品')
              : RefreshIndicator(
                  onRefresh: () => _search(_kwCtrl.text),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final p = _list[i];
                      final stock = _stockMap[p.id] ?? 0;
                      final low = p.minStock > 0 && stock < p.minStock;
                      return SectionCard(
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            if (widget.pickMode) {
                              Navigator.pop(context, p);
                              return;
                            }
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductEditPage(product: p)));
                            _search(_kwCtrl.text);
                          },
                          child: Row(children: [
                            ProductThumb(path: p.imagePath, category: p.category ?? ''),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text('${p.barcode ?? '-'}  ${p.spec ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('${fmtQty(stock)} ${p.unit}',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                                      color: low ? AppColors.orange : AppColors.textDark)),
                              const SizedBox(height: 3),
                              Text('¥${NumberFormatDec().decFmt(p.costPrice)}', style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
    );
  }
}
