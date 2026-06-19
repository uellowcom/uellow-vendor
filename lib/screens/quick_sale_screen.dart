import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Quick / counter sale — captures the customer address, source warehouse and
/// delivery date, files the order on hold pending Uellow approval, and keeps a
/// history log. Two tabs: New sale + History.
class QuickSaleScreen extends StatefulWidget {
  const QuickSaleScreen({super.key});
  @override
  State<QuickSaleScreen> createState() => _QuickSaleScreenState();
}

class _QuickSaleScreenState extends State<QuickSaleScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final List<_Line> _lines = [];
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _street2 = TextEditingController();
  final _city = TextEditingController();
  final _note = TextEditingController();
  List<ProductSummary> _products = [];
  List<Map<String, dynamic>> _warehouses = [];
  int? _warehouseId;
  DateTime? _deliveryDate;
  bool _loading = true;
  bool _busy = false;
  Future<List<Map<String, dynamic>>>? _history;

  bool get _ar => VendorApi.instance.lang == 'ar';
  String get _lang => _ar ? 'ar' : 'en';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
    _history = VendorApi.instance.quickSaleList();
  }

  Future<void> _load() async {
    try {
      var p = await VendorApi.instance.products(state: 'approved');
      if (p.isEmpty) p = await VendorApi.instance.products();
      List<Map<String, dynamic>> whs = [];
      try { whs = await VendorApi.instance.warehouses(); } catch (_) {}
      if (!mounted) return;
      setState(() {
        _products = p;
        _warehouses = whs;
        _warehouseId = whs.isNotEmpty ? whs.first['id'] as int : null;
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
    _tabs.dispose();
    _name.dispose(); _phone.dispose(); _street.dispose();
    _street2.dispose(); _city.dispose(); _note.dispose();
    super.dispose();
  }

  double get _total => _lines.fold(0.0, (s, l) => s + l.product.listPrice.amount * l.qty);

  Future<void> _addProduct() async {
    final picked = await showModalBottomSheet<ProductSummary>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProductPicker(products: _products, lang: _lang, ar: _ar));
    if (picked != null) {
      final ex = _lines.indexWhere((l) => l.product.id == picked.id);
      setState(() {
        if (ex >= 0) { _lines[ex].qty++; } else { _lines.add(_Line(picked, 1)); }
      });
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 120)));
    if (d != null) setState(() => _deliveryDate = d);
  }

  Future<void> _submit() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_ar ? 'أضف منتجاً واحداً على الأقل' : 'Add at least one product')));
      return;
    }
    if (_phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_ar ? 'هاتف العميل مطلوب' : 'Customer phone is required')));
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await VendorApi.instance.quickSale(
        [for (final l in _lines) {'product_id': l.product.id, 'qty': l.qty}],
        customer: {
          'name': _name.text.trim(),
          'phone': _phone.text.trim(),
          'street': _street.text.trim(),
          'street2': _street2.text.trim(),
          'city': _city.text.trim(),
        },
        warehouseId: _warehouseId,
        deliveryDate: _deliveryDate == null ? null
          : '${_deliveryDate!.toIso8601String().split('T').first} 12:00:00',
        note: _note.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.hourglass_top, color: UC.warn, size: 44),
        content: Text(_ar
            ? 'تم تسجيل البيع ${res['name']} — بانتظار اعتماد يلو قبل التنفيذ.'
            : 'Quick sale ${res['name']} recorded — awaiting Uellow approval before fulfilment.',
            textAlign: TextAlign.center),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
      if (mounted) {
        setState(() {
          _lines.clear(); _name.clear(); _phone.clear(); _street.clear();
          _street2.clear(); _city.clear(); _note.clear(); _deliveryDate = null;
          _history = VendorApi.instance.quickSaleList();
        });
        _tabs.animateTo(1);
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
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(_ar ? 'بيع سريع' : 'Quick sale'),
        bottom: TabBar(controller: _tabs, labelColor: UC.brown,
          indicatorColor: UC.brown, unselectedLabelColor: UC.muted,
          tabs: [
            Tab(text: _ar ? 'بيع جديد' : 'New sale'),
            Tab(text: _ar ? 'السجل' : 'History'),
          ])),
      body: _loading
          ? const Center(child: USpinner())
          : TabBarView(controller: _tabs, children: [_newSale(), _historyTab()]),
    );
  }

  Widget _newSale() {
    return Column(children: [
      Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
        _card(_ar ? 'بيانات العميل' : 'Customer', Icons.person_outline, [
          TextField(controller: _name, decoration: InputDecoration(labelText: _ar ? 'الاسم' : 'Name')),
          const SizedBox(height: 8),
          TextField(controller: _phone, keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: _ar ? 'الهاتف *' : 'Phone *')),
          const SizedBox(height: 8),
          TextField(controller: _city, decoration: InputDecoration(labelText: _ar ? 'المدينة / المحافظة' : 'City / Area')),
          const SizedBox(height: 8),
          TextField(controller: _street, decoration: InputDecoration(labelText: _ar ? 'العنوان (شارع/قطعة)' : 'Street / Block')),
          const SizedBox(height: 8),
          TextField(controller: _street2, decoration: InputDecoration(labelText: _ar ? 'تفاصيل (مبنى/شقة)' : 'Building / Apt')),
        ]),
        _card(_ar ? 'المصدر والتوصيل' : 'Source & delivery', Icons.local_shipping_outlined, [
          _lbl(_ar ? 'المخزن المصدر' : 'Source warehouse'),
          _sourceField(),
          const SizedBox(height: 10),
          _lbl(_ar ? 'موعد التوصيل' : 'Delivery date'),
          InkWell(onTap: _pickDate, borderRadius: BorderRadius.circular(11),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(color: UC.bg, border: Border.all(color: UC.border),
                borderRadius: BorderRadius.circular(11)),
              child: Row(children: [
                const Icon(Icons.event, size: 18, color: UC.brown),
                const SizedBox(width: 10),
                Text(_deliveryDate == null
                  ? (_ar ? 'اختر التاريخ' : 'Pick a date')
                  : _deliveryDate!.toIso8601String().split('T').first,
                  style: TextStyle(fontWeight: FontWeight.w700,
                    color: _deliveryDate == null ? UC.muted : UC.ink)),
              ]))),
        ]),
        _card(_ar ? 'المنتجات' : 'Products', Icons.shopping_cart_outlined, [
          for (int i = 0; i < _lines.length; i++) _lineCard(i),
          if (_lines.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_ar ? 'لم تُضف منتجات بعد' : 'No products yet', style: UT.small)),
          const SizedBox(height: 6),
          OutlinedButton.icon(onPressed: _addProduct,
            icon: const Icon(Icons.add, size: 18),
            label: Text(_ar ? 'إضافة منتج (بحث)' : 'Add product (search)')),
        ]),
        _card(_ar ? 'ملاحظة' : 'Note', Icons.notes_outlined, [
          TextField(controller: _note, minLines: 2, maxLines: 4,
            decoration: InputDecoration(hintText: _ar ? 'ملاحظة للطلب (اختياري)' : 'Order note (optional)')),
        ]),
        Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: UC.warnBg, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 16, color: UC.warn),
            const SizedBox(width: 8),
            Expanded(child: Text(_ar
              ? 'يُسجَّل البيع بحالة «بانتظار الاعتماد» ولا يُنفَّذ إلا بعد موافقة يلو.'
              : 'The sale is filed as “pending approval” and only proceeds after Uellow approves.',
              style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600))),
          ])),
        const SizedBox(height: 90),
      ])),
      SafeArea(top: false, child: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(color: Colors.white,
          border: Border(top: BorderSide(color: UC.border))),
        child: Row(children: [
          Expanded(child: Text('${_ar ? 'الإجمالي' : 'Total'}: ${_total.toStringAsFixed(3)} ${_ar ? 'د.ك' : 'KD'}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
          ElevatedButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
              : const Icon(Icons.send, size: 18),
            label: Text(_ar ? 'إرسال للاعتماد' : 'Submit')),
        ]))),
    ]);
  }

  Widget _historyTab() {
    return RefreshIndicator(
      onRefresh: () async => setState(() => _history = VendorApi.instance.quickSaleList()),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _history,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return ListView(children: [Padding(padding: const EdgeInsets.all(40),
              child: Column(children: [
                const Icon(Icons.history, size: 44, color: UC.muted),
                const SizedBox(height: 10),
                Text(_ar ? 'لا توجد مبيعات سريعة بعد' : 'No quick sales yet',
                  textAlign: TextAlign.center, style: UT.body),
              ]))]);
          }
          return ListView.builder(padding: const EdgeInsets.all(12), itemCount: items.length,
            itemBuilder: (c, i) {
              final o = items[i];
              final approved = o['approved'] == true;
              final cancelled = (o['state'] ?? '') == 'cancel';
              final color = cancelled ? UC.dangerDk : (approved ? UC.successDk : UC.warn);
              final label = cancelled ? (_ar ? 'ملغي' : 'Cancelled')
                : (approved ? (_ar ? 'معتمد' : 'Approved') : (_ar ? 'بانتظار الاعتماد' : 'Pending'));
              return Container(margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(12), border: Border.all(color: UC.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('${o['name']}', style: const TextStyle(fontFamily: 'monospace',
                      fontWeight: FontWeight.w900, fontSize: 12)),
                    const Spacer(),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: color.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(999)),
                      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900))),
                  ]),
                  const SizedBox(height: 6),
                  Text('${o['customer'] ?? ''}${(o['city'] ?? '').toString().isNotEmpty ? ' · ${o['city']}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text('${(o['amount'] as Map?)?['amount'] ?? ''} ${(o['amount'] as Map?)?['symbol'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: UC.brown)),
                    const Spacer(),
                    if ((o['delivery_date'] ?? '').toString().isNotEmpty)
                      Text('${_ar ? 'التوصيل' : 'Delivery'}: ${o['delivery_date'].toString().split('T').first}',
                        style: UT.small),
                  ]),
                ]));
            });
        }));
  }

  Widget _lineCard(int i) {
    final l = _lines[i];
    return Container(margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: UC.bg, borderRadius: BorderRadius.circular(11)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.product.name.t(_lang), maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          Text(l.product.listPrice.format(_lang), style: UT.small),
        ])),
        IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20),
          onPressed: () => setState(() => l.qty = l.qty > 1 ? l.qty - 1 : 1)),
        Text('${l.qty}', style: const TextStyle(fontWeight: FontWeight.w900)),
        IconButton(icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: () => setState(() => l.qty++)),
        IconButton(icon: const Icon(Icons.close, size: 18, color: UC.dangerDk),
          onPressed: () => setState(() => _lines.removeAt(i))),
      ]));
  }

  Widget _card(String title, IconData ic, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: UC.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(ic, size: 17, color: UC.brown), const SizedBox(width: 7), Text(title, style: UT.h3)]),
      const SizedBox(height: 12), ...children,
    ]));

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 6),
    child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 10.5,
      fontWeight: FontWeight.w800, color: UC.muted, letterSpacing: .4)));

  // Single own source → clean read-only card. >1 → styled dropdown fallback.
  Widget _sourceField() {
    if (_warehouses.length > 1) {
      return DropdownButtonFormField<int>(
        value: _warehouseId, isExpanded: true,
        hint: Text(_ar ? 'اختر المخزن' : 'Select warehouse'),
        items: [for (final w in _warehouses) DropdownMenuItem<int>(
          value: w['id'] as int, child: Text('${w['name']}', overflow: TextOverflow.ellipsis))],
        onChanged: (v) => setState(() => _warehouseId = v));
    }
    if (_warehouses.isEmpty) {
      return Text(_ar ? 'لا يوجد مخزن متاح' : 'No source warehouse available', style: UT.small);
    }
    final w = _warehouses.first;
    final name = '${w['name'] ?? ''}';
    final location = '${w['location'] ?? ''}';
    final noteMap = w['note'];
    final note = noteMap is Map ? '${noteMap[_lang] ?? noteMap['en'] ?? ''}' : '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UC.yellowFaint, borderRadius: BorderRadius.circular(11),
        border: Border.all(color: UC.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: UC.yellow, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.warehouse_outlined, size: 22, color: UC.brown)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? (_ar ? 'مخزنك' : 'Your warehouse') : name,
              style: UT.h3, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.place_outlined, size: 13, color: UC.muted),
                const SizedBox(width: 4),
                Expanded(child: Text(location, style: UT.small,
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
            ],
            if (note.isNotEmpty) ...[
              const SizedBox(height: 7),
              UPill(text: note, bg: UC.yellow, fg: UC.brown, icon: Icons.check_circle_outline),
            ],
          ])),
      ]));
  }
}

class _Line {
  ProductSummary product;
  int qty;
  _Line(this.product, this.qty);
}

// ─────────────── Searchable product picker ───────────────
class _ProductPicker extends StatefulWidget {
  final List<ProductSummary> products;
  final String lang;
  final bool ar;
  const _ProductPicker({required this.products, required this.lang, required this.ar});
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = widget.products.where((p) => q.isEmpty
      || p.name.en.toLowerCase().contains(q) || p.name.ar.toLowerCase().contains(q)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(height: MediaQuery.of(context).size.height * .75,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: UC.border, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.all(14),
            child: TextField(autofocus: true,
              decoration: InputDecoration(hintText: widget.ar ? 'ابحث عن منتج' : 'Search products',
                prefixIcon: const Icon(Icons.search)),
              onChanged: (s) => setState(() => _q = s))),
          Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) {
            final p = list[i];
            return ListTile(
              title: Text(p.name.t(widget.lang), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(p.listPrice.format(widget.lang), style: UT.small),
              trailing: const Icon(Icons.add_circle, color: UC.brown),
              onTap: () => Navigator.pop(context, p));
          })),
        ])));
  }
}
