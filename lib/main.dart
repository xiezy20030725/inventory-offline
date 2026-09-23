import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'state/app_state.dart';
import 'pages/main_shell.dart';
import 'theme.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: '离线库存管理',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const LockGate(child: MainShell()),
      ),
    );
  }
}

/// 应用锁门卫：开启应用锁后需输入4位PIN进入
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  bool _checked = false;
  bool _locked = false;
  String _pin = '';

  @override
  void initState() {
    super.initState();
    _loadLock();
  }

  Future<void> _loadLock() async {
    final sp = await SharedPreferences.getInstance();
    final enabled = sp.getBool('app_lock_enabled') ?? false;
    final saved = sp.getString('app_lock_pin') ?? '';
    if (!mounted) return;
    setState(() {
      _locked = enabled && saved.isNotEmpty;
      _pin = saved;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_locked) return widget.child;
    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: SafeArea(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.lock_outline, color: Colors.white70, size: 56),
          const SizedBox(height: 16),
          const Text('请输入应用锁密码', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < 4; i++)
              Container(
                width: 16, height: 16, margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _input.length > i ? Colors.white : Colors.white24,
                ),
              ),
          ]),
          const SizedBox(height: 24),
          _buildPad(),
        ]),
      ),
    );
  }

  String _input = '';

  Widget _buildPad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 70),
      child: Column(children: [
        for (final row in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['C', '0', '⌫']])
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final k in row)
              Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: 64, height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12, foregroundColor: Colors.white, elevation: 0),
                    onPressed: () {
                      setState(() {
                        if (k == 'C') {
                          _input = '';
                        } else if (k == '⌫') {
                          if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
                        } else if (_input.length < 4) {
                          _input += k;
                          if (_input.length == 4) {
                            if (_input == _pin) {
                              _locked = false;
                            } else {
                              _input = '';
                              toast(context, '密码错误');
                            }
                          }
                        }
                      });
                    },
                    child: Text(k, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              ),
          ]),
      ]),
    );
  }
}
