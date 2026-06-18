import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

/// A single grid entry. [show] lets us hide entries by vendor type / role.
class _Item {
  final IconData icon;
  final String en, ar, route;
  final Color color;
  final bool Function()? show;
  const _Item(this.icon, this.en, this.ar, this.route, this.color, {this.show});
}

class MeTab extends StatefulWidget {
  const MeTab({super.key});
  @override
  State<MeTab> createState() => _MeTabState();
}

class _MeTabState extends State<MeTab> {
  Future<Dashboard>? _f;
  @override
  void initState() {
    super.initState();
    _f = VendorApi.instance.dashboard();
  }

  Future<void> _refresh() async {
    setState(() => _f = VendorApi.instance.dashboard());
    await _f;
  }

  bool get _isFbuOrConsign =>
      VendorApi.instance.vendorType == 'fbu' ||
      VendorApi.instance.vendorType == 'consignment';

  List<_Item> _items(bool ar) => [
        _Item(Icons.local_shipping_outlined, 'Order hub', 'مركز الطلبات', '/order-hub', UC.info),
        _Item(Icons.bolt_outlined, 'Promotions', 'العروض الداخلية', '/flash', UC.warn),
        _Item(Icons.local_offer_outlined, 'Campaigns', 'الحملات', '/promotions', UC.success),
        _Item(Icons.videocam_outlined, 'Videos', 'فيديوهات', '/videos', const Color(0xFFEC4899)),
        _Item(Icons.qr_code_scanner, 'Scan', 'مسح باركود', '/scan', UC.brown),
        _Item(Icons.point_of_sale_outlined, 'Quick sale', 'بيع سريع', '/quick-sale', const Color(0xFF6366F1)),
        _Item(Icons.campaign_outlined, 'Sponsor', 'إعلانات ممولة', '/ads', const Color(0xFFF97316)),
        _Item(Icons.report_problem_outlined, 'Order issues', 'مشاكل الطلبات', '/disputes', UC.danger),
        _Item(Icons.inventory_2_outlined, 'Stock', 'المخزون', '/stock', UC.successDk),
        _Item(Icons.refresh, 'Restock', 'طلبات التعبئة', '/restock', const Color(0xFF0EA5E9)),
        _Item(Icons.upload_file_outlined, 'Bulk import', 'استيراد جماعي', '/import', const Color(0xFF8B5CF6)),
        _Item(Icons.assignment_return_outlined, 'Stock returns', 'استرجاع بضاعة', '/returns', const Color(0xFFD97706),
            show: () => _isFbuOrConsign),
        _Item(Icons.sell_outlined, 'Price requests', 'طلبات الأسعار', '/price-requests', const Color(0xFF14B8A6)),
        _Item(Icons.palette_outlined, 'Store style', 'تصميم المتجر', '/style', const Color(0xFFA855F7)),
        _Item(Icons.reviews_outlined, 'Reviews', 'التقييمات', '/reviews', UC.warn),
        _Item(Icons.bar_chart, 'Analytics', 'التحليلات', '/analytics', UC.info),
        _Item(Icons.table_view_outlined, 'Reports', 'التقارير', '/reports', UC.brownSoft),
        _Item(Icons.person_outline, 'Profile', 'ملف التاجر', '/profile', UC.muted),
        _Item(Icons.code, 'Developer', 'المطورون / API', '/developer', const Color(0xFF475569)),
        _Item(Icons.settings_outlined, 'Settings', 'الإعدادات', '/settings', UC.brown),
        _Item(Icons.shield_outlined, 'Admin', 'وضع الأدمن', '/admin', UC.dangerDk,
            show: () => VendorApi.instance.isAdmin),
      ];

  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    final v = VendorApi.instance.vendor;
    final items = _items(ar).where((i) => i.show?.call() ?? true).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(v?.storeName.t(lang) ?? (ar ? 'متجري' : 'My store'),
            style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: UC.dangerDk),
            tooltip: ar ? 'تسجيل الخروج' : 'Sign out',
            onPressed: () async {
              await VendorApi.instance.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 28), children: [
          // ── Stats strip (wallet / products / orders) ──
          FutureBuilder<Dashboard>(
            future: _f,
            builder: (_, snap) {
              final d = snap.data;
              final wallet = d?.walletBalance.format(lang) ??
                  (v != null ? Money(amount: v.walletBalance, currency: v.currency,
                      symbol: v.currencySymbol, digits: 3).format(lang) : '—');
              final products = d != null ? '${d.productsActive}' : '—';
              final orders = d != null
                  ? '${d.ordersNew + d.ordersConfirmed + d.ordersCompleted}'
                  : '${v?.orderCount ?? 0}';
              return Row(children: [
                _stat(ar ? 'المحفظة' : 'Wallet', wallet, Icons.account_balance_wallet,
                    UC.brown, UC.yellowFaint, onTap: () => Navigator.pushNamed(context, '/wallet')),
                const SizedBox(width: 8),
                _stat(ar ? 'المنتجات' : 'Products', products, Icons.shopping_bag,
                    UC.successDk, UC.successBg),
                const SizedBox(width: 8),
                _stat(ar ? 'الطلبات' : 'Orders', orders, Icons.receipt_long,
                    UC.info, UC.infoBg, onTap: () => Navigator.pushNamed(context, '/order-hub')),
              ]);
            },
          ),
          const SizedBox(height: 18),
          Text(ar ? 'الأقسام' : 'Sections', style: UT.h3),
          const SizedBox(height: 10),
          // ── Big-icon grid ──
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10,
              childAspectRatio: .92),
            itemBuilder: (c, i) => _gridTile(items[i], ar),
          ),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value, IconData ic, Color fg, Color bg,
      {VoidCallback? onTap}) {
    return Expanded(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(ic, color: fg, size: 18),
              const SizedBox(height: 8),
              Text(value,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w900)),
              Text(label,
                  style: TextStyle(color: fg.withValues(alpha: .75), fontSize: 10.5,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _gridTile(_Item it, bool ar) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pushNamed(context, it.route),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: UC.border)),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 50, height: 50, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: it.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(15)),
              child: Icon(it.icon, color: it.color, size: 26),
            ),
            const SizedBox(height: 9),
            Text(ar ? it.ar : it.en,
                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: UC.ink)),
          ]),
        ),
      ),
    );
  }
}
