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
    _f = VendorApi.instance.products(state: 'live');
  }

  Future<void> _refresh() async {
    setState(() => _f = VendorApi.instance.products(
        state: 'live', search: _q.isEmpty ? null : _q));
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
          // ── Store hero header (banner + scrim + overlapping logo) ──
          SliverToBoxAdapter(
            child: _hero(v, lang, ar, base),
          ),
          // ── Stat pills + preview note + search ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 44, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 7, runSpacing: 7, children: [
                  UPill(
                      text: (v?.avgRating ?? 0).toStringAsFixed(2),
                      icon: Icons.star_rounded,
                      bg: UC.warnBg, fg: const Color(0xFF92400E)),
                  UPill(
                      text: '${v?.followerCount ?? 0} ${ar ? "متابع" : "followers"}',
                      icon: Icons.people_alt_rounded,
                      bg: UC.bg, fg: UC.text),
                  UPill(
                      text: (v?.tier ?? '').toUpperCase(),
                      icon: Icons.workspace_premium_rounded,
                      bg: UC.yellowFaint, fg: UC.brown),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                    color: UC.infoBg,
                    borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.visibility_rounded, size: 15, color: UC.info),
                    const SizedBox(width: 7),
                    Expanded(child: Text(
                      ar ? 'هكذا يرى العملاء متجرك' : 'This is how customers see your shop',
                      style: const TextStyle(fontSize: 11.5, color: UC.info, fontWeight: FontWeight.w800))),
                  ]),
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: UC.border)),
                    child: TextField(
                      decoration: InputDecoration(
                        filled: false,
                        hintText: ar ? 'ابحث في متجرك' : 'Search your shop',
                        prefixIcon: const Icon(Icons.search_rounded, size: 21, color: UC.muted),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14)),
                      onSubmitted: (s) { _q = s.trim(); _refresh(); },
                    ),
                  ),
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

  Widget _hero(Vendor? v, String lang, bool ar, String base) {
    final name = v?.storeName.t(lang) ?? '';
    final tagline = v?.tagline.t(lang) ?? '';
    return Stack(clipBehavior: Clip.none, children: [
      // banner
      SizedBox(
        height: 188,
        width: double.infinity,
        child: v?.bannerUrl != null
            ? CachedNetworkImage(
                imageUrl: '$base${v!.bannerUrl!}',
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _bannerFallback())
            : _bannerFallback(),
      ),
      // gradient scrim for legibility
      Positioned.fill(
        bottom: 0,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x14000000), Color(0xB3000000)],
              stops: [0.35, 0.6, 1.0]))),
      ),
      // store name + tagline over the scrim
      Positioned(
        left: 16, right: 16, bottom: 16,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900,
                      height: 1.1, letterSpacing: -0.2,
                      shadows: [Shadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 1))])),
              if (tagline.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(tagline,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xF2FFFFFF), fontSize: 12.5, fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Color(0x59000000), blurRadius: 4, offset: Offset(0, 1))])),
              ],
            ],
          ),
        ),
      ),
      // overlapping logo
      PositionedDirectional(
        start: 16, bottom: -34,
        child: Container(
          width: 78, height: 78,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x40000000),
                blurRadius: 14, offset: Offset(0, 6))]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: v?.logoUrl != null
                ? CachedNetworkImage(
                    imageUrl: '$base${v!.logoUrl!}',
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _logoFallback(name))
                : _logoFallback(name.isEmpty ? 'U' : name)),
        ),
      ),
    ]);
  }

  Widget _bannerFallback() => Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [UC.brown, UC.brownSoft, UC.yellow],
          begin: Alignment.topLeft, end: Alignment.bottomRight)));

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
                if (!p.inStock)
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
