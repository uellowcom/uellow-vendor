import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Marketplace promotions — available campaigns the vendor can JOIN with their
/// products (calls /promotions/join) + the vendor's joined lines.
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});
  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _canJoin = true;

  @override
  void initState() {
    super.initState();
    _future = VendorApi.instance.promotions();
    _checkCaps();
  }

  Future<void> _checkCaps() async {
    try {
      final caps = await VendorApi.instance.capabilities();
      if (mounted) {
        setState(() => _canJoin = (caps['capabilities'] as Map?)?['join_promotions'] != false);
      }
    } catch (_) {}
  }

  void _reload() => setState(() => _future = VendorApi.instance.promotions());

  Color _lineColor(String s) {
    switch (s) {
      case 'approved': return UC.successBg;
      case 'rejected': return UC.dangerBg;
      default: return UC.warnBg;
    }
  }

  Color _lineFg(String s) {
    switch (s) {
      case 'approved': return UC.successDk;
      case 'rejected': return UC.dangerDk;
      default: return UC.warn;
    }
  }

  String _lineLabel(String s, bool ar) {
    switch (s) {
      case 'approved': return ar ? 'مقبول' : 'Approved';
      case 'rejected': return ar ? 'مرفوض' : 'Rejected';
      default: return ar ? 'قيد المراجعة' : 'Pending';
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────
  String _promoName(Map p, bool ar) {
    final n = p['name'];
    if (n is Map) return (ar ? (n['ar'] ?? n['en']) : (n['en'] ?? n['ar']))?.toString() ?? '';
    return '$n';
  }

  /// Parses "YYYY-MM-DD..." date strings; returns null if unparseable.
  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Live human countdown to [end], or null if ended/none.
  String? _countdown(DateTime? end, bool ar) {
    if (end == null) return null;
    final diff = end.difference(DateTime.now());
    if (diff.isNegative) return ar ? 'انتهت' : 'Ended';
    final days = diff.inDays;
    if (days >= 1) return ar ? 'يتبقى $days يوم' : '$days days left';
    final hrs = diff.inHours;
    if (hrs >= 1) return ar ? 'يتبقى $hrs ساعة' : '$hrs hrs left';
    final mins = diff.inMinutes;
    return ar ? 'يتبقى $mins دقيقة' : '$mins min left';
  }

  // ── join flow ──────────────────────────────────────────────────────────
  Future<void> _join(Map promo) async {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    final minD = ((promo['min_discount_pct'] ?? 0) as num).toDouble();
    final maxD = ((promo['max_discount_pct'] ?? 100) as num).toDouble();
    final base = VendorApi.instance.baseUrl;

    List<ProductSummary> prods;
    try {
      prods = await VendorApi.instance.products(state: 'live');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    if (prods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ar ? 'لا منتجات منشورة للانضمام' : 'No live products to join')));
      return;
    }

    final selected = <int>{};
    final discCtrl = TextEditingController(text: minD.toStringAsFixed(0));
    bool submitting = false;

    final name = _promoName(promo, ar);
    final dateTo = _parseDate(promo['date_to']);
    final dateFrom = _parseDate(promo['date_from']);

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => StatefulBuilder(builder: (c, setM) {
        final h = MediaQuery.of(c).size.height;
        // Live discount echo & clamp preview.
        final typed = double.tryParse(discCtrl.text.trim());
        final clamped = typed?.clamp(minD, maxD).toDouble();
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * 0.92),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // grab handle
              Container(width: 42, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 6),
                decoration: BoxDecoration(color: UC.border, borderRadius: BorderRadius.circular(99))),
              // ── hero ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: _heroBlock(name, minD, maxD, dateFrom, dateTo, ar),
              ),
              const Divider(height: 1, color: UC.border),
              // ── discount field ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ar ? 'نسبة الخصم لكل المنتجات المختارة'
                            : 'Discount applied to selected products',
                        style: UT.h3),
                    const SizedBox(height: 2),
                    Text(
                      clamped != null && typed != null && clamped != typed
                          ? (ar ? 'سيتم ضبطها إلى ${clamped.toStringAsFixed(0)}% ضمن الحدود'
                                : 'Will be capped to ${clamped.toStringAsFixed(0)}% within limits')
                          : (ar ? 'ضمن $minD%–$maxD%' : 'Within $minD%–$maxD%'),
                      style: UT.small),
                  ])),
                  const SizedBox(width: 10),
                  SizedBox(width: 96, child: TextField(
                    controller: discCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: UC.brown),
                    onChanged: (_) => setM(() {}),
                    decoration: InputDecoration(
                      suffixText: '%',
                      suffixStyle: const TextStyle(fontWeight: FontWeight.w900, color: UC.brown),
                      hintText: minD.toStringAsFixed(0),
                    ),
                  )),
                ]),
              ),
              // ── product selector header ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Row(children: [
                  Expanded(child: Text(ar ? 'اختر المنتجات للانضمام' : 'Select products to enrol',
                      style: UT.h3)),
                  UPill(
                    text: ar ? '${selected.length} مختار' : '${selected.length} selected',
                    bg: selected.isEmpty ? UC.bg : UC.yellowFaint,
                    fg: selected.isEmpty ? UC.muted : UC.brown,
                    icon: Icons.check_circle_outline),
                ]),
              ),
              // quick select all / none
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  TextButton.icon(
                    onPressed: () => setM(() => selected
                      ..clear()
                      ..addAll(prods.map((e) => e.id))),
                    icon: const Icon(Icons.done_all, size: 16, color: UC.brown),
                    label: Text(ar ? 'تحديد الكل' : 'Select all',
                        style: const TextStyle(color: UC.brown, fontWeight: FontWeight.w800, fontSize: 12))),
                  TextButton.icon(
                    onPressed: selected.isEmpty ? null : () => setM(() => selected.clear()),
                    icon: const Icon(Icons.remove_done, size: 16, color: UC.muted),
                    label: Text(ar ? 'مسح' : 'Clear',
                        style: const TextStyle(color: UC.muted, fontWeight: FontWeight.w800, fontSize: 12))),
                ]),
              ),
              // ── product list ──────────────────────────────────────────
              Flexible(child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                shrinkWrap: true,
                itemCount: prods.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = prods[i];
                  final on = selected.contains(p.id);
                  return _productTile(p, on, lang, base, () => setM(() {
                    if (on) { selected.remove(p.id); } else { selected.add(p.id); }
                  }));
                },
              )),
              // ── confirm bar ───────────────────────────────────────────
              SafeArea(top: false, child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: UC.border)),
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: selected.isEmpty ? UC.border : UC.yellow,
                    foregroundColor: UC.brown,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  onPressed: (selected.isEmpty || submitting) ? null : () {
                    setM(() => submitting = true);
                    Navigator.pop(c, true);
                  },
                  icon: submitting
                      ? const SizedBox(width: 16, height: 16, child: USpinner(size: 16))
                      : const Icon(Icons.campaign_rounded, size: 20),
                  label: Text(selected.isEmpty
                      ? (ar ? 'اختر منتجاً واحداً على الأقل' : 'Select at least one product')
                      : (ar ? 'إرسال طلب الانضمام (${selected.length})'
                            : 'Submit join request (${selected.length})')),
                ),
              )),
            ]),
          ),
        );
      }),
    );

    if (submitted != true) return;
    var disc = double.tryParse(discCtrl.text.trim()) ?? minD;
    if (disc < minD) disc = minD;
    if (disc > maxD) disc = maxD;
    final items = selected.map((id) => {'product_id': id, 'discount_pct': disc}).toList();
    try {
      await VendorApi.instance.promotionJoin(promo['id'] as int, items);
      if (!mounted) return;
      _toast(ar ? 'تم إرسال طلب الانضمام للمراجعة' : 'Join request submitted for review',
          ok: true);
      _reload();
    } catch (e) {
      if (!mounted) return;
      _toast('$e', ok: false);
    }
  }

  void _toast(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ok ? UC.successDk : UC.dangerDk,
      content: Row(children: [
        Icon(ok ? Icons.check_circle : Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ]),
    ));
  }

  // ── hero block (inside join sheet) ───────────────────────────────────────
  Widget _heroBlock(String name, double minD, double maxD,
      DateTime? from, DateTime? to, bool ar) {
    final cd = _countdown(to, ar);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [UC.yellow, UC.yellowSoft],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: UC.brown, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.local_offer_rounded, color: UC.yellow, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ar ? 'حملة ترويجية' : 'Marketplace campaign',
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: UC.brownSoft)),
            const SizedBox(height: 1),
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: UC.brown)),
          ])),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _heroChip(Icons.percent_rounded,
              ar ? 'الخصم ${minD.toStringAsFixed(0)}%–${maxD.toStringAsFixed(0)}%'
                 : 'Discount ${minD.toStringAsFixed(0)}%–${maxD.toStringAsFixed(0)}%'),
          if (from != null)
            _heroChip(Icons.play_arrow_rounded,
                '${ar ? "يبدأ" : "From"} ${_fmtDate(from)}'),
          if (to != null)
            _heroChip(Icons.event_busy_rounded,
                '${ar ? "ينتهي" : "Ends"} ${_fmtDate(to)}'),
          if (cd != null)
            _heroChip(Icons.timer_outlined, cd, live: true),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, size: 15, color: UC.brownSoft),
            const SizedBox(width: 6),
            Expanded(child: Text(
              ar
                ? 'سيُطبَّق الخصم على المنتجات المختارة بعد موافقة الإدارة. يمكنك تركها لاحقاً من قائمة مشاركاتي.'
                : 'The discount applies to selected products after admin approval. You can leave entries later from “My entries”.',
              style: const TextStyle(fontSize: 11, color: UC.brownSoft, height: 1.35, fontWeight: FontWeight.w600))),
          ]),
        ),
      ]),
    );
  }

  Widget _heroChip(IconData icon, String text, {bool live = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (live) Container(width: 7, height: 7, margin: const EdgeInsetsDirectional.only(end: 5),
        decoration: const BoxDecoration(color: UC.danger, shape: BoxShape.circle)),
      Icon(icon, size: 13, color: UC.brown),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: UC.brown)),
    ]),
  );

  // ── product tile (inside join sheet) ─────────────────────────────────────
  Widget _productTile(ProductSummary p, bool on, String lang, String base, VoidCallback toggle) {
    return InkWell(
      onTap: toggle,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: on ? UC.yellowFaint : Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: on ? UC.yellow : UC.border, width: on ? 1.6 : 1),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: p.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: '$base${p.imageUrl!}',
                  width: 52, height: 52, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(width: 52, height: 52,
                    color: UC.bg, child: const Icon(Icons.image, color: UC.muted, size: 20)))
              : Container(width: 52, height: 52, color: UC.yellowFaint,
                  child: const Icon(Icons.image, color: UC.brown, size: 20))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name.t(lang), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: UC.ink)),
            const SizedBox(height: 3),
            Text(p.listPrice.format(lang),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: UC.brown)),
          ])),
          const SizedBox(width: 8),
          // visual checkbox
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: on ? UC.yellow : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: on ? UC.yellow : UC.border, width: 1.6)),
            child: on ? const Icon(Icons.check_rounded, size: 17, color: UC.brown) : null),
        ]),
      ),
    );
  }

  // ── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Directionality(
      textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(ar ? 'الحملات الترويجية' : 'Promotions')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) {
              return const USpinner();
            }
            if (s.hasError) {
              return _errorState('${s.error}', ar);
            }
            final d = s.data ?? const {};
            final avail = (d['available'] as List?) ?? const [];
            final mine = (d['mine'] as List?) ?? const [];
            return RefreshIndicator(
              color: UC.brown,
              onRefresh: () async => _reload(),
              child: ListView(padding: const EdgeInsets.fromLTRB(12, 14, 12, 28), children: [
                _sectionHeader(Icons.campaign_rounded,
                    ar ? 'حملات متاحة للانضمام' : 'Open campaigns',
                    avail.length, ar),
                const SizedBox(height: 10),
                if (avail.isEmpty) _emptyHint(
                    ar ? 'لا حملات متاحة حالياً' : 'No open campaigns right now',
                    Icons.inbox_outlined),
                for (final p in avail) _availCard(p as Map, ar),
                const SizedBox(height: 22),
                _sectionHeader(Icons.assignment_turned_in_outlined,
                    ar ? 'مشاركاتي' : 'My entries',
                    mine.length, ar),
                const SizedBox(height: 10),
                if (mine.isEmpty) _emptyHint(
                    ar ? 'لم تنضم لأي حملة بعد' : 'You have not joined any campaign yet',
                    Icons.local_offer_outlined),
                for (final l in mine) _mineRow(l as Map, ar),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, int count, bool ar) => Row(children: [
    Icon(icon, size: 18, color: UC.brown),
    const SizedBox(width: 7),
    Text(title, style: UT.h2),
    const SizedBox(width: 8),
    if (count > 0) UPill(text: '$count', bg: UC.yellowFaint, fg: UC.brown),
  ]);

  Widget _emptyHint(String msg, IconData icon) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: UC.border)),
    child: Column(children: [
      Icon(icon, size: 30, color: UC.muted),
      const SizedBox(height: 8),
      Text(msg, textAlign: TextAlign.center, style: UT.small),
    ]),
  );

  Widget _errorState(String err, bool ar) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 40, color: UC.muted),
        const SizedBox(height: 10),
        Text(ar ? 'تعذّر تحميل الحملات' : 'Could not load campaigns', style: UT.h3),
        const SizedBox(height: 4),
        Text(err, textAlign: TextAlign.center, style: UT.small),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _reload,
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(ar ? 'إعادة المحاولة' : 'Retry')),
      ]),
    ),
  );

  // ── available campaign card (list) ───────────────────────────────────────
  Widget _availCard(Map p, bool ar) {
    final name = _promoName(p, ar);
    final minD = ((p['min_discount_pct'] ?? 0) as num).toDouble();
    final maxD = ((p['max_discount_pct'] ?? 0) as num).toDouble();
    final to = _parseDate(p['date_to']);
    final cd = _countdown(to, ar);
    final ending = to != null && to.difference(DateTime.now()).inDays <= 3 &&
        !to.difference(DateTime.now()).isNegative;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UC.border),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // accent strip + title
        Container(
          padding: const EdgeInsets.fromLTRB(13, 13, 13, 11),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [UC.yellowFaint, Colors.white],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: UC.brown, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.local_offer_rounded, color: UC.yellow, size: 17)),
            const SizedBox(width: 9),
            Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: UC.brown))),
            if (ending && cd != null)
              UPill(text: cd, bg: UC.dangerBg, fg: UC.dangerDk, live: true),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 4, 13, 13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 7, runSpacing: 7, children: [
              UPill(
                text: ar ? 'الخصم ${minD.toStringAsFixed(0)}%–${maxD.toStringAsFixed(0)}%'
                         : 'Discount ${minD.toStringAsFixed(0)}%–${maxD.toStringAsFixed(0)}%',
                bg: UC.yellowFaint, fg: UC.brown, icon: Icons.percent_rounded),
              if (to != null && !ending)
                UPill(
                  text: '${ar ? "ينتهي" : "Ends"} ${_fmtDate(to)}',
                  bg: UC.bg, fg: UC.muted, icon: Icons.event_outlined),
              if (cd != null && !ending)
                UPill(text: cd, bg: UC.infoBg, fg: UC.info, icon: Icons.timer_outlined),
            ]),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: UC.yellow, foregroundColor: UC.brown,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              onPressed: _canJoin ? () => _join(p) : null,
              icon: const Icon(Icons.add_circle_outline, size: 19),
              label: Text(_canJoin
                  ? (ar ? 'انضمام بمنتجاتي' : 'Join with my products')
                  : (ar ? 'الانضمام غير متاح' : 'Joining unavailable')))),
          ]),
        ),
      ]),
    );
  }

  // ── my-entries row (list) ────────────────────────────────────────────────
  Widget _mineRow(Map l, bool ar) {
    final state = (l['state'] ?? '').toString();
    final disc = ((l['discount_pct'] ?? 0) as num);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: UC.border)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: UC.bg, borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.sell_outlined, size: 16, color: UC.brown)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${l['product'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: UC.ink)),
          const SizedBox(height: 3),
          Row(children: [
            Flexible(child: Text('${l['promotion'] ?? ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: UT.small)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: UC.yellowFaint, borderRadius: BorderRadius.circular(6)),
              child: Text('-${disc.toStringAsFixed(disc % 1 == 0 ? 0 : 1)}%',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: UC.brown))),
          ]),
        ])),
        const SizedBox(width: 8),
        UPill(text: _lineLabel(state, ar), bg: _lineColor(state), fg: _lineFg(state)),
      ]),
    );
  }
}
