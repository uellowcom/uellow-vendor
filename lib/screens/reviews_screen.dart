import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  Future<List<Review>>? _f;
  @override
  void initState() { super.initState(); _f = VendorApi.instance.reviews(); }
  Future<void> _refresh() async {
    setState(() => _f = VendorApi.instance.reviews()); await _f;
  }

  Future<void> _reply(Review r) async {
    final ar = VendorApi.instance.lang == 'ar';
    final c = TextEditingController(text: r.reply);
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: Text(ar ? 'الرد على التقييم' : 'Reply to review'),
      content: TextField(controller: c, minLines: 2, maxLines: 5,
        decoration: InputDecoration(labelText: ar ? 'الرد' : 'Your reply')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false),
          child: Text(ar ? 'إلغاء' : 'Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true),
          child: Text(ar ? 'إرسال' : 'Send')),
      ]));
    if (ok != true || c.text.trim().isEmpty) return;
    try {
      await VendorApi.instance.reviewReply(r.id, c.text.trim());
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'تقييمات العملاء' : 'Customer reviews')),
      body: RefreshIndicator(onRefresh: _refresh,
        child: FutureBuilder<List<Review>>(future: _f, builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: USpinner());
          if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(snap.error.toString(), style: UT.body, textAlign: TextAlign.center)));
          final rows = snap.data ?? const <Review>[];
          if (rows.isEmpty) return Padding(padding: const EdgeInsets.all(40),
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.reviews_outlined, size: 48, color: UC.muted),
              const SizedBox(height: 12),
              Text(ar ? 'لا توجد تقييمات بعد' : 'No reviews yet', style: UT.body),
            ])));
          return ListView.separated(padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _card(rows[i]));
        })),
    );
  }

  Widget _card(Review r) {
    final ar = VendorApi.instance.lang == 'ar';
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(13),
      child: Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: UC.border),
          borderRadius: BorderRadius.circular(13)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 16, backgroundColor: UC.yellowFaint,
              backgroundImage: (r.author?['avatar_url'] as String?) != null
                ? CachedNetworkImageProvider('${VendorApi.instance.baseUrl}${r.author!['avatar_url']}')
                : null,
              child: (r.author?['avatar_url'] as String?) == null
                ? Text(((r.author?['name'] ?? '?').toString()).substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: UC.brown, fontWeight: FontWeight.w900, fontSize: 12))
                : null),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((r.author?['name'] ?? 'Anonymous').toString(),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              if (r.product != null) Text((r.product!['name'] ?? '').toString(),
                style: UT.small, maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            Row(children: [
              for (var i = 0; i < 5; i++)
                Icon(i < r.rating.round() ? Icons.star : Icons.star_border,
                  size: 14, color: UC.warn),
            ]),
          ]),
          const SizedBox(height: 8),
          Text(r.comment.isNotEmpty ? r.comment : (ar ? 'لا يوجد تعليق' : '(no comment)'),
            style: const TextStyle(fontSize: 12.5, height: 1.4)),
          if (r.reply.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8),
            child: Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: UC.yellowFaint,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: UC.yellow)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.reply, color: UC.brown, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(r.reply, style: const TextStyle(
                  fontSize: 12, color: UC.brown, fontWeight: FontWeight.w700))),
              ]))),
          const SizedBox(height: 8),
          Align(alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(onPressed: () => _reply(r),
              icon: const Icon(Icons.reply, size: 14),
              label: Text(r.reply.isEmpty
                ? (ar ? 'رد' : 'Reply')
                : (ar ? 'تعديل الرد' : 'Edit reply')))),
        ])));
  }
}
