import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme.dart';

/// 扫码页：摄像头识别条码后返回；底部支持手动输入条码（弱光/权限异常兜底）
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  MobileScannerController? _controller;
  bool _done = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final v = barcode.rawValue;
      if (v != null && v.isNotEmpty) {
        _done = true;
        Navigator.pop(context, v);
        return;
      }
    }
  }

  void _manualInput() async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('手动输入条码'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(controller: ctrl, autofocus: true, keyboardType: TextInputType.text,
            decoration: const InputDecoration(hintText: '输入或使用扫码枪输入条码')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('确定')),
        ],
      ),
    );
    if (r != null && r.isNotEmpty) {
      if (!mounted) return;
      Navigator.pop(context, r);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('扫一扫'),
        actions: [
          TextButton(onPressed: _manualInput, child: const Text('手动输入', style: TextStyle(color: Colors.white))),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _controller ??= MobileScannerController(
            detectionSpeed: DetectionSpeed.normal,
            formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.code128, BarcodeFormat.qrCode],
          ),
          onDetect: _onDetect,
          errorBuilder: (c, error, _) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 60),
              const SizedBox(height: 12),
              const Text('相机不可用，请手动输入条码', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _manualInput, child: const Text('手动输入')),
            ]),
          ),
        ),
        // 取景框
        Center(
          child: Container(
            width: 260,
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary.withOpacity(0.9), width: 2.5),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ]),
    );
  }
}

/// 打开扫码页并返回条码（异常时返回 null，调用方可降级手动输入）
Future<String?> scan(BuildContext context) async {
  try {
    return await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScannerPage()));
  } catch (_) {
    return null;
  }
}
