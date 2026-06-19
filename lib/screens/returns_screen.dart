import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Stock returns — two directions:
///  • Vendor withdrawal: pull goods stored at Uellow back (FBU/Consignment).
///  • Uellow return: Uellow sends goods back to the vendor (with a reason).
/// Both appear here; the vendor creates withdrawals + tracks Uellow returns.
class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});
  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  late Future<Map<String, dynamic>> _f;
  @override
  void initState() { super.initState(); _f = VendorApi.instance.returnList(); }
  void _reload() => setState(() => _f = VendorApi.instance.returnList());

  bool get _ar => VendorApi.instance.lang == 'ar';

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
  String _bl(dynamic v) => v is Map ? (_ar ? (v['ar'] ?? v['en']) : (v['en'] ?? v['ar']) ?? '').toString() : '${v ?? ''}';

  Future<void> _create(List<Map<String, dynamic>> reasons) async {
    final ar = _ar;
    final lang = ar ? 'ar' : 'en';
    List<ProductSummary> prods;
    try { prods = await VendorApi.instance.products(state: 'live'); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); return; }
    if (!mounted) return;
    if (prods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'لا منتجات' : 'No products'))); return;
    }
    final qtys = <int, int>{};
    String pickup = 'self';
    String reasonCode = reasons.isNotEmpty ? (reasons.first['code'] as String) : 'other';
    final reason = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (c) => StatefulBuilder(builder: (c, setM) => Padding(
        padding: EdgeInsets.only(left: 14, right: 14, top: 14,
          bottom: MediaQuery.of(c).viewInsets.bottom + 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ar ? 'طلب سحب بضاعة من يلو' : 'Withdraw stock from Uellow', style: UT.h2),
          const SizedBox(height: 10),
          Text(ar ? 'سبب الإرجاع' : 'Return reason', style: UT.small),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: reasonCode, isExpanded: true,
            items: [for (final r in reasons) DropdownMenuItem(value: r['code'] as String,
              child: Text(ar ? (r['ar'] ?? r['en']) : r['en']))],
            onChanged: (v) => setM(() => reasonCode = v ?? 'other')),
          const SizedBox(height: 10),
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
            labelText: ar ? 'تفاصيل إضافية (اختياري)' : 'Extra details (optional)', border: const OutlineInputBorder())),
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
      await VendorApi.instance.returnCreate(pickup, reasonCode, reason.text.trim(), items);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'تم إرسال طلب السحب' : 'Withdrawal request sent')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(ar ? 'الإرجاع والسحب' : 'Returns & withdrawals')),
      body: FutureBuilder<Map<String, dynamic>>(future: _f, builder: (_, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: USpinner());
        if (s.hasError) return Center(child: Text('${s.error}'));
        final data = s.data ?? const {};
        final rows = ((data['returns'] as List?) ?? const []).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        final reasons = ((data['reasons'] as List?) ?? const []).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        return Scaffold(
          backgroundColor: UC.bg,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: UC.brown, foregroundColor: UC.yellow,
            onPressed: () => _create(reasons), icon: const Icon(Icons.assignment_return),
            label: Text(ar ? 'سحب بضاعة' : 'Withdraw stock')),
          body: RefreshIndicator(onRefresh: () async => _reload(),
            child: rows.isEmpty
              ? ListView(children: [Padding(padding: const EdgeInsets.all(40),
                  child: Column(children: [
                    const Icon(Icons.assignment_return_outlined, size: 44, color: UC.muted),
                    const SizedBox(height: 10),
                    Text(ar ? 'لا طلبات إرجاع/سحب بعد' : 'No returns / withdrawals yet',
                      textAlign: TextAlign.center, style: UT.body),
                  ]))])
              : ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
                  for (final r in rows) _card(r, ar),
                ])),
        );
      }),
    );
  }

  Widget _card(Map<String, dynamic> r, bool ar) {
    final uellowInit = r['initiator'] == 'uellow';
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: uellowInit ? UC.warn : UC.border, width: uellowInit ? 1.4 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(uellowInit ? Icons.south_west : Icons.north_east, size: 16,
            color: uellowInit ? UC.warn : UC.brown),
          const SizedBox(width: 6),
          Expanded(child: Text('${r['name']}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
          UPill(text: _stateLabel('${r['state']}', ar),
            bg: _stateColor('${r['state']}'), fg: UC.brown),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          UPill(text: _bl(r['initiator_label']),
            bg: uellowInit ? UC.warnBg : UC.yellowFaint, fg: UC.brown),
          const SizedBox(width: 6),
          if (_bl(r['reason_label']).isNotEmpty)
            Flexible(child: UPill(text: _bl(r['reason_label']), bg: UC.bg, fg: UC.muted)),
        ]),
        const SizedBox(height: 6),
        Text('${r['total_qty']} ${ar ? "قطعة" : "items"} · '
             '${(r['pickup_mode'] == 'uellow') ? (ar ? "مندوب يلو" : "Uellow courier") : (ar ? "استلام ذاتي" : "Self pickup")}',
          style: UT.small),
        if ('${r['reason'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4),
          child: Text('${r['reason']}', style: UT.tiny, maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
