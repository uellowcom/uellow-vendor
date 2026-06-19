import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Sponsored ads — product boost / banner / in-feed, paid from the wallet and
/// rendered in the main customer app (banner/in-feed via mobile.app.ad).
class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key});
  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _campaigns = [];
  double _wallet = 0;

  bool get _ar => VendorApi.instance.lang == 'ar';
  String _bl(dynamic v) => v is Map ? (_ar ? (v['ar'] ?? v['en']) : (v['en'] ?? v['ar']) ?? '').toString() : '${v ?? ''}';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await VendorApi.instance.ads();
      if (!mounted) return;
      setState(() {
        _campaigns = ((d['campaigns'] as List?) ?? const []).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _wallet = ((d['wallet_balance'] ?? 0) as num).toDouble();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _create() async {
    final created = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => const AdCreateScreen()));
    if (created == true) _load();
  }

  Future<void> _cancel(int id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      content: Text(_ar ? 'إيقاف هذا الإعلان؟' : 'Stop this campaign?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_ar ? 'لا' : 'No')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_ar ? 'نعم' : 'Yes')),
      ]));
    if (ok != true) return;
    try { await VendorApi.instance.adCancel(id); _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Color _stateColor(String s) => {
    'active': UC.successDk, 'ended': UC.muted, 'cancelled': UC.dangerDk}[s] ?? UC.warn;
  IconData _fmtIcon(String f) => {
    'product_boost': Icons.trending_up, 'banner': Icons.view_carousel,
    'infeed': Icons.dashboard_customize}[f] ?? Icons.campaign;

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(ar ? 'الإعلانات الممولة' : 'Sponsored ads')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: UC.brown, foregroundColor: UC.yellow,
        onPressed: _create, icon: const Icon(Icons.campaign),
        label: Text(ar ? 'إعلان جديد' : 'New ad')),
      body: _loading ? const Center(child: USpinner())
        : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
        : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
            Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [UC.yellow, UC.yellowSoft],
                begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.account_balance_wallet, color: UC.brown),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ar ? 'رصيد المحفظة' : 'Wallet balance',
                    style: const TextStyle(color: UC.brownSoft, fontSize: 11, fontWeight: FontWeight.w800)),
                  Text('${_wallet.toStringAsFixed(3)} ${ar ? "د.ك" : "KD"}',
                    style: const TextStyle(color: UC.brown, fontSize: 18, fontWeight: FontWeight.w900)),
                ])),
                Text(ar ? 'يُخصم منها' : 'Ads charge here', style: const TextStyle(color: UC.brownSoft, fontSize: 10)),
              ])),
            const SizedBox(height: 12),
            if (_campaigns.isEmpty) Padding(padding: const EdgeInsets.all(28),
              child: Column(children: [
                const Icon(Icons.campaign_outlined, size: 44, color: UC.muted),
                const SizedBox(height: 10),
                Text(ar ? 'لا إعلانات بعد' : 'No campaigns yet', style: UT.body),
              ])),
            for (final c in _campaigns) _campaignCard(c, ar),
          ])),
    );
  }

  Widget _campaignCard(Map<String, dynamic> c, bool ar) {
    final st = '${c['state']}';
    return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: UC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_fmtIcon('${c['ad_format']}'), size: 18, color: UC.brown),
          const SizedBox(width: 6),
          Expanded(child: Text('${c['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
          UPill(text: st, bg: _stateColor(st).withValues(alpha: .14), fg: _stateColor(st)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          UPill(text: _bl(c['ad_format_label']), bg: UC.yellowFaint, fg: UC.brown),
          UPill(text: _bl(c['placement_label']), bg: UC.bg, fg: UC.muted),
          if ('${c['product'] ?? ''}'.isNotEmpty) UPill(text: '${c['product']}', bg: UC.bg, fg: UC.muted),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('${c['days']} ${ar ? "يوم" : "days"} · ${c['daily_rate']} ${ar ? "د.ك/يوم" : "KD/day"}', style: UT.small)),
          Text('${c['total_cost']} ${ar ? "د.ك" : "KD"}', style: const TextStyle(fontWeight: FontWeight.w900, color: UC.brown)),
        ]),
        if ((c['impressions'] ?? 0) != 0 || (c['clicks'] ?? 0) != 0)
          Padding(padding: const EdgeInsets.only(top: 4),
            child: Text('${c['impressions']} ${ar ? "ظهور" : "impr."} · ${c['clicks']} ${ar ? "نقرة" : "clicks"}', style: UT.tiny)),
        if (st == 'active') Align(alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(onPressed: () => _cancel(c['id'] as int),
            icon: const Icon(Icons.stop_circle_outlined, size: 18, color: UC.dangerDk),
            label: Text(ar ? 'إيقاف' : 'Stop', style: const TextStyle(color: UC.dangerDk)))),
      ]));
  }
}

// ─────────────── Ad create (full page) ───────────────
class AdCreateScreen extends StatefulWidget {
  const AdCreateScreen({super.key});
  @override
  State<AdCreateScreen> createState() => _AdCreateScreenState();
}

class _AdCreateScreenState extends State<AdCreateScreen> {
  String _format = 'product_boost';
  String _placement = 'home';
  ProductSummary? _product;
  final _headline = TextEditingController();
  String? _bannerB64;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 7));
  Map<String, dynamic> _rates = {};
  List<Map<String, dynamic>> _formats = [];
  List<Map<String, dynamic>> _placements = [];
  List<ProductSummary> _products = [];
  bool _loading = true, _busy = false;

  bool get _ar => VendorApi.instance.lang == 'ar';
  String get _lang => _ar ? 'ar' : 'en';
  String _bl(dynamic v) => v is Map ? (_ar ? (v['ar'] ?? v['en']) : (v['en'] ?? v['ar']) ?? '').toString() : '${v ?? ''}';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final q = await VendorApi.instance.adQuote();
      var p = await VendorApi.instance.products(state: 'approved');
      if (p.isEmpty) p = await VendorApi.instance.products();
      if (!mounted) return;
      setState(() {
        _rates = (q['rates'] as Map?)?.cast<String, dynamic>() ?? {};
        _formats = ((q['formats'] as List?) ?? const []).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _placements = ((q['placements'] as List?) ?? const []).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
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
  void dispose() { _headline.dispose(); super.dispose(); }

  int get _days => _end.difference(_start).inDays + 1;
  double get _rate => ((_rates[_format] ?? 1) as num).toDouble();
  double get _cost => _days * _rate;

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<ProductSummary>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AdProductPicker(products: _products, lang: _lang, ar: _ar));
    if (picked != null) setState(() => _product = picked);
  }

  Future<void> _pickBanner() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (f == null) return;
    final b = await File(f.path).readAsBytes();
    setState(() => _bannerB64 = base64Encode(b));
  }

  Future<void> _pickDate(bool start) async {
    final d = await showDatePicker(context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180)));
    if (d != null) setState(() { if (start) { _start = d; if (_end.isBefore(d)) _end = d; } else { _end = d; } });
  }

  Future<void> _submit() async {
    final ar = _ar;
    if (_format == 'product_boost' && _product == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'اختر منتجاً للإبراز' : 'Pick a product to boost'))); return;
    }
    if (_format != 'product_boost' && _bannerB64 == null && _product == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'أضف صورة بانر أو اختر منتجاً' : 'Add a banner image or pick a product'))); return;
    }
    setState(() => _busy = true);
    String f(DateTime d) => d.toIso8601String().split('T').first;
    try {
      await VendorApi.instance.adCreate(adFormat: _format, placement: _placement,
        start: f(_start), end: f(_end), productId: _product?.id,
        headline: _headline.text.trim(), bannerBase64: _bannerB64);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'تم تفعيل الإعلان' : 'Campaign activated')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    final needsBanner = _format != 'product_boost';
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(ar ? 'إعلان جديد' : 'New ad')),
      body: _loading ? const Center(child: USpinner()) : ListView(padding: const EdgeInsets.all(14), children: [
        _card(ar ? 'الشكل' : 'Format', Icons.style, [
          for (final fmt in _formats)
            RadioListTile<String>(contentPadding: EdgeInsets.zero, activeColor: UC.brown,
              value: fmt['code'] as String, groupValue: _format,
              onChanged: (v) => setState(() => _format = v ?? 'product_boost'),
              title: Text(_bl(fmt), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              secondary: Text('${((_rates[fmt['code']] ?? 1) as num)} ${ar ? "د.ك/يوم" : "KD/day"}',
                style: const TextStyle(color: UC.brown, fontWeight: FontWeight.w900, fontSize: 12))),
        ]),
        _card(ar ? 'المكان' : 'Placement', Icons.place_outlined, [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final pl in _placements)
              ChoiceChip(label: Text(_bl(pl)), selected: _placement == pl['code'],
                selectedColor: UC.yellowFaint,
                onSelected: (_) => setState(() => _placement = pl['code'] as String)),
          ]),
        ]),
        _card(ar ? 'المحتوى' : 'Creative', Icons.image_outlined, [
          InkWell(onTap: _pickProduct, borderRadius: BorderRadius.circular(11),
            child: Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: UC.bg, border: Border.all(color: UC.border), borderRadius: BorderRadius.circular(11)),
              child: Row(children: [
                const Icon(Icons.shopping_bag_outlined, color: UC.brown, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_product == null
                  ? (needsBanner ? (ar ? 'اربط منتجاً (اختياري)' : 'Link a product (optional)') : (ar ? 'اختر المنتج' : 'Select product'))
                  : _product!.name.t(_lang), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, color: _product == null ? UC.muted : UC.ink))),
                const Icon(Icons.search, color: UC.muted, size: 18),
              ]))),
          if (needsBanner) ...[
            const SizedBox(height: 10),
            TextField(controller: _headline, decoration: InputDecoration(labelText: ar ? 'عنوان الإعلان' : 'Headline')),
            const SizedBox(height: 10),
            _bannerB64 == null
              ? OutlinedButton.icon(onPressed: _pickBanner, icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text(ar ? 'صورة البانر' : 'Banner image'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 46)))
              : Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(11),
                    child: Image.memory(base64Decode(_bannerB64!), height: 120, width: double.infinity, fit: BoxFit.cover)),
                  Positioned(right: 6, top: 6, child: Material(color: Colors.black54, shape: const CircleBorder(),
                    child: InkWell(onTap: () => setState(() => _bannerB64 = null),
                      child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.close, color: Colors.white, size: 16))))),
                ]),
          ],
        ]),
        _card(ar ? 'المدة' : 'Schedule', Icons.event, [
          Row(children: [
            Expanded(child: _dateBtn(ar ? 'من' : 'From', _start, () => _pickDate(true))),
            const SizedBox(width: 10),
            Expanded(child: _dateBtn(ar ? 'إلى' : 'To', _end, () => _pickDate(false))),
          ]),
        ]),
        Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: UC.brown, borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ar ? 'التكلفة الإجمالية' : 'TOTAL COST',
              style: const TextStyle(color: Color(0xFFFFE066), fontSize: 10, fontWeight: FontWeight.w800)),
            Text('${_cost.toStringAsFixed(3)} ${ar ? "د.ك" : "KD"}',
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            Text('$_days ${ar ? "يوم" : "days"} × ${_rate.toStringAsFixed(3)} ${ar ? "د.ك" : "KD"}',
              style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11)),
          ])),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
            : const Icon(Icons.bolt, size: 18),
          label: Text(ar ? 'تفعيل ودفع' : 'Activate & pay',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)))),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _dateBtn(String label, DateTime d, VoidCallback onTap) => InkWell(onTap: onTap,
    borderRadius: BorderRadius.circular(11),
    child: Container(padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: UC.bg, border: Border.all(color: UC.border), borderRadius: BorderRadius.circular(11)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: UT.tiny),
        const SizedBox(height: 2),
        Text(d.toIso8601String().split('T').first, style: const TextStyle(fontWeight: FontWeight.w800)),
      ])));

  Widget _card(String title, IconData ic, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: UC.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(ic, size: 17, color: UC.brown), const SizedBox(width: 7), Text(title, style: UT.h3)]),
      const SizedBox(height: 8), ...children,
    ]));
}

class _AdProductPicker extends StatefulWidget {
  final List<ProductSummary> products;
  final String lang;
  final bool ar;
  const _AdProductPicker({required this.products, required this.lang, required this.ar});
  @override
  State<_AdProductPicker> createState() => _AdProductPickerState();
}

class _AdProductPickerState extends State<_AdProductPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = widget.products.where((p) => q.isEmpty
      || p.name.en.toLowerCase().contains(q) || p.name.ar.toLowerCase().contains(q)).toList();
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(height: MediaQuery.of(context).size.height * .75, child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: UC.border, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.all(14),
          child: TextField(autofocus: true,
            decoration: InputDecoration(hintText: widget.ar ? 'ابحث عن منتج' : 'Search products', prefixIcon: const Icon(Icons.search)),
            onChanged: (s) => setState(() => _q = s))),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) {
          final p = list[i];
          return ListTile(
            leading: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: p.imageUrl != null
                ? Image.network('${VendorApi.instance.baseUrl}${p.imageUrl}', width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_,__,___) => Container(width: 44, height: 44, color: UC.border, child: const Icon(Icons.image, color: UC.muted)))
                : Container(width: 44, height: 44, color: UC.border, child: const Icon(Icons.image, color: UC.muted))),
            title: Text(p.name.t(widget.lang), maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.pop(context, p));
        })),
      ])));
  }
}
