import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Barcode scanner — scan a product barcode/SKU to look it up and update stock.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _ctrl = MobileScannerController();
  bool _handling = false;

  bool get _ar => VendorApi.instance.lang == 'ar';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture cap) async {
    if (_handling) return;
    final code = cap.barcodes.isNotEmpty ? (cap.barcodes.first.rawValue ?? '') : '';
    if (code.isEmpty) return;
    setState(() => _handling = true);
    await _ctrl.stop();
    try {
      final prod = await VendorApi.instance.productByBarcode(code);
      if (!mounted) return;
      if (prod == null) {
        await _notFound(code);
      } else {
        await _showProduct(prod);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() => _handling = false);
        _ctrl.start();
      }
    }
  }

  Future<void> _notFound(String code) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_ar ? 'غير موجود' : 'Not found'),
          content: Text(_ar ? 'لا يوجد منتج بالباركود:\n$code' : 'No product for barcode:\n$code'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );

  Future<void> _showProduct(ProductDetail p) async {
    final lang = _ar ? 'ar' : 'en';
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name.t(lang), style: UT.h2),
            const SizedBox(height: 6),
            Text('${_ar ? 'السعر' : 'Price'}: ${p.listPrice.format(lang)}', style: UT.body),
            Text('${_ar ? 'المخزون' : 'Stock'}: ${p.qty.toStringAsFixed(0)}', style: UT.body),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, '/product', arguments: {'id': p.id});
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(_ar ? 'فتح' : 'Open'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _updateStock(p, lang);
                  },
                  icon: const Icon(Icons.edit),
                  label: Text(_ar ? 'تعديل المخزون' : 'Set stock'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _updateStock(ProductDetail p, String lang) async {
    final ctrl = TextEditingController(text: p.qty.toStringAsFixed(0));
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.name.t(lang)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: _ar ? 'الكمية الجديدة' : 'New quantity'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_ar ? 'إلغاء' : 'Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_ar ? 'حفظ' : 'Save')),
        ],
      ),
    );
    if (go != true) return;
    final qty = double.tryParse(ctrl.text.trim());
    if (qty == null) return;
    try {
      await VendorApi.instance.productSetStock(p.id, qty);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_ar ? 'تم تحديث المخزون' : 'Stock updated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_ar ? 'مسح الباركود' : 'Scan barcode'),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), onPressed: () => _ctrl.toggleTorch()),
          IconButton(icon: const Icon(Icons.cameraswitch), onPressed: () => _ctrl.switchCamera()),
        ],
      ),
      body: Stack(children: [
        MobileScanner(controller: _ctrl, onDetect: _onDetect),
        if (_handling) const Center(child: CircularProgressIndicator()),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            color: Colors.black54,
            padding: const EdgeInsets.all(14),
            child: Text(
              _ar ? 'وجّه الكاميرا نحو باركود المنتج' : 'Point the camera at a product barcode',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ]),
    );
  }
}
