import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key});
  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  Future<List<PayoutSummary>>? _f;
  CommissionList? _comm;
  bool _busy = false;

  bool get _ar => VendorApi.instance.lang == 'ar';
  String get _lang => _ar ? 'ar' : 'en';

  @override
  void initState() {
    super.initState();
    _f = VendorApi.instance.payouts();
    _loadComm();
  }

  Future<void> _loadComm() async {
    try {
      final c = await VendorApi.instance.commissions();
      if (mounted) setState(() => _comm = c);
    } catch (_) {/* summary header is best-effort */}
  }

  Future<void> _refresh() async {
    setState(() => _f = VendorApi.instance.payouts());
    await _f;
    await _loadComm();
  }

  // ── state styling ──────────────────────────────────────
  Color _bg(String s) => switch (s) {
        'paid' || 'done' => UC.successBg,
        'approved' || 'confirmed' => UC.infoBg,
        'draft' || 'pending' => UC.warnBg,
        'cancel' || 'cancelled' || 'canceled' => UC.dangerBg,
        _ => UC.bg,
      };
  Color _fg(String s) => switch (s) {
        'paid' || 'done' => UC.successDk,
        'approved' || 'confirmed' => const Color(0xFF1E40AF),
        'draft' || 'pending' => const Color(0xFF92400E),
        'cancel' || 'cancelled' || 'canceled' => UC.dangerDk,
        _ => UC.muted,
      };
  IconData _stateIcon(String s) => switch (s) {
        'paid' || 'done' => Icons.check_circle_rounded,
        'approved' || 'confirmed' => Icons.verified_rounded,
        'draft' || 'pending' => Icons.schedule_rounded,
        'cancel' || 'cancelled' || 'canceled' => Icons.cancel_rounded,
        _ => Icons.circle,
      };

  String _maskIban(String? iban) {
    if (iban == null || iban.trim().isEmpty) return '';
    final s = iban.replaceAll(' ', '');
    if (s.length <= 6) return s;
    final head = s.substring(0, 2);
    final tail = s.substring(s.length - 4);
    return '$head•••• •••• $tail';
  }

  String _dateOnly(String? v) => (v == null || v.isEmpty) ? '—' : v.split('T').first;

  // ── request flow ───────────────────────────────────────
  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      final p = await VendorApi.instance.requestPayout();
      if (!mounted) return;
      // line_count == 0  →  nothing to pay out (friendly empty state, not an error)
      if (p.lineCount <= 0 || p.amount.amount <= 0) {
        await _showResult(
          icon: Icons.savings_outlined,
          tint: UC.info,
          title: _ar ? 'لا توجد عمولات للدفع' : 'Nothing to pay out yet',
          message: _ar
              ? 'لا توجد عمولات مُفرَج عنها جاهزة للدفع حالياً. ستظهر هنا فور اكتمال الطلبات والإفراج عن عمولاتها.'
              : 'There are no released commissions ready to pay out right now. They will appear here once orders complete and their commissions are released.',
        );
      } else {
        await _showResult(
          icon: Icons.check_circle_rounded,
          tint: UC.success,
          title: _ar ? 'تم إنشاء طلب الدفع' : 'Payout request created',
          message: _ar
              ? 'تم إنشاء طلب دفع بنجاح.'
              : 'Your payout request was created successfully.',
          amount: p.amount,
          lineCount: p.lineCount,
        );
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      await _showResult(
        icon: Icons.error_outline_rounded,
        tint: UC.danger,
        title: _ar ? 'تعذّر إنشاء الطلب' : 'Request could not be completed',
        message: _friendlyError(e),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object e) {
    var s = e.toString();
    final idx = s.indexOf('): ');
    if (idx != -1) s = s.substring(idx + 3);
    s = s.replaceFirst(RegExp(r'^VendorApiException[^:]*:\s*'), '').trim();
    if (s.isEmpty) {
      return _ar ? 'حدث خطأ غير متوقع. حاول مرة أخرى.' : 'An unexpected error occurred. Please try again.';
    }
    return s;
  }

  Future<void> _showResult({
    required IconData icon,
    required Color tint,
    required String title,
    required String message,
    Money? amount,
    int? lineCount,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 56, height: 56, alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: tint, size: 30),
              ),
              const SizedBox(height: 14),
              Text(title, style: UT.h2, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message, style: UT.body, textAlign: TextAlign.center),
              if (amount != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                      color: UC.bg, borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    Text(_ar ? 'مبلغ الدفعة' : 'Payout amount', style: UT.small),
                    const SizedBox(height: 4),
                    Text(amount.format(_lang),
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: UC.brown)),
                    if (lineCount != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _ar
                            ? '$lineCount عمولة مُضمّنة'
                            : '$lineCount commission line${lineCount == 1 ? '' : 's'} included',
                        style: UT.small,
                      ),
                    ],
                  ]),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(_ar ? 'تم' : 'Done'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── payout detail sheet ────────────────────────────────
  void _openDetail(PayoutSummary p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Directionality(
        textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (_, scroll) => _PayoutDetailBody(
            p: p,
            lang: _lang,
            ar: _ar,
            commissions: _comm,
            bg: _bg,
            fg: _fg,
            stateIcon: _stateIcon,
            maskIban: _maskIban,
            dateOnly: _dateOnly,
            scroll: scroll,
          ),
        ),
      ),
    );
  }

  // ── totals header ──────────────────────────────────────
  Widget _summaryHeader() {
    final c = _comm;
    if (c == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [UC.brown, UC.brownSoft],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_ar ? 'ملخّص العمولات' : 'Commission summary',
            style: const TextStyle(
                color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 11)),
        const SizedBox(height: 12),
        Row(children: [
          _totalCell(_ar ? 'مُعلّقة' : 'Pending', c.pending, UC.warn),
          _div(),
          _totalCell(_ar ? 'جاهزة' : 'Released', c.released, UC.yellow),
          _div(),
          _totalCell(_ar ? 'مدفوعة' : 'Paid out', c.paidOut, UC.success),
        ]),
      ]),
    );
  }

  Widget _div() => Container(width: 1, height: 34, color: Colors.white24);

  Widget _totalCell(String label, Money m, Color dot) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 7, height: 7,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 10.5))),
          ]),
          const SizedBox(height: 4),
          Text(m.format(_lang),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900)),
        ]),
      );

  // ── payout card ────────────────────────────────────────
  Widget _payoutCard(PayoutSummary p) {
    final iban = _maskIban(p.bankIban);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UC.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(p),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    width: 40, height: 40, alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: UC.yellowFaint, borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.payments, color: UC.brown, size: 19)),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w900,
                            fontSize: 12.5,
                            color: UC.ink)),
                    const SizedBox(height: 3),
                    UPill(
                        text: p.stateLabel.t(_lang),
                        bg: _bg(p.state),
                        fg: _fg(p.state),
                        icon: _stateIcon(p.state)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(p.amount.format(_lang),
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: UC.brown)),
                  const SizedBox(height: 2),
                  Text(
                      _ar
                          ? '${p.lineCount} عمولة'
                          : '${p.lineCount} line${p.lineCount == 1 ? '' : 's'}',
                      style: UT.tiny),
                ]),
              ]),
              const SizedBox(height: 12),
              Container(height: 1, color: UC.bg),
              const SizedBox(height: 10),
              Row(children: [
                _metaCell(Icons.event_available_rounded,
                    _ar ? 'تاريخ الدفع' : 'Payout date', _dateOnly(p.payoutDate)),
                _metaCell(Icons.add_circle_outline_rounded,
                    _ar ? 'تاريخ الإنشاء' : 'Created', _dateOnly(p.when)),
              ]),
              if (iban.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.account_balance_rounded, size: 14, color: UC.muted),
                  const SizedBox(width: 6),
                  Text(_ar ? 'الآيبان:' : 'IBAN:', style: UT.small),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(iban,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: UC.text))),
                ]),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_ar ? 'عرض التفاصيل' : 'View details',
                      style: const TextStyle(
                          color: UC.brown, fontWeight: FontWeight.w900, fontSize: 11.5)),
                  const SizedBox(width: 2),
                  Icon(_ar ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                      size: 18, color: UC.brown),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _metaCell(IconData icon, String label, String value) => Expanded(
        child: Row(children: [
          Icon(icon, size: 14, color: UC.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: UT.tiny),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: UC.text)),
            ]),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _ar ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: Text(_ar ? 'الدفعات' : 'Payouts')),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<PayoutSummary>>(
            future: _f,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: USpinner());
              }
              if (snap.hasError) {
                return ListView(children: [
                  const SizedBox(height: 90),
                  const Icon(Icons.cloud_off_rounded, size: 44, color: UC.muted),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(_friendlyError(snap.error!),
                        style: UT.body, textAlign: TextAlign.center),
                  ),
                ]);
              }
              final rows = snap.data ?? const <PayoutSummary>[];
              return ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  _summaryHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 2),
                    child: Text(_ar ? 'سجل الدفعات' : 'Payout history', style: UT.h2),
                  ),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
                      child: Column(children: [
                        const Icon(Icons.receipt_long_rounded, size: 44, color: UC.muted),
                        const SizedBox(height: 12),
                        Text(_ar ? 'لا توجد دفعات بعد' : 'No payouts yet',
                            style: UT.h3, textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        Text(
                            _ar
                                ? 'اطلب دفعتك الأولى عندما تتوفر عمولات جاهزة.'
                                : 'Request your first payout once you have released commissions.',
                            style: UT.small, textAlign: TextAlign.center),
                      ]),
                    )
                  else
                    ...rows.map(_payoutCard),
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
                color: Colors.white, border: Border(top: BorderSide(color: UC.border))),
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _request,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
                  : const Icon(Icons.send, size: 18),
              label: Text(_ar ? 'طلب دفعة جديدة' : 'Request new payout',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ),
      ),
    );
  }
}

// ── detail body ──────────────────────────────────────────
class _PayoutDetailBody extends StatelessWidget {
  const _PayoutDetailBody({
    required this.p,
    required this.lang,
    required this.ar,
    required this.commissions,
    required this.bg,
    required this.fg,
    required this.stateIcon,
    required this.maskIban,
    required this.dateOnly,
    required this.scroll,
  });
  final PayoutSummary p;
  final String lang;
  final bool ar;
  final CommissionList? commissions;
  final Color Function(String) bg, fg;
  final IconData Function(String) stateIcon;
  final String Function(String?) maskIban;
  final String Function(String?) dateOnly;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final iban = maskIban(p.bankIban);
    // Best-effort: show the commission lines we already have (no new endpoint).
    final lines = commissions?.items ?? const <Commission>[];
    return Column(children: [
      const SizedBox(height: 10),
      Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: UC.border, borderRadius: BorderRadius.circular(99))),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: UC.ink)),
              const SizedBox(height: 5),
              UPill(
                  text: p.stateLabel.t(lang),
                  bg: bg(p.state),
                  fg: fg(p.state),
                  icon: stateIcon(p.state)),
            ]),
          ),
          Text(p.amount.format(lang),
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: UC.brown)),
        ]),
      ),
      const SizedBox(height: 14),
      Expanded(
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          children: [
            _kv(ar ? 'تاريخ الدفع' : 'Payout date', dateOnly(p.payoutDate)),
            _kv(ar ? 'تاريخ الإنشاء' : 'Created', dateOnly(p.when)),
            _kv(ar ? 'عدد العمولات' : 'Commission lines', '${p.lineCount}'),
            if (iban.isNotEmpty) _kv(ar ? 'الآيبان' : 'IBAN', iban, mono: true),
            const SizedBox(height: 18),
            Row(children: [
              Text(ar ? 'العمولات' : 'Commission lines', style: UT.h3),
              const SizedBox(width: 8),
              if (lines.isNotEmpty)
                Text('(${lines.length})', style: UT.small),
            ]),
            const SizedBox(height: 8),
            if (lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                    ar
                        ? 'لا توجد تفاصيل عمولات متاحة لعرضها.'
                        : 'No commission line details available to display.',
                    style: UT.small),
              )
            else
              ...lines.map((c) => _lineCard(c)),
          ],
        ),
      ),
    ]);
  }

  Widget _kv(String k, String v, {bool mono = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: Text(k, style: UT.small)),
          Expanded(
            flex: 6,
            child: Text(v,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: UC.text,
                    fontFamily: mono ? 'monospace' : null)),
          ),
        ]),
      );

  Widget _lineCard(Commission c) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: UC.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(c.orderName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 12.5, color: UC.ink)),
            ),
            Text(dateOnly(c.orderDate), style: UT.tiny),
          ]),
          const SizedBox(height: 8),
          _lineRow(ar ? 'مبلغ الطلب' : 'Order amount', c.orderAmount.format(lang)),
          _lineRow(
              ar
                  ? 'العمولة (${c.commissionRate.toStringAsFixed(1)}%)'
                  : 'Commission (${c.commissionRate.toStringAsFixed(1)}%)',
              c.commissionAmount.format(lang)),
          Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 6),
              color: UC.border),
          _lineRow(ar ? 'صافي البائع' : 'Net to vendor', c.netAmount.format(lang),
              bold: true),
        ]),
      );

  Widget _lineRow(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
              child: Text(k,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: bold ? UC.ink : UC.muted,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w600))),
          Text(v,
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                  color: bold ? UC.brown : UC.text)),
        ]),
      );
}
