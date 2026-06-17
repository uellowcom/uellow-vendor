import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

bool get _ar => VendorApi.instance.lang == 'ar';

String _bil(dynamic v) {
  if (v is Map) return (_ar ? (v['ar'] ?? v['en']) : (v['en'] ?? v['ar']) ?? '').toString();
  return (v ?? '').toString();
}

Color _stateColor(String s) => {
      'sent': UC.warn,
      'received': UC.success,
      'applied': UC.muted,
    }[s] ?? UC.muted;

String _stateLabel(String s) {
  switch (s) {
    case 'sent':
      return _ar ? 'بانتظار ردّك' : 'Awaiting reply';
    case 'received':
      return _ar ? 'تم الإرسال' : 'Submitted';
    case 'applied':
      return _ar ? 'مُطبّق' : 'Applied';
  }
  return s;
}

// ─────────────────────────── LIST ───────────────────────────
class PriceRequestsScreen extends StatefulWidget {
  const PriceRequestsScreen({super.key});
  @override
  State<PriceRequestsScreen> createState() => _PriceRequestsScreenState();
}

class _PriceRequestsScreenState extends State<PriceRequestsScreen> {
  late Future<List<Map<String, dynamic>>> _f;
  @override
  void initState() {
    super.initState();
    _f = VendorApi.instance.priceRequests();
  }

  void _reload() => setState(() => _f = VendorApi.instance.priceRequests());

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(
        backgroundColor: UC.yellow,
        foregroundColor: UC.brown,
        title: Text(ar ? 'طلبات الأسعار' : 'Price Requests',
            style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: UC.brown));
            }
            if (s.hasError) {
              return _Msg(icon: Icons.error_outline, text: s.error.toString());
            }
            final items = s.data ?? const [];
            if (items.isEmpty) {
              return _Msg(
                  icon: Icons.sell_outlined,
                  text: ar ? 'لا توجد طلبات حالياً.' : 'No requests right now.');
            }
            return ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: items.length,
              itemBuilder: (c, i) {
                final r = items[i];
                final st = (r['state'] ?? '').toString();
                final pending = (r['pending'] ?? 0).toString();
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: UC.border)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text((r['name'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w900, color: UC.ink)),
                    subtitle: Text(
                        '${r['product_count'] ?? 0} ${ar ? 'منتج' : 'products'} · ${r['date'] ?? ''}',
                        style: const TextStyle(color: UC.muted, fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: _stateColor(st).withOpacity(.15),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(_stateLabel(st),
                          style: TextStyle(
                              color: _stateColor(st),
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                    onTap: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PriceRequestDetailScreen(
                                  id: r['id'] as int? ?? 0)));
                      _reload();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────── DETAIL ───────────────────────────
class PriceRequestDetailScreen extends StatefulWidget {
  final int id;
  const PriceRequestDetailScreen({super.key, required this.id});
  @override
  State<PriceRequestDetailScreen> createState() => _PriceRequestDetailScreenState();
}

class _PriceRequestDetailScreenState extends State<PriceRequestDetailScreen> {
  Map<String, dynamic>? _req;
  bool _loading = true, _busy = false;
  String? _err;
  // per line: keep flag + new price controller
  final Map<int, bool> _keep = {};
  final Map<int, TextEditingController> _ctl = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctl.values) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await VendorApi.instance.priceRequest(widget.id);
      for (final ln in (r['lines'] as List? ?? const [])) {
        final id = ln['line_id'] as int? ?? 0;
        _ctl.putIfAbsent(id, () => TextEditingController());
        if (ln['response'] == 'match') _keep[id] = true;
        if (ln['response'] == 'changed' && ln['new_price'] != null) {
          _ctl[id]!.text = (ln['new_price']).toString();
        }
      }
      setState(() {
        _req = r;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final lines = (_req!['lines'] as List? ?? const []);
    final responses = <Map<String, dynamic>>[];
    for (final ln in lines) {
      final id = ln['line_id'] as int? ?? 0;
      final txt = _ctl[id]?.text.trim() ?? '';
      if (_keep[id] == true) {
        responses.add({'line_id': id, 'action': 'match'});
      } else if (txt.isNotEmpty) {
        final v = double.tryParse(txt);
        if (v != null) responses.add({'line_id': id, 'action': 'price', 'price': v});
      }
    }
    if (responses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_ar
              ? 'طابِق أو اكتب سعراً لمنتج واحد على الأقل.'
              : 'Match or set a price for at least one product.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await VendorApi.instance.respondPriceRequest(widget.id, responses);
      if (!mounted) return;
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                icon: const Icon(Icons.check_circle, color: UC.success, size: 48),
                content: Text(
                    _ar
                        ? 'تم استلام ردّك. السطور المطابقة اعتُمدت تلقائياً، والمتغيّرة بانتظار موافقة الإدارة.'
                        : 'Your response was received. Matched lines auto-confirm; changed ones await admin approval.',
                    textAlign: TextAlign.center),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      child: Text(_ar ? 'تم' : 'Done'))
                ],
              ));
    } on VendorApiException catch (e) {
      setState(() {
        _busy = false;
        _err = e.message;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _err = e.toString();
      });
    }
  }

  void _matchAll() {
    setState(() {
      for (final ln in (_req!['lines'] as List? ?? const [])) {
        _keep[ln['line_id'] as int? ?? 0] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(
        backgroundColor: UC.yellow,
        foregroundColor: UC.brown,
        title: Text(_req?['name']?.toString() ?? (ar ? 'الطلب' : 'Request'),
            style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: UC.brown))
          : _req == null
              ? _Msg(icon: Icons.error_outline, text: _err ?? 'Error')
              : _buildBody(ar),
      bottomNavigationBar: (_req != null && _req!['editable'] == true)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: _busy ? null : _submit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: UC.brown,
                      foregroundColor: UC.yellowSoft,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: UC.yellowSoft))
                      : Text(ar ? 'إرسال الردّ' : 'Submit response',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w900)),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(bool ar) {
    final editable = _req!['editable'] == true;
    final lines = (_req!['lines'] as List? ?? const []);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if ((_req!['note'] ?? '').toString().isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: UC.yellowFaint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: UC.yellow)),
            child: Text(_req!['note'].toString(),
                style: const TextStyle(color: UC.brown, fontSize: 13)),
          ),
        if (editable)
          Align(
            alignment: ar ? Alignment.centerRight : Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _matchAll,
              icon: const Icon(Icons.done_all, size: 18, color: UC.brown),
              label: Text(ar ? 'طابِق كل الأسعار' : 'Match all prices',
                  style: const TextStyle(
                      color: UC.brown, fontWeight: FontWeight.w900)),
            ),
          ),
        ...lines.map((ln) => _lineCard(ln as Map, ar, editable)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _lineCard(Map ln, bool ar, bool editable) {
    final id = ln['line_id'] as int? ?? 0;
    final cur = ln['current_price'];
    final st = (ln['line_state'] ?? 'pending').toString();
    final keep = _keep[id] == true;
    final stColors = {
      'pending': UC.muted,
      'confirmed': UC.success,
      'await': UC.warn,
      'approved': UC.success,
      'rejected': UC.danger,
    };
    final stLabels = {
      'pending': ar ? 'بانتظار' : 'Pending',
      'confirmed': ar ? 'مؤكّد' : 'Confirmed',
      'await': ar ? 'بانتظار الموافقة' : 'Awaiting approval',
      'approved': ar ? 'معتمد' : 'Approved',
      'rejected': ar ? 'مرفوض' : 'Rejected',
    };
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: UC.border)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (ln['image_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                    '${VendorApi.instance.baseUrl}${ln['image_url']}',
                    width: 46, height: 46, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image_outlined, color: UC.muted)),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_bil(ln['name']),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: UC.ink)),
                Text('${ar ? 'الحالي' : 'Current'}: ${cur ?? '-'} KD',
                    style: const TextStyle(color: UC.muted, fontSize: 12)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: (stColors[st] ?? UC.muted).withOpacity(.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(stLabels[st] ?? st,
                  style: TextStyle(
                      color: stColors[st] ?? UC.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
          if (editable) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _keep[id] = !keep;
                    if (_keep[id] == true) _ctl[id]?.clear();
                  }),
                  style: OutlinedButton.styleFrom(
                      backgroundColor: keep ? UC.success : Colors.white,
                      foregroundColor: keep ? Colors.white : UC.brown,
                      side: BorderSide(color: keep ? UC.success : UC.brown)),
                  icon: Icon(keep ? Icons.check : Icons.check_outlined, size: 16),
                  label: Text(ar ? 'مطابِق' : 'Match',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctl[id],
                  enabled: !keep,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    if (v.isNotEmpty && keep) setState(() => _keep[id] = false);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: ar ? 'سعر جديد' : 'New price',
                    suffixText: 'KD',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _Msg extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Msg({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: UC.muted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center,
                style: const TextStyle(color: UC.muted)),
          ]),
        ),
      );
}
