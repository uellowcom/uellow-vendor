import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Live commerce — shoppable product videos hosted on Bunny Stream.
class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});
  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _videos = [];

  bool get _ar => VendorApi.instance.lang == 'ar';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final v = await VendorApi.instance.videos();
      if (!mounted) return;
      setState(() { _videos = v; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _add() async {
    final created = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => const VideoCreateScreen()));
    if (created == true) _load();
  }

  Future<void> _open(Map<String, dynamic> v) async {
    final changed = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => VideoDetailScreen(id: v['id'] as int, seed: v)));
    if (changed == true) _load();
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(_ar ? 'حذف الفيديو' : 'Delete video'),
      content: Text(_ar ? 'حذف هذا الفيديو نهائياً؟' : 'Delete this video permanently?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_ar ? 'إلغاء' : 'Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: UC.danger, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true), child: Text(_ar ? 'حذف' : 'Delete')),
      ]));
    if (ok != true) return;
    try { await VendorApi.instance.videoDelete(id); _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(ar ? 'فيديوهات المنتجات' : 'Shoppable videos')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: UC.brown, foregroundColor: UC.yellow,
        onPressed: _add, icon: const Icon(Icons.video_call),
        label: Text(ar ? 'فيديو جديد' : 'New video')),
      body: _loading
          ? const Center(child: USpinner())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(onRefresh: _load,
                  child: _videos.isEmpty
                    ? ListView(children: [Padding(padding: const EdgeInsets.all(36),
                        child: Column(children: [
                          const Icon(Icons.movie_creation_outlined, size: 48, color: UC.muted),
                          const SizedBox(height: 12),
                          Text(ar ? 'لا توجد فيديوهات بعد' : 'No videos yet',
                            style: UT.h3, textAlign: TextAlign.center),
                          const SizedBox(height: 6),
                          Text(ar ? 'ارفع مقطعاً قصيراً لإبراز منتجك على صفحة المنتج وفي التطبيق.'
                                  : 'Upload a short clip to showcase your product on the product page and in the app.',
                            style: UT.small, textAlign: TextAlign.center),
                        ]))])
                    : GridView.builder(padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .62),
                        itemCount: _videos.length,
                        itemBuilder: (c, i) => _videoCard(_videos[i], ar)),
                ),
    );
  }

  Widget _videoCard(Map<String, dynamic> v, bool ar) {
    final thumb = '${v['thumb_url'] ?? ''}';
    final status = '${v['status'] ?? ''}';
    final encoding = videoIsEncoding(status);
    final pct = (v['encode_pct'] is num) ? (v['encode_pct'] as num).toDouble() : 0.0;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _open(v),
        onLongPress: () => _delete(v['id'] as int),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: UC.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Stack(fit: StackFit.expand, children: [
              ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                child: thumb.isNotEmpty
                  ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
                      placeholder: (_,__) => Container(color: UC.bg, child: const USpinner()),
                      errorWidget: (_,__,___) => Container(color: UC.bg, child: const Icon(Icons.movie, color: UC.muted, size: 36)))
                  : Container(color: UC.bg, child: const Center(child: Icon(Icons.movie, color: UC.muted, size: 36)))),
              const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 38)),
              if (encoding) Positioned(left: 6, top: 6, child: UPill(
                text: pct > 0 ? '${pct.toStringAsFixed(0)}%' : (ar ? 'معالجة' : 'encoding'),
                bg: Colors.black54, fg: Colors.white, icon: Icons.hourglass_top, live: true)),
              if ('${v['duration'] ?? ''}'.isNotEmpty) Positioned(right: 6, bottom: 6,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Text('${v['duration']}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))),
            ])),
            Padding(padding: const EdgeInsets.all(9),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${v['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                Text('${v['product'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: UT.small),
                const SizedBox(height: 6),
                Row(children: [
                  UPill(text: videoStatusLabel(status, ar),
                    bg: videoStatusColor(status).withOpacity(.14), fg: videoStatusColor(status)),
                  const Spacer(),
                  if ((v['views'] ?? 0) != 0) Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.visibility_outlined, size: 12, color: UC.muted),
                    const SizedBox(width: 3),
                    Text('${v['views']}', style: UT.tiny),
                  ]),
                ]),
              ])),
          ]),
        ),
      ),
    );
  }
}

// ─────────────── Shared status helpers ───────────────
Color videoStatusColor(String s) {
  final l = s.toLowerCase();
  if (l.contains('finish') || l.contains('ready') || l == '4') return UC.successDk;
  if (l.contains('error') || l.contains('fail')) return UC.dangerDk;
  if (l.isEmpty) return UC.muted;
  return UC.warn;
}

bool videoIsEncoding(String s) {
  final l = s.toLowerCase();
  if (l.contains('finish') || l.contains('ready') || l == '4') return false;
  if (l.contains('error') || l.contains('fail')) return false;
  return l.isEmpty || l.contains('encod') || l.contains('process') || l.contains('queue') || l.contains('upload');
}

String videoStatusLabel(String s, bool ar) {
  final l = s.toLowerCase();
  if (l.contains('finish') || l.contains('ready') || l == '4') return ar ? 'جاهز' : 'Ready';
  if (l.contains('error') || l.contains('fail')) return ar ? 'فشل' : 'Failed';
  if (l.isEmpty) return ar ? 'بانتظار المعالجة' : 'Processing';
  return s;
}

// ─────────────── Video detail (full page) ───────────────
class VideoDetailScreen extends StatefulWidget {
  final int id;
  final Map<String, dynamic> seed;
  const VideoDetailScreen({super.key, required this.id, this.seed = const {}});
  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  late Map<String, dynamic> _v;
  bool _loading = true;
  String? _error;
  bool _changed = false;

  bool get _ar => VendorApi.instance.lang == 'ar';
  String _base() => VendorApi.instance.baseUrl;

  @override
  void initState() {
    super.initState();
    _v = Map<String, dynamic>.from(widget.seed);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await VendorApi.instance.videoDetail(widget.id);
      if (!mounted) return;
      setState(() { _v = d; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _abs(String u) {
    if (u.isEmpty) return u;
    if (u.startsWith('http')) return u;
    return '${_base()}$u';
  }

  // ── Edit title + sequence ──
  Future<void> _edit() async {
    final ar = _ar;
    final title = TextEditingController(text: '${_v['title'] ?? ''}');
    final seq = TextEditingController(text: '${_v['sequence'] ?? ''}');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(ar ? 'تعديل الفيديو' : 'Edit video'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title,
          decoration: InputDecoration(labelText: ar ? 'العنوان' : 'Title')),
        const SizedBox(height: 12),
        TextField(controller: seq, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: ar ? 'الترتيب' : 'Order / sequence',
            helperText: ar ? 'الأصغر يظهر أولاً' : 'Lower shows first')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ar ? 'حفظ' : 'Save')),
      ]));
    if (ok != true) return;
    final body = <String, dynamic>{'title': title.text.trim()};
    final s = int.tryParse(seq.text.trim());
    if (s != null) body['sequence'] = s;
    try {
      final d = await VendorApi.instance.videoUpdate(widget.id, body);
      if (!mounted) return;
      setState(() { _v = d; _changed = true; });
      _snack(ar ? 'تم الحفظ' : 'Saved');
    } catch (e) { _snack('$e'); }
  }

  // ── Request edit / delete (with optional note) ──
  Future<void> _request(String action) async {
    final ar = _ar;
    final isDelete = action == 'delete';
    final note = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(isDelete
        ? (ar ? 'طلب حذف' : 'Request delete')
        : (ar ? 'طلب تعديل' : 'Request edit')),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(ar
          ? 'سيُرسل طلبك إلى فريق Yellow للمراجعة.'
          : 'Your request will be sent to the Yellow team for review.',
          style: UT.small),
        const SizedBox(height: 12),
        TextField(controller: note, maxLines: 3,
          decoration: InputDecoration(labelText: ar ? 'ملاحظة (اختياري)' : 'Note (optional)',
            hintText: ar ? 'اشرح ما تريد تغييره…' : 'Describe what you need…')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ar ? 'إرسال' : 'Send')),
      ]));
    if (ok != true) return;
    try {
      await VendorApi.instance.videoRequest(widget.id, action, note.text.trim());
      _snack(ar ? 'تم إرسال الطلب' : 'Request sent');
    } catch (e) { _snack('$e'); }
  }

  // ── Direct delete with confirm ──
  Future<void> _delete() async {
    final ar = _ar;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(ar ? 'حذف الفيديو' : 'Delete video'),
      content: Text(ar ? 'حذف هذا الفيديو نهائياً؟' : 'Delete this video permanently?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ar ? 'إلغاء' : 'Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: UC.danger, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true), child: Text(ar ? 'حذف' : 'Delete')),
      ]));
    if (ok != true) return;
    try {
      await VendorApi.instance.videoDelete(widget.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { _snack('$e'); }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    final v = _v;
    final status = '${v['status'] ?? ''}';
    final encoding = videoIsEncoding(status);
    final pct = (v['encode_pct'] is num) ? (v['encode_pct'] as num).toDouble() : 0.0;
    final thumb = '${v['thumb_url'] ?? ''}';
    final canEdit = v['can_edit'] == true || !v.containsKey('can_edit');

    return WillPopScope(
      onWillPop: () async { Navigator.pop(context, _changed); return false; },
      child: Scaffold(
        backgroundColor: UC.bg,
        appBar: AppBar(
          title: Text(ar ? 'الفيديو' : 'Video'),
          leading: IconButton(icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _changed)),
          actions: [
            if (canEdit) IconButton(icon: const Icon(Icons.edit_outlined), tooltip: ar ? 'تعديل' : 'Edit', onPressed: _edit),
            PopupMenuButton<String>(
              onSelected: (s) {
                if (s == 'edit') _edit();
                if (s == 'req_edit') _request('edit');
                if (s == 'req_delete') _request('delete');
                if (s == 'delete') _delete();
              },
              itemBuilder: (_) => [
                if (canEdit) PopupMenuItem(value: 'edit', child: Row(children: [
                  const Icon(Icons.edit_outlined, size: 18, color: UC.brown), const SizedBox(width: 8),
                  Text(ar ? 'تعديل' : 'Edit')])),
                PopupMenuItem(value: 'req_edit', child: Row(children: [
                  const Icon(Icons.rule_folder_outlined, size: 18, color: UC.info), const SizedBox(width: 8),
                  Text(ar ? 'طلب تعديل' : 'Request edit')])),
                PopupMenuItem(value: 'req_delete', child: Row(children: [
                  const Icon(Icons.assignment_late_outlined, size: 18, color: UC.warn), const SizedBox(width: 8),
                  Text(ar ? 'طلب حذف' : 'Request delete')])),
                PopupMenuItem(value: 'delete', child: Row(children: [
                  const Icon(Icons.delete_outline, size: 18, color: UC.danger), const SizedBox(width: 8),
                  Text(ar ? 'حذف' : 'Delete', style: const TextStyle(color: UC.danger))])),
              ],
            ),
          ],
        ),
        body: _loading
          ? const Center(child: USpinner())
          : _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
            : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(14), children: [
                // ── Player / thumbnail ──
                AspectRatio(aspectRatio: 9 / 14, child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(fit: StackFit.expand, children: [
                    thumb.isNotEmpty
                      ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
                          placeholder: (_,__) => Container(color: Colors.black12, child: const USpinner()),
                          errorWidget: (_,__,___) => Container(color: Colors.black12, child: const Icon(Icons.movie, color: UC.muted, size: 48)))
                      : Container(color: Colors.black12, child: const Center(child: Icon(Icons.movie, color: UC.muted, size: 48))),
                    Center(child: Container(
                      decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44))),
                    if (encoding) Positioned(left: 10, top: 10, child: UPill(
                      text: pct > 0 ? '${pct.toStringAsFixed(0)}%' : (ar ? 'معالجة' : 'encoding'),
                      bg: Colors.black54, fg: Colors.white, icon: Icons.hourglass_top, live: true)),
                    if ('${v['duration'] ?? ''}'.isNotEmpty) Positioned(right: 10, bottom: 10,
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                        child: Text('${v['duration']}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)))),
                  ]))),
                const SizedBox(height: 14),

                // ── Title + status ──
                Text('${v['title'] ?? ''}', style: UT.h1),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  UPill(text: videoStatusLabel(status, ar),
                    bg: videoStatusColor(status).withOpacity(.14), fg: videoStatusColor(status),
                    icon: encoding ? Icons.hourglass_top : Icons.check_circle, live: encoding),
                  if ((v['views'] ?? 0) != 0)
                    UPill(text: ar ? '${v['views']} مشاهدة' : '${v['views']} views', icon: Icons.visibility_outlined),
                  if ('${v['type'] ?? ''}'.isNotEmpty)
                    UPill(text: '${v['type']}', icon: Icons.movie_filter_outlined),
                  if (v['active'] == false)
                    UPill(text: ar ? 'غير نشط' : 'Inactive', bg: UC.dangerBg, fg: UC.dangerDk, icon: Icons.visibility_off_outlined),
                ]),

                // ── Encode progress ──
                if (encoding) ...[
                  const SizedBox(height: 14),
                  Container(padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: UC.warnBg, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.hourglass_top, size: 16, color: UC.warn), const SizedBox(width: 6),
                        Text(ar ? 'جاري المعالجة' : 'Encoding', style: UT.h3),
                        const Spacer(),
                        if (pct > 0) Text('${pct.toStringAsFixed(0)}%', style: UT.h3),
                      ]),
                      const SizedBox(height: 8),
                      ClipRRect(borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: pct > 0 ? (pct / 100).clamp(0.0, 1.0) : null,
                          minHeight: 7, backgroundColor: Colors.white, color: UC.warn)),
                    ])),
                ],

                const SizedBox(height: 14),

                // ── Linked product ──
                _section(ar ? 'المنتج المرتبط' : 'Linked product', Icons.shopping_bag_outlined,
                  Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(10),
                      child: '${v['product_image'] ?? ''}'.isNotEmpty
                        ? CachedNetworkImage(imageUrl: _abs('${v['product_image']}'), width: 52, height: 52, fit: BoxFit.cover,
                            placeholder: (_,__) => Container(width: 52, height: 52, color: UC.bg),
                            errorWidget: (_,__,___) => Container(width: 52, height: 52, color: UC.border, child: const Icon(Icons.image, color: UC.muted)))
                        : Container(width: 52, height: 52, color: UC.border, child: const Icon(Icons.image, color: UC.muted))),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${v['product'] ?? (ar ? '—' : '—')}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))),
                  ])),

                const SizedBox(height: 12),

                // ── Info rows ──
                _section(ar ? 'التفاصيل' : 'Details', Icons.info_outline, Column(children: [
                  _row(ar ? 'المدة' : 'Duration', '${v['duration'] ?? '—'}'),
                  _row(ar ? 'المشاهدات' : 'Views', '${v['views'] ?? 0}'),
                  _row(ar ? 'الترتيب' : 'Order', '${v['sequence'] ?? '—'}'),
                  _row(ar ? 'الملف' : 'File', '${v['filename'] ?? '—'}'),
                  _row(ar ? 'تاريخ الإنشاء' : 'Created', '${v['created'] ?? '—'}'),
                ])),

                const SizedBox(height: 16),

                // ── Actions ──
                Row(children: [
                  if (canEdit) Expanded(child: ElevatedButton.icon(onPressed: _edit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(ar ? 'تعديل' : 'Edit'))),
                  if (canEdit) const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(onPressed: () => _request('edit'),
                    icon: const Icon(Icons.rule_folder_outlined, size: 18),
                    label: Text(ar ? 'طلب تعديل' : 'Request edit'))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _request('delete'),
                    icon: const Icon(Icons.assignment_late_outlined, size: 18),
                    label: Text(ar ? 'طلب حذف' : 'Request delete'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(onPressed: _delete,
                    style: OutlinedButton.styleFrom(foregroundColor: UC.danger, side: const BorderSide(color: UC.danger, width: 1.5)),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(ar ? 'حذف' : 'Delete'))),
                ]),
                const SizedBox(height: 24),
              ])),
      ),
    );
  }

  Widget _section(String title, IconData ic, Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: UC.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(ic, size: 17, color: UC.brown), const SizedBox(width: 7), Text(title, style: UT.h3)]),
      const SizedBox(height: 10), child,
    ]));

  Widget _row(String k, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110, child: Text(k, style: UT.small)),
      Expanded(child: Text(val, style: UT.body, textAlign: TextAlign.end)),
    ]));
}

// ─────────────── Video create (full page) ───────────────
class VideoCreateScreen extends StatefulWidget {
  const VideoCreateScreen({super.key});
  @override
  State<VideoCreateScreen> createState() => _VideoCreateScreenState();
}

class _VideoCreateScreenState extends State<VideoCreateScreen> {
  final _title = TextEditingController();
  ProductSummary? _product;
  XFile? _file;
  int _bytes = 0;
  bool _busy = false, _loadingProducts = true;
  List<ProductSummary> _products = [];

  bool get _ar => VendorApi.instance.lang == 'ar';
  String get _lang => _ar ? 'ar' : 'en';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      var p = await VendorApi.instance.products(state: 'approved');
      if (p.isEmpty) p = await VendorApi.instance.products();
      if (!mounted) return;
      setState(() { _products = p; _loadingProducts = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() { _title.dispose(); super.dispose(); }

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<ProductSummary>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _VideoProductPicker(products: _products, lang: _lang, ar: _ar));
    if (picked != null) {
      setState(() {
        _product = picked;
        if (_title.text.trim().isEmpty) _title.text = picked.name.t(_lang);
      });
    }
  }

  Future<void> _pickVideo() async {
    final f = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 90));
    if (f == null) return;
    final b = await f.readAsBytes();
    if (b.length > 80 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_ar ? 'الفيديو أكبر من 80 ميجا' : 'Video exceeds 80 MB')));
      return;
    }
    setState(() { _file = f; _bytes = b.length; });
  }

  Future<void> _upload() async {
    final ar = _ar;
    if (_product == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'اختر المنتج' : 'Pick a product'))); return;
    }
    if (_file == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'اختر الفيديو' : 'Pick a video'))); return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await _file!.readAsBytes();
      final title = _title.text.trim().isEmpty ? _product!.name.t(_lang) : _title.text.trim();
      final res = await VendorApi.instance.videoCreate(
        _product!.id, title, base64Encode(bytes), _file!.name);
      if (!mounted) return;
      final err = res['upload_error'];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err != null
          ? (ar ? 'حُفظ لكن فشل الرفع: $err' : 'Saved but upload failed: $err')
          : (ar ? 'تم الرفع — جاري المعالجة' : 'Uploaded — processing'))));
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
    final mb = (_bytes / 1024 / 1024);
    return Scaffold(
      backgroundColor: UC.bg,
      appBar: AppBar(title: Text(ar ? 'فيديو جديد' : 'New video')),
      body: _loadingProducts ? const Center(child: USpinner()) : ListView(padding: const EdgeInsets.all(14), children: [
        _card(ar ? 'المنتج' : 'Product', Icons.shopping_bag_outlined, [
          InkWell(onTap: _pickProduct, borderRadius: BorderRadius.circular(11),
            child: Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: UC.bg, border: Border.all(color: UC.border),
                borderRadius: BorderRadius.circular(11)),
              child: _product == null
                ? Row(children: [
                    const Icon(Icons.add, color: UC.brown), const SizedBox(width: 8),
                    Text(ar ? 'اختر المنتج (بحث)' : 'Select product (search)',
                      style: const TextStyle(color: UC.muted, fontWeight: FontWeight.w700)),
                  ])
                : Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: _product!.imageUrl != null
                        ? Image.network('${VendorApi.instance.baseUrl}${_product!.imageUrl}', width: 42, height: 42, fit: BoxFit.cover,
                            errorBuilder: (_,__,___) => Container(width: 42, height: 42, color: UC.border, child: const Icon(Icons.image, size: 18, color: UC.muted)))
                        : Container(width: 42, height: 42, color: UC.border, child: const Icon(Icons.image, size: 18, color: UC.muted))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_product!.name.t(_lang), maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800))),
                    const Icon(Icons.swap_horiz, color: UC.muted),
                  ]))),
        ]),
        _card(ar ? 'العنوان' : 'Title', Icons.title, [
          TextField(controller: _title,
            decoration: InputDecoration(hintText: ar ? 'عنوان الفيديو' : 'Video title')),
        ]),
        _card(ar ? 'الفيديو' : 'Video', Icons.movie_outlined, [
          if (_file == null)
            OutlinedButton.icon(onPressed: _pickVideo,
              icon: const Icon(Icons.video_library_outlined, size: 18),
              label: Text(ar ? 'اختر فيديو من المعرض' : 'Pick video from gallery'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)))
          else Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: UC.successBg, borderRadius: BorderRadius.circular(11)),
            child: Row(children: [
              const Icon(Icons.check_circle, color: UC.successDk, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_file!.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                Text('${mb.toStringAsFixed(1)} MB', style: UT.small),
              ])),
              TextButton(onPressed: _pickVideo, child: Text(ar ? 'تغيير' : 'Change')),
            ])),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.info_outline, size: 14, color: UC.muted),
            const SizedBox(width: 6),
            Expanded(child: Text(ar ? 'حتى ٩٠ ثانية · بحد أقصى ٨٠ ميجا · عمودي يُفضّل'
                                    : 'Up to 90s · max 80 MB · vertical preferred', style: UT.small)),
          ]),
        ]),
        const SizedBox(height: 6),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _busy ? null : _upload,
          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
            : const Icon(Icons.cloud_upload_outlined, size: 18),
          label: Text(_busy ? (ar ? 'جاري الرفع…' : 'Uploading…') : (ar ? 'رفع الفيديو' : 'Upload video'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)))),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _card(String title, IconData ic, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: UC.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(ic, size: 17, color: UC.brown), const SizedBox(width: 7), Text(title, style: UT.h3)]),
      const SizedBox(height: 10), ...children,
    ]));
}

class _VideoProductPicker extends StatefulWidget {
  final List<ProductSummary> products;
  final String lang;
  final bool ar;
  const _VideoProductPicker({required this.products, required this.lang, required this.ar});
  @override
  State<_VideoProductPicker> createState() => _VideoProductPickerState();
}

class _VideoProductPickerState extends State<_VideoProductPicker> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = widget.products.where((p) => q.isEmpty
      || p.name.en.toLowerCase().contains(q) || p.name.ar.toLowerCase().contains(q)).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(height: MediaQuery.of(context).size.height * .75, child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: UC.border, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.all(14),
          child: TextField(autofocus: true,
            decoration: InputDecoration(hintText: widget.ar ? 'ابحث عن منتج' : 'Search products',
              prefixIcon: const Icon(Icons.search)),
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
