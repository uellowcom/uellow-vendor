import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Bulk product import — upload a CSV/Excel file → it parses into editable
/// rows → fix issues → submit for Uellow review (which creates the products).
class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});
  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  late Future<List<Map<String, dynamic>>> _f;
  bool _busy = false;
  bool get _ar => VendorApi.instance.lang == 'ar';

  @override
  void initState() { super.initState(); _f = VendorApi.instance.imports(); }
  void _reload() => setState(() => _f = VendorApi.instance.imports());

  String _stateLabel(String s) => {
    'draft': _ar ? 'مسودة' : 'Draft',
    'review': _ar ? 'بانتظار المراجعة' : 'In review',
    'done': _ar ? 'تم الاستيراد' : 'Imported',
    'rejected': _ar ? 'مرفوض' : 'Rejected',
  }[s] ?? s;
  Color _stateColor(String s) => {
    'draft': UC.warn, 'review': UC.info, 'done': UC.successDk, 'rejected': UC.dangerDk}[s] ?? UC.muted;

  Future<void> _pickAndCreate() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['csv', 'xlsx'], withData: true);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_ar ? 'تعذّر قراءة الملف' : 'Could not read file')));
      return;
    }
    setState(() => _busy = true);
    try {
      final job = await VendorApi.instance.importCreate(base64Encode(bytes), f.name);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => ImportDetailScreen(jobId: job['id'] as int)));
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(ar ? 'الاستيراد الجماعي' : 'Bulk import')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: UC.brown, foregroundColor: UC.yellow,
        onPressed: _busy ? null : _pickAndCreate,
        icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: UC.yellow))
          : const Icon(Icons.upload_file),
        label: Text(ar ? 'رفع ملف' : 'Upload file')),
      body: RefreshIndicator(onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(future: _f, builder: (_, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: USpinner());
          if (s.hasError) return ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('${s.error}', textAlign: TextAlign.center))]);
          final jobs = s.data ?? const [];
          return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: UC.yellowFaint, borderRadius: BorderRadius.circular(12), border: Border.all(color: UC.border)),
              child: Row(children: [
                const Icon(Icons.lightbulb_outline, color: UC.brown, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(ar
                  ? 'ارفع ملف CSV أو Excel بأعمدة: name_en, name_ar, sku, barcode, cost, price, category, description — ثم عدّل الصفوف وأرسلها للمراجعة.'
                  : 'Upload a CSV/Excel with columns: name_en, name_ar, sku, barcode, cost, price, category, description — then edit rows and submit for review.',
                  style: UT.small)),
              ])),
            const SizedBox(height: 12),
            if (jobs.isEmpty) Padding(padding: const EdgeInsets.all(28),
              child: Column(children: [
                const Icon(Icons.cloud_upload_outlined, size: 44, color: UC.muted),
                const SizedBox(height: 10),
                Text(ar ? 'لا عمليات استيراد بعد' : 'No imports yet', style: UT.body),
              ])),
            for (final j in jobs) _jobCard(j, ar),
          ]);
        })),
    );
  }

  Widget _jobCard(Map<String, dynamic> j, bool ar) {
    final st = '${j['state']}';
    return Container(margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: UC.border)),
      child: ListTile(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => ImportDetailScreen(jobId: j['id'] as int)));
          _reload();
        },
        leading: Container(width: 40, height: 40, alignment: Alignment.center,
          decoration: BoxDecoration(color: UC.yellowFaint, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.description_outlined, color: UC.brown)),
        title: Text('${j['name']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        subtitle: Text('${j['file_name']} · ${j['row_count']} ${ar ? "صف" : "rows"}'
          '${(j['error_count'] ?? 0) != 0 ? ' · ${j['error_count']} ${ar ? "خطأ" : "errors"}' : ''}'
          '${(j['created_count'] ?? 0) != 0 ? ' · ${j['created_count']} ${ar ? "أُنشئ" : "created"}' : ''}', style: UT.small),
        trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: _stateColor(st).withValues(alpha: .14), borderRadius: BorderRadius.circular(8)),
          child: Text(_stateLabel(st), style: TextStyle(color: _stateColor(st), fontSize: 10.5, fontWeight: FontWeight.w800))),
      ));
  }
}

// ─────────────── Import detail (editable rows) ───────────────
class ImportDetailScreen extends StatefulWidget {
  final int jobId;
  const ImportDetailScreen({super.key, required this.jobId});
  @override
  State<ImportDetailScreen> createState() => _ImportDetailScreenState();
}

class _ImportDetailScreenState extends State<ImportDetailScreen> {
  Map<String, dynamic>? _job;
  bool _loading = true, _busy = false;
  bool get _ar => VendorApi.instance.lang == 'ar';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final j = await VendorApi.instance.importGet(widget.jobId);
      if (!mounted) return;
      setState(() { _job = j; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  bool get _editable => (_job?['state'] ?? '') == 'draft';

  Future<void> _editLine(Map<String, dynamic> line) async {
    final ctl = {for (final k in ['name_en','name_ar','sku','barcode','cost','price','category','description'])
      k: TextEditingController(text: '${line[k] ?? ''}')};
    final saved = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Padding(padding: EdgeInsets.only(left: 14, right: 14, top: 16,
        bottom: MediaQuery.of(c).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_ar ? 'تعديل الصف' : 'Edit row', style: UT.h2),
          const SizedBox(height: 10),
          Flexible(child: ListView(shrinkWrap: true, children: [
            for (final k in ['name_ar','name_en','price','cost','sku','barcode','category','description'])
              Padding(padding: const EdgeInsets.only(bottom: 8),
                child: TextField(controller: ctl[k],
                  keyboardType: (k == 'price' || k == 'cost') ? TextInputType.number : TextInputType.text,
                  decoration: InputDecoration(labelText: k, isDense: true))),
          ])),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => Navigator.pop(c, true), child: Text(_ar ? 'حفظ' : 'Save'))),
        ])));
    if (saved != true) return;
    try {
      await VendorApi.instance.importEditLine(widget.jobId, line['id'] as int,
        {for (final e in ctl.entries) e.key: e.value.text.trim()});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    for (final c in ctl.values) { c.dispose(); }
  }

  Future<void> _deleteLine(int lineId) async {
    try { await VendorApi.instance.importDeleteLine(widget.jobId, lineId); _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> _submit() async {
    final errs = ((_job?['lines'] as List?) ?? const []).where((l) => '${(l as Map)['error'] ?? ''}'.isNotEmpty).length;
    if (errs > 0) {
      final go = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: Text(_ar ? 'توجد أخطاء' : 'Some rows have issues'),
        content: Text(_ar ? '$errs صف به مشاكل ولن يُستورد. المتابعة؟' : '$errs row(s) have issues and will be skipped. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_ar ? 'تراجع' : 'Back')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_ar ? 'إرسال' : 'Submit')),
        ]));
      if (go != true) return;
    }
    setState(() => _busy = true);
    try {
      await VendorApi.instance.importSubmit(widget.jobId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_ar ? 'أُرسل للمراجعة' : 'Submitted for review')));
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
    final lines = ((_job?['lines'] as List?) ?? const []).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(_job?['name']?.toString() ?? (ar ? 'استيراد' : 'Import'))),
      body: _loading ? const Center(child: USpinner()) : ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          Expanded(child: Text('${lines.length} ${ar ? "صف" : "rows"} · ${_stateLabel()}', style: UT.h3)),
        ]),
        const SizedBox(height: 8),
        for (final l in lines) _lineCard(l, ar),
        const SizedBox(height: 90),
      ]),
      bottomNavigationBar: (_editable && !_loading) ? SafeArea(top: false, child: Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
            : const Icon(Icons.send, size: 18),
          label: Text(ar ? 'إرسال للمراجعة' : 'Submit for review',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50))))) : null,
    );
  }

  String _stateLabel() => {
    'draft': _ar ? 'مسودة' : 'Draft', 'review': _ar ? 'بانتظار المراجعة' : 'In review',
    'done': _ar ? 'تم الاستيراد' : 'Imported', 'rejected': _ar ? 'مرفوض' : 'Rejected',
  }[_job?['state']] ?? '${_job?['state'] ?? ''}';

  Widget _lineCard(Map<String, dynamic> l, bool ar) {
    final err = '${l['error'] ?? ''}';
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: err.isNotEmpty ? UC.danger : UC.border)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${l['name_ar']?.toString().isNotEmpty == true ? l['name_ar'] : l['name_en'] ?? ''}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          Text('${l['price'] ?? '-'} ${ar ? "د.ك" : "KD"}${(l['sku'] ?? '').toString().isNotEmpty ? ' · ${l['sku']}' : ''}'
            '${(l['category'] ?? '').toString().isNotEmpty ? ' · ${l['category']}' : ''}', style: UT.small),
          if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3),
            child: Text('⚠ $err', style: const TextStyle(color: UC.dangerDk, fontSize: 11, fontWeight: FontWeight.w700))),
        ])),
        if (_editable) ...[
          IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: UC.brown), onPressed: () => _editLine(l)),
          IconButton(icon: const Icon(Icons.close, size: 18, color: UC.dangerDk), onPressed: () => _deleteLine(l['id'] as int)),
        ] else if (l['created'] == true)
          const Icon(Icons.check_circle, color: UC.successDk, size: 20),
      ]));
  }
}
