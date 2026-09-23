import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/alert_service.dart';
import '../../services/backup_service.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// 设置：数据备份与恢复 / 数据导出 / 预警设置 / 应用锁 / 关于
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置'), backgroundColor: AppColors.bg),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        _group('数据管理', [
          _item(context, Icons.backup_outlined, AppColors.blue, '数据备份与恢复', '本地备份 / 恢复 / 自动安全备份', () => _backupManager(context)),
          _item(context, Icons.file_download_outlined, AppColors.green, '数据导出', '导出商品档案 / 库存明细 CSV', () => _exportSheet(context)),
        ]),
        _group('预警与安全', [
          _item(context, Icons.notifications_outlined, AppColors.orange, '预警设置', '预警开关 / 立即检测', () => _alertSettings(context)),
          _item(context, Icons.lock_outline, AppColors.red, '应用锁', '进入APP需输入4位密码', () => _lockSettings(context)),
        ]),
        _group('其他', [
          _item(context, Icons.info_outline, AppColors.indigo, '关于系统', '版本信息 / 存储说明', () => _about(context)),
        ]),
      ]),
    );
  }

  Widget _group(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(4, 6, 0, 8), child: Text(title,
          style: const TextStyle(fontSize: 13, color: AppColors.textSub))),
      SectionCard(margin: EdgeInsets.zero, padding: EdgeInsets.zero,
          child: Column(children: [for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ]])),
      const SizedBox(height: 14),
    ]);
  }

  Widget _item(BuildContext context, IconData icon, Color color, String title, String sub, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.textSub)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.textSub),
        ]),
      ),
    );
  }

  // ---------------- 备份与恢复 ----------------
  Future<void> _backupManager(BuildContext context) async {
    final svc = BackupService();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => StatefulBuilder(builder: (c, setS) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('数据备份与恢复', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('备份保存在本机应用目录，数据不离开设备。恢复前会自动再做一次安全备份。',
                style: TextStyle(fontSize: 12, color: AppColors.textSub)),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final path = await svc.backup();
                  if (c.mounted) {
                    toast(c, '备份完成：${path.split(Platform.pathSeparator).last}');
                    setS(() {});
                  }
                } catch (e) {
                  toast(c, e.toString().replaceFirst('Exception: ', ''));
                }
              },
              icon: const Icon(Icons.add_a_photo_outlined, size: 20),
              label: const Text('立即备份'),
            ),
            const SizedBox(height: 8),
            const Text('历史备份', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            FutureBuilder<List<FileSystemEntity>>(
              future: svc.backups(),
              builder: (c, snap) {
                final list = snap.data ?? [];
                if (list.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('暂无备份文件', style: TextStyle(fontSize: 12, color: AppColors.textSub)));
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final f = list[i];
                      final st = f.statSync();
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined, color: AppColors.blue),
                        title: Text(f.path.split(Platform.pathSeparator).last, style: const TextStyle(fontSize: 13)),
                        subtitle: Text('${st.size ~/ 1024} KB · ${st.modified}'.substring(0, 33), style: const TextStyle(fontSize: 11)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          TextButton(onPressed: () async {
                            if (!await confirm(c, '恢复数据', '将用该备份覆盖当前数据，恢复前会自动安全备份，确定继续？')) return;
                            try {
                              await svc.restore(f.path);
                              if (c.mounted) {
                                toast(c, '恢复成功，请重启应用');
                                if (c.mounted) Navigator.pop(c);
                              }
                            } catch (e) {
                              toast(c, e.toString().replaceFirst('Exception: ', ''));
                            }
                          }, child: const Text('恢复')),
                          IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.red),
                              onPressed: () async {
                                await svc.deleteBackup(f.path);
                                setS(() {});
                              }),
                        ]),
                      );
                    },
                  ),
                );
              },
            ),
          ]),
        ),
      )),
    );
  }

  // ---------------- 数据导出 ----------------
  Future<void> _exportSheet(BuildContext context) async {
    final svc = BackupService();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('数据导出（CSV，Excel可直接打开）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: AppColors.green),
              title: const Text('导出商品档案'),
              onTap: () async {
                final path = await svc.exportProductsCsv();
                if (c.mounted) {
                  toast(c, '已导出：${path.split(Platform.pathSeparator).last}');
                  Navigator.pop(c);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.assessment_outlined, color: AppColors.blue),
              title: const Text('导出库存明细'),
              onTap: () async {
                final path = await svc.exportStockCsv();
                if (c.mounted) {
                  toast(c, '已导出：${path.split(Platform.pathSeparator).last}');
                  Navigator.pop(c);
                }
              },
            ),
          ]),
        ),
      ),
    );
  }

  // ---------------- 预警设置 ----------------
  Future<void> _alertSettings(BuildContext context) async {
    final svc = AlertService();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('预警设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('每日自动本地扫描：库存不足 / 积压 / 临期 / 过期，通过本地通知提醒，全程离线。',
                style: TextStyle(fontSize: 12, color: AppColors.textSub)),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () async {
                final state = c.read<AppState>();
                final n = await svc.dailyScanAndNotify(state.currentWarehouseId);
                await state.refreshHome();
                if (c.mounted) {
                  toast(c, '检测完成：共 $n 条预警');
                  Navigator.pop(c);
                }
              },
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('立即检测预警'),
            ),
          ]),
        ),
      ),
    );
  }

  // ---------------- 应用锁 ----------------
  Future<void> _lockSettings(BuildContext context) async {
    final sp = await SharedPreferences.getInstance();
    final enabledCtrl = TextEditingController(text: sp.getString('app_lock_pin') ?? '');
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => StatefulBuilder(builder: (c, setS) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('应用锁', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('开启应用锁', style: TextStyle(fontSize: 15)),
              subtitle: const Text('进入APP需输入4位密码', style: TextStyle(fontSize: 12)),
              value: sp.getBool('app_lock_enabled') ?? false,
              onChanged: (v) {
                if (v && (sp.getString('app_lock_pin') ?? '').length != 4) {
                  toast(c, '请先设置4位密码');
                  return;
                }
                sp.setBool('app_lock_enabled', v);
                setS(() {});
              },
            ),
            TextField(
              controller: enabledCtrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(labelText: '设置4位密码', counterText: ''),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                if (enabledCtrl.text.length != 4 || int.tryParse(enabledCtrl.text) == null) {
                  toast(c, '密码必须是4位数字');
                  return;
                }
                sp.setString('app_lock_pin', enabledCtrl.text);
                sp.setBool('app_lock_enabled', true);
                toast(c, '应用锁已启用');
                Navigator.pop(c);
              },
              child: const Text('保存密码并启用'),
            ),
          ]),
        ),
      )),
    );
  }

  // ---------------- 关于 ----------------
  Future<void> _about(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('离线库存管理系统', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('版本 1.0.0', style: TextStyle(fontSize: 13)),
          SizedBox(height: 8),
          Text('纯本地离线运行：数据存储于本机 SQLite 数据库，图片与备份保存在应用私有目录，无需任何网络与服务器。',
              style: TextStyle(fontSize: 13, color: AppColors.textSub)),
          SizedBox(height: 8),
          Text('支持：商品档案 / 仓库货位 / 入库 / 出库 / 调拨 / 盘点 / 预警 / 备份恢复 / CSV导出。',
              style: TextStyle(fontSize: 13, color: AppColors.textSub)),
        ]),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(c), child: const Text('知道了'))],
      ),
    );
  }
}
