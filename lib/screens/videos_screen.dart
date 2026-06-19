import 'dart:convert';
import 'package:flutter/material.dart';
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

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      content: Text(_ar ? 'حذف هذا الفيديو؟' : 'Delete this video?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_ar ? 'لا' : 'No')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_ar ? 'نعم' : 'Yes')),
      ]));
    if (ok != true) return;
    try { await VendorApi.instance.videoDelete(id); _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Color _statusColor(String s) {
    final l = s.toLowerCase();
    if (l.contains('finish') || l.contains('ready') || l == '4') return UC.successDk;
    if (l.contains('error') || l.contains('fail')) return UC.dangerDk;
    if (l.isEmpty) return UC.muted;
    return UC.warn;
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
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Stack(fit: StackFit.expand, children: [
          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: thumb.isNotEmpty
              ? Image.network(thumb, fit: BoxFit.cover,
                  errorBuilder: (_,__,___) => Container(color: UC.bg, child: const Icon(Icons.movie, color: UC.muted, size: 36)))
              : Container(color: UC.bg, child: const Center(child: Icon(Icons.movie, color: UC.muted, size: 36)))),
          const Center(child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 38)),
          if ('${v['duration'] ?? ''}'.isNotEmpty) Positioned(right: 6, bottom: 6,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: Text('${v['duration']}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)))),
          Positioned(left: 6, top: 6, child: Material(color: Colors.black45, shape: const CircleBorder(),
            child: InkWell(customBorder: const CircleBorder(),
              onTap: () => _delete(v['id'] as int),
              child: const Padding(padding: EdgeInsets.all(5), child: Icon(Icons.delete_outline, color: Colors.white, size: 16))))),
        ])),
        Padding(padding: const EdgeInsets.all(9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${v['title'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            Text('${v['product'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: UT.small),
            const SizedBox(height: 5),
            Row(children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Expanded(child: Text(status.isEmpty ? (ar ? 'بانتظار المعالجة' : 'processing') : status,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: _statusColor(status), fontWeight: FontWeight.w700))),
              if ((v['views'] ?? 0) != 0) Text('${v['views']} 👁', style: UT.tiny),
            ]),
          ])),
      ]),
    );
  }
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
