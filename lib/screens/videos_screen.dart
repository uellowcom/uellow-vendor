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
  bool _uploading = false;
  String? _error;
  List<Map<String, dynamic>> _videos = [];

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
      final v = await VendorApi.instance.videos();
      if (!mounted) return;
      setState(() {
        _videos = v;
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

  Future<void> _add() async {
    // 1) pick a product
    List<ProductSummary> prods;
    try {
      prods = await VendorApi.instance.products(state: 'approved');
      if (prods.isEmpty) prods = await VendorApi.instance.products();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!mounted) return;
    if (prods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_ar ? 'لا توجد منتجات' : 'No products')));
      return;
    }
    final lang = _ar ? 'ar' : 'en';
    ProductSummary? selected = prods.first;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: Text(_ar ? 'اختر المنتج' : 'Pick a product'),
        content: DropdownButton<ProductSummary>(
          isExpanded: true,
          value: selected,
          items: [for (final p in prods) DropdownMenuItem(value: p, child: Text(p.name.t(lang), overflow: TextOverflow.ellipsis))],
          onChanged: (p) => setS(() => selected = p),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_ar ? 'إلغاء' : 'Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_ar ? 'اختر فيديو' : 'Pick video')),
        ],
      )),
    );
    if (go != true || selected == null) return;
    // 2) pick a video file
    final XFile? file = await ImagePicker().pickVideo(
        source: ImageSource.gallery, maxDuration: const Duration(seconds: 90));
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 80 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_ar ? 'الفيديو أكبر من 80 ميجا' : 'Video exceeds 80 MB')));
      return;
    }
    setState(() => _uploading = true);
    try {
      final res = await VendorApi.instance.videoCreate(
          selected!.id, selected!.name.t(lang), base64Encode(bytes), file.name);
      if (!mounted) return;
      final err = res['upload_error'];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err != null
            ? (_ar ? 'حُفظ لكن فشل الرفع: $err' : 'Saved but upload failed: $err')
            : (_ar ? 'تم الرفع — جاري المعالجة' : 'Uploaded — processing')),
      ));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(_ar ? 'حذف هذا الفيديو؟' : 'Delete this video?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_ar ? 'لا' : 'No')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_ar ? 'نعم' : 'Yes')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await VendorApi.instance.videoDelete(id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_ar ? 'فيديوهات المنتجات' : 'Shoppable videos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _add,
        icon: _uploading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: UC.brown))
            : const Icon(Icons.video_call),
        label: Text(_ar ? 'فيديو جديد' : 'New video'),
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
                            ? 'ارفع مقطعاً قصيراً (حتى 90 ثانية) لإبراز منتجك. يُعرض على صفحة المنتج وفي التطبيق.'
                            : 'Upload a short clip (up to 90s) to showcase your product. Plays on the product page and in the app.',
                        style: UT.body,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_videos.isEmpty)
                      Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(_ar ? 'لا توجد فيديوهات' : 'No videos yet', style: UT.small))),
                    for (final v in _videos)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: UC.border)),
                        child: ListTile(
                          leading: ('${v['thumb_url'] ?? ''}'.isNotEmpty)
                              ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network('${v['thumb_url']}', width: 54, height: 54, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie, color: UC.brown)))
                              : const Icon(Icons.movie, color: UC.brown, size: 40),
                          title: Text('${v['title']}', style: const TextStyle(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${v['product']} · ${v['status'].toString().isEmpty ? (_ar ? 'بانتظار' : 'pending') : v['status']}${v['duration'].toString().isNotEmpty ? ' · ${v['duration']}' : ''}', style: UT.small),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: UC.dangerDk, size: 20), onPressed: () => _delete(v['id'] as int)),
                        ),
                      ),
                  ]),
                ),
    );
  }
}
