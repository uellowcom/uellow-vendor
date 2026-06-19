import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// Storefront preview — shows the vendor how customers see their shop:
/// the store header + the live (published) catalogue as customer-style cards,
/// with category filtering, an active-promotions block and infinite scroll.
class ShopTab extends StatefulWidget {
  const ShopTab({super.key});
  @override
  State<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<ShopTab> {
  static const int _pageSize = 20;

  final ScrollController _scroll = ScrollController();
  final List<ProductSummary> _items = [];

  String _q = '';
  int? _categoryId;            // null = All
  int _page = 1;
  bool _loading = false;       // a page fetch is in flight
  bool _hasMore = true;        // more pages available
  bool _firstLoadDone = false; // first page resolved (success or empty)
  String? _error;

  // shop meta (loaded once)
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _promotions = const [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadMeta();
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 400) {
      _loadNextPage();
    }
  }

  Future<void> _loadMeta() async {
    try {
      final m = await VendorApi.instance.shopMeta();
      if (!mounted) return;
      setState(() {
        _categories = ((m['categories'] as List?) ?? const [])
            .cast<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        _promotions = ((m['promotions'] as List?) ?? const [])
            .cast<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      });
    } catch (_) {
      // fail silently; the product grid still works without meta
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _items.clear();
      _page = 1;
      _hasMore = true;
      _firstLoadDone = false;
      _error = null;
    });
    await _fetchPage(1);
  }

  Future<void> _loadNextPage() async {
    if (_loading || !_hasMore || !_firstLoadDone) return;
    await _fetchPage(_page + 1);
  }

  Future<void> _fetchPage(int page) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final batch = await VendorApi.instance.products(
        state: 'live',
        search: _q.isEmpty ? null : _q,
        categoryId: _categoryId,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        _page = page;
        _items.addAll(batch);
        _hasMore = batch.length >= _pageSize;
        _firstLoadDone = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _firstLoadDone = true;
        _hasMore = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await _loadMeta();
    await _loadFirstPage();
  }

  void _selectCategory(int? id) {
    if (_categoryId == id) return;
    setState(() => _categoryId = id);
    _loadFirstPage();
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
        child: CustomScrollView(controller: _scroll, slivers: [
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
                      onSubmitted: (s) { _q = s.trim(); _loadFirstPage(); },
                    ),
                  ),
                ),
              ]),
            ),
          ),
          // ── Category chips bar ──
          if (_categories.isNotEmpty)
            SliverToBoxAdapter(child: _categoryBar(lang, ar)),
          // ── Promotions block ──
          if (_promotions.isNotEmpty)
            SliverToBoxAdapter(child: _promotionsBlock(lang, ar)),
          // ── Live catalogue grid ──
          ..._buildGridSlivers(lang, ar, base),
          // ── Loading / end footer ──
          SliverToBoxAdapter(child: _footer(ar)),
        ]),
      ),
    );
  }

  // ── Grid slivers (loading / error / empty / grid) ──
  List<Widget> _buildGridSlivers(String lang, bool ar, String base) {
    if (!_firstLoadDone) {
      return const [
        SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.all(40), child: USpinner())),
      ];
    }
    if (_error != null && _items.isEmpty) {
      return [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(30),
            child: Text(_error!, textAlign: TextAlign.center, style: UT.body))),
      ];
    }
    if (_items.isEmpty) {
      return [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
          child: Column(children: [
            const Icon(Icons.storefront_outlined, size: 44, color: UC.muted),
            const SizedBox(height: 10),
            Text(ar ? 'لا توجد منتجات منشورة بعد' : 'No published products yet',
                style: UT.body, textAlign: TextAlign.center),
          ]))),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
            childAspectRatio: .66),
          delegate: SliverChildBuilderDelegate(
            (c, i) => _card(_items[i], lang, base),
            childCount: _items.length),
        ),
      ),
    ];
  }

  Widget _footer(bool ar) {
    if (_loading && _items.isNotEmpty) {
      return const Padding(
          padding: EdgeInsets.fromLTRB(0, 6, 0, 28), child: USpinner(size: 22));
    }
    if (!_hasMore && _items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
        child: Center(child: Text(
            ar ? 'وصلت إلى نهاية القائمة' : 'You\'ve reached the end',
            style: UT.tiny)),
      );
    }
    return const SizedBox(height: 28);
  }

  // ── Category chips bar ──
  Widget _categoryBar(String lang, bool ar) {
    final chips = <Widget>[];
    chips.add(_catChip(label: ar ? 'الكل' : 'All', count: null,
        selected: _categoryId == null, onTap: () => _selectCategory(null)));
    for (final c in _categories) {
      final id = (c['id'] as num?)?.toInt();
      if (id == null) continue;
      final nameMap = (c['name'] as Map?)?.cast<String, dynamic>() ?? const {};
      final name = (nameMap[lang] ?? nameMap['en'] ?? nameMap['ar'] ?? '').toString();
      final count = (c['count'] as num?)?.toInt();
      chips.add(_catChip(label: name, count: count,
          selected: _categoryId == id, onTap: () => _selectCategory(id)));
    }
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _catChip({required String label, int? count,
      required bool selected, required VoidCallback onTap}) {
    return Material(
      color: selected ? UC.brown : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? UC.brown : UC.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : UC.text)),
            if (count != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? const Color(0x33FFFFFF) : UC.bg,
                  borderRadius: BorderRadius.circular(999)),
                child: Text('$count',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : UC.muted)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // ── Promotions block ──
  Widget _promotionsBlock(String lang, bool ar) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_fire_department_rounded, size: 18, color: UC.danger),
          const SizedBox(width: 6),
          Text(ar ? 'العروض النشطة' : 'Active promotions', style: UT.h3),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _promotions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _promoCard(_promotions[i], lang, ar),
          ),
        ),
      ]),
    );
  }

  Widget _promoCard(Map<String, dynamic> p, String lang, bool ar) {
    final nameMap = (p['name'] as Map?)?.cast<String, dynamic>() ?? const {};
    final name = (nameMap[lang] ?? nameMap['en'] ?? nameMap['ar'] ?? '').toString();
    final disc = (p['discount_pct'] as num?)?.toDouble() ?? 0;
    final pCount = (p['product_count'] as num?)?.toInt() ?? 0;
    final remaining = (p['remaining_seconds'] as num?)?.toInt() ?? 0;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [UC.brown, UC.brownSoft],
          begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (disc > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: UC.yellow, borderRadius: BorderRadius.circular(999)),
              child: Text('-${disc.toStringAsFixed(disc % 1 == 0 ? 0 : 1)}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                      color: UC.brown)),
            ),
          const Spacer(),
          if (remaining > 0)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.timer_outlined, size: 13, color: Color(0xF2FFFFFF)),
              const SizedBox(width: 3),
              Text(_fmtCountdown(remaining, ar),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                      color: Color(0xF2FFFFFF))),
            ]),
        ]),
        const Spacer(),
        Text(name,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900,
                color: Colors.white, height: 1.2)),
        const SizedBox(height: 5),
        Text(
            ar ? '$pCount منتج' : '$pCount ${pCount == 1 ? "product" : "products"}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: Color(0xCCFFFFFF))),
      ]),
    );
  }

  String _fmtCountdown(int seconds, bool ar) {
    if (seconds <= 0) return ar ? 'انتهى' : 'ended';
    final d = seconds ~/ 86400;
    final h = (seconds % 86400) ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (d > 0) return ar ? '$d ي $h س' : '${d}d ${h}h';
    if (h > 0) return ar ? '$h س $m د' : '${h}h ${m}m';
    return ar ? '$m د' : '${m}m';
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
