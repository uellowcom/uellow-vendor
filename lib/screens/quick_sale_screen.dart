import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Quick / counter sale — build a confirmed order from the vendor's products.
class QuickSaleScreen extends StatefulWidget {
  const QuickSaleScreen({super.key});
  @override
  State<QuickSaleScreen> createState() => _QuickSaleScreenState();
}

class _QuickSaleScreenState extends State<QuickSaleScreen> {
  final List<_Line> _lines = [];
  final _name = TextEditingController();
  final _phone = TextEditingController();
  List<ProductSummary> _products = [];
  bool _loading = true;
  bool _busy = false;

  bool get _ar => VendorApi.instance.lang == 'ar';
  String get _lang => _ar ? 'ar' : 'en';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      var p = await VendorApi.instance.products(state: 'approved');
      if (p.isEmpty) p = await VendorApi.instance.products();
      if (!mounted) return;
      setState(() {
        _products = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _addLine() {
    if (_products.isEmpty) return;
    setState(() => _lines.add(_Line(_products.first, 1)));
  }

  double get _total => _lines.fold(0.0, (s, l) => s + l.product.listPrice.amount * l.qty);

  Future<void> _submit() async {
    if (_lines.isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await VendorApi.instance.quickSale(
        [for (final l in _lines) {'product_id': l.product.id, 'qty': l.qty}],
        customerName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        customerPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_ar ? 'تم البيع' : 'Sale created'),
          content: Text(_ar
              ? 'الطلب ${res['name']} — ${(res['amount'] as Map)['amount']} د.ك'
              : 'Order ${res['name']} — ${(res['amount'] as Map)['amount']} KD'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      if (mounted) {
        setState(() {
          _lines.clear();
          _name.clear();
          _phone.clear();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_ar ? 'بيع سريع' : 'Quick sale')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.all(12), children: [
                  TextField(controller: _name, decoration: InputDecoration(labelText: _ar ? 'اسم العميل (اختياري)' : 'Customer name (optional)')),
                  const SizedBox(height: 8),
                  TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: _ar ? 'الهاتف (اختياري)' : 'Phone (optional)')),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Text(_ar ? 'المنتجات' : 'Products', style: UT.h3)),
                    TextButton.icon(onPressed: _addLine, icon: const Icon(Icons.add, size: 18), label: Text(_ar ? 'إضافة' : 'Add')),
                  ]),
                  for (int i = 0; i < _lines.length; i++) _lineCard(i),
                  if (_lines.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(_ar ? 'أضف منتجاً للبدء' : 'Add a product to start', style: UT.small)),
                ]),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(child: Text('${_ar ? 'الإجمالي' : 'Total'}: ${_total.toStringAsFixed(3)} ${_ar ? 'د.ك' : 'KD'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                    ElevatedButton.icon(
                      onPressed: (_lines.isEmpty || _busy) ? null : _submit,
                      icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown)) : const Icon(Icons.point_of_sale),
                      label: Text(_ar ? 'إتمام البيع' : 'Complete sale'),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }

  Widget _lineCard(int i) {
    final l = _lines[i];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: UC.border)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(children: [
          Expanded(
            child: DropdownButton<ProductSummary>(
              isExpanded: true,
              underline: const SizedBox(),
              value: l.product,
              items: [for (final p in _products) DropdownMenuItem(value: p, child: Text(p.name.t(_lang), overflow: TextOverflow.ellipsis))],
              onChanged: (p) => setState(() => l.product = p ?? l.product),
            ),
          ),
          IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: () => setState(() => l.qty = l.qty > 1 ? l.qty - 1 : 1)),
          Text('${l.qty}', style: const TextStyle(fontWeight: FontWeight.w800)),
          IconButton(icon: const Icon(Icons.add, size: 18), onPressed: () => setState(() => l.qty++)),
          IconButton(icon: const Icon(Icons.close, size: 18, color: UC.dangerDk), onPressed: () => setState(() => _lines.removeAt(i))),
        ]),
      ),
    );
  }
}

class _Line {
  ProductSummary product;
  int qty;
  _Line(this.product, this.qty);
}
