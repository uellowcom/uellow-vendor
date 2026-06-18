import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Bulk product import — paste CSV text, submit, see a per-row result summary.
/// Dependency-free (no file picker): vendors paste from a spreadsheet export.
class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});
  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;

  static const _header = 'name_en,name_ar,sku,barcode,cost,price,category,description';
  static const _sample =
      '$_header\n'
      'Cotton T-Shirt,تيشيرت قطن,TS-001,,3.5,9.9,Fashion,Soft cotton tee\n'
      'Coffee Mug,كوب قهوة,MUG-002,,1.2,4.5,Home,Ceramic 350ml';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ar = VendorApi.instance.lang == 'ar';
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await VendorApi.instance.productsImport(text);
      if (!mounted) return;
      final created = res['created'] ?? 0;
      final errCount = res['error_count'] ?? 0;
      final errs = (res['errors'] as List?)?.cast<String>() ?? const [];
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(ar ? 'نتيجة الاستيراد' : 'Import result'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.check_circle, color: UC.success, size: 20),
                const SizedBox(width: 8),
                Text(
                  ar ? '$created منتج تم إنشاؤه (قيد المراجعة)'
                      : '$created product(s) created (under review)',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ]),
              if (errCount > 0) ...[
                const SizedBox(height: 10),
                Text(
                  ar ? '$errCount صف به خطأ:' : '$errCount row(s) with errors:',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: UC.dangerDk),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Text(errs.join('\n'), style: UT.small),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(ar ? 'حسناً' : 'OK'),
            ),
          ],
        ),
      );
      if (mounted && created != 0) {
        _ctrl.clear();
        Navigator.pop(context, true); // signal caller to refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'استيراد جماعي' : 'Bulk import')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: UC.yellowFaint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: UC.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ar ? 'كيف يعمل' : 'How it works', style: UT.h3),
                const SizedBox(height: 6),
                Text(
                  ar
                      ? 'الصق بيانات CSV من Excel/Google Sheets. الصف الأول هو العناوين. '
                          'كل المنتجات تُنشأ "قيد المراجعة" حتى يعتمدها الأدمن.'
                      : 'Paste CSV from Excel/Google Sheets. First row is the header. '
                          'All products are created "under review" until an admin approves.',
                  style: UT.body,
                ),
                const SizedBox(height: 8),
                Text(ar ? 'الأعمدة:' : 'Columns:', style: UT.tiny),
                const SizedBox(height: 2),
                const SelectableText(_header,
                    style: TextStyle(
                        fontSize: 11, fontFamily: 'monospace', color: UC.brown)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _ctrl.text = _sample),
              icon: const Icon(Icons.bolt, size: 18),
              label: Text(ar ? 'إدراج مثال' : 'Insert example'),
            ),
          ),
          TextField(
            controller: _ctrl,
            maxLines: 12,
            minLines: 8,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              hintText: '$_header\n...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: UC.brown))
                  : const Icon(Icons.upload_file),
              label: Text(
                ar ? 'استيراد المنتجات' : 'Import products',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
