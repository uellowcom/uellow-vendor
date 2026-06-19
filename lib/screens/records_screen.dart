import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Generic drill-down: shows the records behind a KPI/home block. Opened with
/// arguments {metric, title}. Rows know their own kind ('order'/'product'/…).
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key, required this.metric, required this.title});
  final String metric;
  final String title;
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  Future<List<Map<String, dynamic>>>? _f;
  @override
  void initState() { super.initState(); _f = VendorApi.instance.analyticsRecords(widget.metric); }
  Future<void> _refresh() async {
    setState(() => _f = VendorApi.instance.analyticsRecords(widget.metric));
    await _f;
  }

  void _open(Map<String, dynamic> r) {
    final kind = (r['kind'] ?? '').toString();
    final id = (r['id'] is num) ? (r['id'] as num).toInt() : 0;
    if (kind == 'order') {
      Navigator.pushNamed(context, '/order', arguments: {'id': id});
    } else if (kind == 'product') {
      Navigator.pushNamed(context, '/product', arguments: {'id': id});
    }
  }

  IconData _icon(String kind) => switch (kind) {
    'order' => Icons.receipt_long,
    'product' => Icons.inventory_2_outlined,
    'customer' => Icons.person_outline,
    'return' => Icons.assignment_return_outlined,
    _ => Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(widget.title)),
      body: RefreshIndicator(onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(future: _f, builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
          if (snap.hasError) return ListView(children: [Padding(padding: const EdgeInsets.all(24),
            child: Text(snap.error.toString(), textAlign: TextAlign.center, style: UT.body))]);
          final rows = snap.data ?? const [];
          if (rows.isEmpty) {
            return ListView(children: [Padding(padding: const EdgeInsets.all(48),
              child: Column(children: [
                const Icon(Icons.inbox_outlined, size: 46, color: UC.muted),
                const SizedBox(height: 10),
                Text(ar ? 'لا توجد سجلات' : 'No records', style: UT.body),
              ]))]);
          }
          return ListView.separated(padding: const EdgeInsets.all(12),
            itemCount: rows.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(padding: const EdgeInsets.only(bottom: 4, left: 2),
                  child: Text('${rows.length} ${ar ? "سجل" : "records"}', style: UT.small));
              }
              final r = rows[i - 1];
              final kind = (r['kind'] ?? '').toString();
              final tappable = kind == 'order' || kind == 'product';
              return Material(color: Colors.white, borderRadius: BorderRadius.circular(12),
                child: InkWell(borderRadius: BorderRadius.circular(12),
                  onTap: tappable ? () => _open(r) : null,
                  child: Container(padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: UC.border),
                      borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      Container(width: 38, height: 38, alignment: Alignment.center,
                        decoration: BoxDecoration(color: UC.yellowFaint, borderRadius: BorderRadius.circular(10)),
                        child: Icon(_icon(kind), size: 18, color: UC.brown)),
                      const SizedBox(width: 11),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text((r['title'] ?? '').toString(),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                          if ((r['badge'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(width: 6),
                            UPill(text: (r['badge']).toString(), bg: UC.infoBg, fg: const Color(0xFF1E40AF)),
                          ],
                        ]),
                        if ((r['subtitle'] ?? '').toString().isNotEmpty)
                          Text((r['subtitle']).toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: UT.small),
                      ])),
                      const SizedBox(width: 8),
                      Text((r['trailing'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w900, color: UC.brown, fontSize: 12.5)),
                      if (tappable) const Icon(Icons.chevron_right, color: UC.muted, size: 18),
                    ]))));
            });
        })),
    );
  }
}
