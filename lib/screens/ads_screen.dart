import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Sponsored listings — vendor pays from wallet to boost a product.
class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key});
  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _campaigns = [];
  double _rate = 1.0;
  double _balance = 0.0;

  bool get _ar => VendorApi.instance.lang == 'ar';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await VendorApi.instance.ads();
      if (!mounted) return;
      setState(() {
        _campaigns = ((d['campaigns'] as List?) ?? const []).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _rate = ((d['daily_rate'] ?? 1.0) as num).toDouble();
        _balance = ((d['wallet_balance'] ?? 0.0) as num).toDouble();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    // pick a product
    List<ProductSummary> prods;
    try {
      prods = await VendorApi.instance.products(state: 'approved');
    } catch (_) {
      prods = await VendorApi.instance.products();
    }
    if (!mounted) return;
    if (prods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_ar ? 'لا توجد منتجات' : 'No products')));
      return;
    }
    ProductSummary? selected = prods.first;
    DateTime start = DateTime.now();
    DateTime end = DateTime.now().add(const Duration(days: 6));
    final lang = _ar ? 'ar' : 'en';

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final days = end.difference(start).inDays + 1;
        final cost = days > 0 ? days * _rate : 0.0;
        String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        return AlertDialog(
          title: Text(_ar ? 'إعلان مموّل' : 'Sponsor a product'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButton<ProductSummary>(
                isExpanded: true,
                value: selected,
                items: [for (final p in prods) DropdownMenuItem(value: p, child: Text(p.name.t(lang), overflow: TextOverflow.ellipsis))],
                onChanged: (p) => setS(() => selected = p),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: start, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setS(() => start = d);
                  },
                  child: Text('${_ar ? 'من' : 'From'}: ${fmt(start)}'),
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: end, firstDate: start, lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setS(() => end = d);
                  },
                  child: Text('${_ar ? 'إلى' : 'To'}: ${fmt(end)}'),
                )),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: UC.yellowFaint, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  _ar
                      ? '$days يوم × ${_rate.toStringAsFixed(3)} = ${cost.toStringAsFixed(3)} د.ك\nالرصيد: ${_balance.toStringAsFixed(3)}'
                      : '$days days × ${_rate.toStringAsFixed(3)} = ${cost.toStringAsFixed(3)} KD\nBalance: ${_balance.toStringAsFixed(3)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: UC.brown),
                ),
              ),
              if (cost > _balance)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(_ar ? 'الرصيد غير كافٍ' : 'Insufficient balance', style: const TextStyle(color: UC.dangerDk, fontSize: 12))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_ar ? 'إلغاء' : 'Cancel')),
            ElevatedButton(
              onPressed: (cost > 0 && cost <= _balance) ? () => Navigator.pop(ctx, true) : null,
              child: Text(_ar ? 'تفعيل ودفع' : 'Activate & pay'),
            ),
          ],
        );
      }),
    );
    if (go != true || selected == null) return;
    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    try {
      await VendorApi.instance.adCreate(selected!.id, fmt(start), fmt(end));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _cancel(int id) async {
    try {
      await VendorApi.instance.adCancel(id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Color _stateColor(String s) => s == 'active' ? UC.success : (s == 'draft' ? UC.warn : UC.muted);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_ar ? 'الإعلانات المموّلة' : 'Sponsored listings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.campaign),
        label: Text(_ar ? 'إعلان جديد' : 'New'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: UC.yellowFaint, borderRadius: BorderRadius.circular(12), border: Border.all(color: UC.border)),
                      child: Text(
                        _ar
                            ? 'ادفع لإبراز منتجاتك. السعر ${_rate.toStringAsFixed(3)} د.ك/يوم · رصيد المحفظة ${_balance.toStringAsFixed(3)}'
                            : 'Pay to boost your products. Rate ${_rate.toStringAsFixed(3)} KD/day · Wallet ${_balance.toStringAsFixed(3)}',
                        style: UT.body,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_campaigns.isEmpty)
                      Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(_ar ? 'لا توجد حملات' : 'No campaigns', style: UT.small))),
                    for (final c in _campaigns)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: UC.border)),
                        child: ListTile(
                          title: Text('${c['product']}', style: const TextStyle(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${c['start']} → ${c['end']} · ${c['days']}${_ar ? ' يوم' : 'd'} · ${(c['total_cost'] as num).toStringAsFixed(3)} ${_ar ? 'د.ك' : 'KD'}', style: UT.small),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _stateColor('${c['state']}').withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                              child: Text('${c['state']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _stateColor('${c['state']}'))),
                            ),
                            if (c['state'] == 'active' || c['state'] == 'draft')
                              IconButton(icon: const Icon(Icons.stop_circle_outlined, size: 20, color: UC.dangerDk), onPressed: () => _cancel(c['id'] as int)),
                          ]),
                        ),
                      ),
                  ]),
                ),
    );
  }
}
