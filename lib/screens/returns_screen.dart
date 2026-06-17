import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Stock returns — vendor requests to withdraw goods stored at Uellow
/// (FBU / Consignment). Admin approves + prints the signed note + settles.
class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});
  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  late Future<List<Map<String, dynamic>>> _f;
  @override
  void initState() { super.initState(); _f = VendorApi.instance.returnList(); }
  void _reload() => setState(() => _f = VendorApi.instance.returnList());

  Color _stateColor(String s) {
    switch (s) {
      case 'settled': return UC.successBg;
      case 'rejected': return UC.dangerBg;
      default: return UC.warnBg;
    }
  }
  String _stateLabel(String s, bool ar) => {
    'submitted': ar ? 'مُقدّم' : 'Submitted',
    'approved': ar ? 'معتمد' : 'Approved',
    'delivered': ar ? 'سُلّم' : 'Delivered',
    'settled': ar ? 'تمّت التسوية' : 'Settled',
    'rejected': ar ? 'مرفوض' : 'Rejected',
  }[s] ?? s;

  Future<void> _create() async {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    List<ProductSummary> prods;
    try { prods = await VendorApi.instance.products(state: 'live'); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); return; }
    if (!mounted) return;
    if (prods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'لا منتجات' : 'No products'))); return;
    }
    final qtys = <int, int>{};
    String pickup = 'self';
    final reason = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (c) => StatefulBuilder(builder: (c, setM) => Padding(
        padding: EdgeInsets.only(left: 14, right: 14, top: 14,
          bottom: MediaQuery.of(c).viewInsets.bottom + 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ar ? 'طلب استرجاع بضاعة' : 'Request stock return', style: UT.h2),
          const SizedBox(height: 8),
          Text(ar ? 'طريقة الاستلام' : 'Handover', style: UT.small),
          Row(children: [
            ChoiceChip(label: Text(ar ? 'أستلمها بنفسي' : 'I pick up'), selected: pickup == 'self',
              selectedColor: UC.yellowFaint, onSelected: (_) => setM(() => pickup = 'self')),
            const SizedBox(width: 6),
            ChoiceChip(label: Text(ar ? 'مندوب يلو' : 'Uellow courier'), selected: pickup == 'uellow',
              selectedColor: UC.yellowFaint, onSelected: (_) => setM(() => pickup = 'uellow')),
          ]),
          const SizedBox(height: 8),
          Text(ar ? 'المنتجات والكميات' : 'Products & quantities', style: UT.small),
          Flexible(child: ListView(shrinkWrap: true, children: [
            for (final p in prods) Row(children: [
              Expanded(child: Text(p.name.t(lang), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              SizedBox(width: 70, child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: ar ? 'كمية' : 'qty', isDense: true),
                onChanged: (v) => qtys[p.id] = int.tryParse(v) ?? 0)),
            ]),
          ])),
          const SizedBox(height: 8),
          TextField(controller: reason, decoration: InputDecoration(
            labelText: ar ? 'السبب (اختياري)' : 'Reason (optional)', border: const OutlineInputBorder())),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: UC.brown, foregroundColor: UC.yellow),
            onPressed: () => Navigator.pop(c, true),
            child: Text(ar ? 'إرسال الطلب' : 'Submit request'))),
          const SizedBox(height: 4),
        ]))),
    );
    if (ok != true) return;
    final items = qtys.entries.where((e) => e.value > 0)
      .map((e) => {'product_id': e.key, 'qty': e.value}).toList();
    if (items.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'أدخل كمية لمنتج واحد على الأقل' : 'Enter a quantity for at least one product')));
      return;
    }
    try {
      await VendorApi.instance.returnCreate(pickup, reason.text.trim(), items);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم إرسال طلب الاسترجاع' : 'Return request sent')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'استرجاع البضاعة' : 'Stock returns')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: UC.brown, foregroundColor: UC.yellow,
        onPressed: _create, icon: const Icon(Icons.assignment_return),
        label: Text(ar ? 'طلب استرجاع' : 'New return')),
      body: FutureBuilder<List<Map<String, dynamic>>>(future: _f, builder: (_, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return Center(child: Text('${s.error}'));
        final rows = s.data ?? [];
        if (rows.isEmpty) {
          return Center(child: Text(ar ? 'لا طلبات استرجاع بعد' : 'No return requests yet', style: UT.body));
        }
        return RefreshIndicator(onRefresh: () async => _reload(),
          child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
            for (final r in rows) Container(
              margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: UC.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${r['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
                  UPill(text: _stateLabel('${r['state']}', ar),
                    bg: _stateColor('${r['state']}'), fg: UC.brown),
                ]),
                const SizedBox(height: 4),
                Text('${r['total_qty']} ${ar ? "قطعة" : "items"} · '
                     '${(r['pickup_mode'] == 'uellow') ? (ar ? "مندوب يلو" : "Uellow courier") : (ar ? "استلام ذاتي" : "Self pickup")}',
                  style: UT.small),
              ])),
          ]));
      }),
    );
  }
}
