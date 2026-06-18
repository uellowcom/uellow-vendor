import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Storefront preview — shows the vendor how customers see their shop:
/// the store header + the live (published) catalogue as customer-style cards.
class ShopTab extends StatefulWidget {
  const ShopTab({super.key});
  @override
  State<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<ShopTab> {
  Future<List<ProductSummary>>? _f;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _f = VendorApi.instance.products(state: 'published');
  }

  Future<void> _refresh() async {
    setState(() => _f = VendorApi.instance.products(
        state: 'published', search: _q.isEmpty ? null : _q));
    await _f;
  }

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    final v = VendorApi.instance.vendor;
    final base = VendorApi.instance.baseUrl;
    return Scaffold(
      backgroundColor: UC.bg,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(slivers: [
          // ── Store header (banner + logo overlap) ──
          SliverToBoxAdapter(
            child: Stack(clipBehavior: Clip.none, children: [
              SizedBox(
                height: 140,
                width: double.infinity,
                child: v?.bannerUrl != null
                    ? CachedNetworkImage(
                        imageUrl: '$base${v!.bannerUrl!}',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: UC.yellow))
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [UC.yellow, UC.yellowSoft],
                            begin: Alignment.topLeft, end: Alignment.bottomRight))),
              ),
              Positioned(
                left: 16, bottom: -28,
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Color(0x33000000),
                        blurRadius: 10, offset: Offset(0, 4))]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: v?.logoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: '$base${v!.logoUrl!}',
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _logoFallback(v.storeName.t(lang)))
                        : _logoFallback(v?.storeName.t(lang) ?? 'U')),
                ),
              ),
            ]),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 36, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v?.storeName.t(lang) ?? '', style: UT.h1),
                if ((v?.tagline.t(lang) ?? '').isNotEmpty)
                  Text(v!.tagline.t(lang), style: UT.body),
                const SizedBox(height: 8),
                Row(children: [
                  UPill(text: '⭐ ${(v?.avgRating ?? 0).toStringAsFixed(2)}',
                      bg: UC.warnBg, fg: const Color(0xFF92400E)),
                  const SizedBox(width: 6),
                  UPill(text: '${v?.followerCount ?? 0} ${ar ? "متابع" : "followers"}'),
                  const SizedBox(width: 6),
                  UPill(text: (v?.tier ?? '').toUpperCase(),
                      bg: UC.yellowFaint, fg: UC.brown),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: UC.infoBg, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.visibility, size: 14, color: UC.info),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      ar ? 'هكذا يرى العملاء متجرك' : 'This is how customers see your shop',
                      style: const TextStyle(fontSize: 11, color: UC.info, fontWeight: FontWeight.w700))),
                  ]),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: ar ? 'ابحث في متجرك' : 'Search your shop',
                    prefixIcon: const Icon(Icons.search, size: 20)),
                  onSubmitted: (s) { _q = s.trim(); _refresh(); },
                ),
              ]),
            ),
          ),
          // ── Live catalogue grid ──
          FutureBuilder<List<ProductSummary>>(
            future: _f,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SliverToBoxAdapter(
                    child: Padding(padding: EdgeInsets.all(40), child: USpinner()));
              }
              if (snap.hasError) {
                return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(30),
                    child: Text(snap.error.toString(), textAlign: TextAlign.center, style: UT.body)));
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
                  child: Column(children: [
                    const Icon(Icons.storefront_outlined, size: 44, color: UC.muted),
                    const SizedBox(height: 10),
                    Text(ar ? 'لا توجد منتجات منشورة بعد' : 'No published products yet',
                        style: UT.body, textAlign: TextAlign.center),
                  ])));
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
                    childAspectRatio: .66),
                  delegate: SliverChildBuilderDelegate(
                    (c, i) => _card(items[i], lang, base),
                    childCount: items.length),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }

  Widget _card(ProductSummary p, String lang, String base) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pushNamed(context, '/product', arguments: {'id': p.id}),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: UC.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: AspectRatio(
                aspectRatio: 1,
                child: p.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: '$base${p.imageUrl}',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(color: UC.bg,
                            child: const Icon(Icons.image, color: UC.muted)))
                    : Container(color: UC.bg, child: const Icon(Icons.image, color: UC.muted)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(9),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name.t(lang),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, height: 1.25)),
                const SizedBox(height: 6),
                Text(p.listPrice.format(lang),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: UC.brown)),
                if (p.qty <= 0)
                  Padding(padding: const EdgeInsets.only(top: 4),
                    child: Text(lang == 'ar' ? 'غير متوفر' : 'Out of stock',
                        style: const TextStyle(fontSize: 10, color: UC.dangerDk, fontWeight: FontWeight.w800))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _logoFallback(String name) => Container(
      color: UC.yellow, alignment: Alignment.center,
      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(color: UC.brown, fontSize: 26, fontWeight: FontWeight.w900)));
}
