import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/models.dart';
import '../../services/stock_service.dart';
import '../../theme.dart';
import '../../utils/scanner.dart';
import '../../widgets/common.dart';

/// 商品编辑：条码扫码、图片拍摄、预警参数（上下限/临期天数）
class ProductEditPage extends StatefulWidget {
  final Product? product;
  final String? initialBarcode;
  const ProductEditPage({super.key, this.product, this.initialBarcode});

  @override
  State<ProductEditPage> createState() => _ProductEditPageState();
}

class _ProductEditPageState extends State<ProductEditPage> {
  final StockService _svc = StockService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _barcode;
  late final TextEditingController _name;
  late final TextEditingController _spec;
  late final TextEditingController _category;
  late final TextEditingController _unit;
  late final TextEditingController _cost;
  late final TextEditingController _sale;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late final TextEditingController _warnDays;
  String? _imagePath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _barcode = TextEditingController(text: p?.barcode ?? widget.initialBarcode ?? '');
    _name = TextEditingController(text: p?.name ?? '');
    _spec = TextEditingController(text: p?.spec ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _unit = TextEditingController(text: p?.unit ?? '件');
    _cost = TextEditingController(text: p == null ? '' : p.costPrice.toString());
    _sale = TextEditingController(text: p == null ? '' : p.salePrice.toString());
    _min = TextEditingController(text: p == null ? '' : fmtQty(p.minStock));
    _max = TextEditingController(text: p == null ? '' : fmtQty(p.maxStock));
    _warnDays = TextEditingController(text: (p?.warnDays ?? 30).toString());
    _imagePath = p?.imagePath;
  }

  @override
  void dispose() {
    for (final c in [_barcode, _name, _spec, _category, _unit, _cost, _sale, _min, _max, _warnDays]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await scan(context);
    if (code != null && code.isNotEmpty) setState(() => _barcode.text = code);
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (photo == null) return;
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'products'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final target = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(photo.path).copy(target);
      setState(() => _imagePath = target);
    } catch (_) {
      toast(context, '选图不可用或已取消');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final product = (widget.product ?? Product(name: '', unit: '', createTime: now, updateTime: now))
        ..barcode = _barcode.text.trim().isEmpty ? null : _barcode.text.trim()
        ..name = _name.text.trim()
        ..spec = _spec.text.trim().isEmpty ? null : _spec.text.trim()
        ..category = _category.text.trim().isEmpty ? null : _category.text.trim()
        ..unit = _unit.text.trim().isEmpty ? '件' : _unit.text.trim()
        ..costPrice = double.tryParse(_cost.text) ?? 0
        ..salePrice = double.tryParse(_sale.text) ?? 0
        ..minStock = double.tryParse(_min.text) ?? 0
        ..maxStock = double.tryParse(_max.text) ?? 0
        ..warnDays = int.tryParse(_warnDays.text) ?? 30
        ..imagePath = _imagePath
        ..updateTime = now;
      await _svc.saveProduct(product);
      if (mounted) {
        toast(context, '保存成功');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        if (msg.contains('UNIQUE')) {
          toast(context, '条码已存在：${_barcode.text}');
        } else {
          toast(context, msg.replaceFirst('Exception: ', ''));
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.product == null;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(isNew ? '新增商品' : '编辑商品'), backgroundColor: AppColors.bg),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          SectionCard(child: Column(children: [
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickImage,
                child: _imagePath != null && File(_imagePath!).existsSync()
                    ? ClipRRect(borderRadius: BorderRadius.circular(14),
                        child: Image.file(File(_imagePath!), width: 84, height: 84, fit: BoxFit.cover))
                    : Container(
                        width: 84, height: 84,
                        decoration: BoxDecoration(color: AppColors.itemBg, borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.camera_alt_outlined, color: AppColors.textSub)),
              ),
            ),
            const SizedBox(height: 6),
            const Text('商品图片（点击更换）', style: TextStyle(fontSize: 11, color: AppColors.textSub)),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: TextFormField(
                controller: _barcode,
                decoration: const InputDecoration(labelText: '商品条码', prefixIcon: Icon(Icons.qr_code)),
              )),
              IconButton(onPressed: _scanBarcode, icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary)),
            ]),
            const SizedBox(height: 10),
            TextFormField(
              controller: _name,
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入商品名称' : null,
              decoration: const InputDecoration(labelText: '商品名称 *'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: _spec, decoration: const InputDecoration(labelText: '规格型号'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _category, decoration: const InputDecoration(labelText: '商品分类'))),
            ]),
            const SizedBox(height: 10),
            TextFormField(controller: _unit,
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入计量单位' : null,
              decoration: const InputDecoration(labelText: '计量单位 *', helperText: '如：个 / 桶 / 包')),
          ])),
          const SizedBox(height: 10),
          SectionCard(child: Column(children: [
            Row(children: [
              Expanded(child: TextFormField(controller: _cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '成本价'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _sale,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '售价'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextFormField(controller: _min,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '库存下限', helperText: '低于触发预警'))),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(controller: _max,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '库存上限', helperText: '高于触发积压'))),
            ]),
            const SizedBox(height: 10),
            TextFormField(controller: _warnDays,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '临期预警天数', helperText: '有效期内剩余天数≤该值时预警')),
          ])),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(_saving ? '保存中...' : '保存'),
          ),
          if (!isNew) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                if (!await confirm(context, '删除商品', '确定删除该商品档案？')) return;
                try {
                  await _svc.deleteProduct(widget.product!.id!);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
                }
              },
              child: const Text('删除商品', style: TextStyle(color: AppColors.red)),
            ),
          ],
        ]),
      ),
    );
  }
}
