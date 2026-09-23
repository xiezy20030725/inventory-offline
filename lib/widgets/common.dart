import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme.dart';

/// 通用组件库：Toast、确认弹窗、徽章、空状态、分区卡片等

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontSize: 14)),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(milliseconds: 1600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ));
}

Future<bool> confirm(BuildContext context, String title, String content) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      content: Text(content, style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
        ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('确定')),
      ],
    ),
  );
  return r ?? false;
}

/// 单行文本输入弹窗（扫码失败手动输入等场景）
Future<String?> inputDialog(BuildContext context, String title, {String hint = '', String initial = ''}) async {
  final ctrl = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        ElevatedButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('确定')),
      ],
    ),
  );
  return r;
}

/// 预警类型徽章（不足/临期/积压/过期）
class AlertBadge extends StatelessWidget {
  final String type;
  const AlertBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    Color c;
    switch (type) {
      case AlertInfo.typeOver:
        c = AppColors.red;
        break;
      case AlertInfo.typeExpired:
        c = AppColors.red;
        break;
      case AlertInfo.typeInsufficient:
        c = AppColors.orange;
        break;
      default:
        c = AppColors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(AlertInfo.typeNames[type] ?? '',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
    );
  }
}

/// 单据状态chip
class StatusChip extends StatelessWidget {
  final String text;
  final int status; // 0草稿/进行中 1已完成 2已作废
  const StatusChip({super.key, required this.text, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = status == 1
        ? AppColors.green
        : status == 2
            ? AppColors.textSub
            : AppColors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
    );
  }
}

/// 分区白卡片
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets margin;
  final EdgeInsets padding;
  const SectionCard({super.key, required this.child, this.margin = const EdgeInsets.fromLTRB(12, 10, 12, 0), this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF1A2233).withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

/// 空状态
class EmptyView extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyView({super.key, this.text = '暂无数据', this.icon = Icons.inventory_2_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 52, color: const Color(0xFFC6CCD8)),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textSub)),
      ]),
    );
  }
}

/// 常用功能宫格项
class FuncItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const FuncItem({super.key, required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.85), color]),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 7),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textDark)),
      ]),
    );
  }
}

/// 商品图片（本地路径或占位图标）
class ProductThumb extends StatelessWidget {
  final String? path;
  final double size;
  final String category;
  const ProductThumb({super.key, this.path, this.size = 44, this.category = ''});

  @override
  Widget build(BuildContext context) {
    final icon = _categoryIcon();
    final color = _categoryColor();
    if (path != null && path!.isNotEmpty && File(path!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(path!), width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _photon(icon, color)),
      );
    }
    return _photon(icon, color);
  }

  Widget _photon(IconData icon, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: size * 0.55, color: color),
      );

  IconData _categoryIcon() {
    if (category.contains('油')) return Icons.opacity;
    if (category.contains('劳保')) return Icons.health_and_safety_outlined;
    if (category.contains('工具')) return Icons.build_outlined;
    if (category.contains('辅')) return Icons.category_outlined;
    return Icons.widgets_outlined;
  }

  Color _categoryColor() {
    if (category.contains('油')) return AppColors.indigo;
    if (category.contains('劳保')) return AppColors.green;
    if (category.contains('工具')) return AppColors.orange;
    return AppColors.blue;
  }
}

/// 底部操作栏（单据页通用）
class BottomActionBar extends StatelessWidget {
  final List<Widget> children;
  const BottomActionBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: const Color(0xFF1A2233).withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: Row(children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: children[i]),
        ]
      ]),
    );
  }
}
