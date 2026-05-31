import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../api/api.dart';
import '../theme/theme.dart';

class MeTab extends StatelessWidget {
  const MeTab({super.key});
  @override
  Widget build(BuildContext context) {
    final ar = VendorApi.instance.lang == 'ar';
    final lang = ar ? 'ar' : 'en';
    final v = VendorApi.instance.vendor;
    return Scaffold(
      appBar: AppBar(title: Text(ar ? 'متجري' : 'My store')),
      body: ListView(padding: EdgeInsets.zero, children: [
        // Banner + logo overlap
        Stack(clipBehavior: Clip.none, children: [
          SizedBox(height: 130, child: v?.bannerUrl != null
            ? CachedNetworkImage(
                imageUrl: '${VendorApi.instance.baseUrl}${v!.bannerUrl!}',
                width: double.infinity, fit: BoxFit.cover,
                errorWidget: (_,__,___) => Container(color: UC.yellow))
            : Container(color: UC.yellow)),
          Positioned(left: 14, bottom: -30, child: Container(width: 76, height: 76,
            decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x33000000),
                blurRadius: 10, offset: Offset(0, 4))]),
            child: ClipRRect(borderRadius: BorderRadius.circular(18),
              child: v?.logoUrl != null
                ? CachedNetworkImage(
                    imageUrl: '${VendorApi.instance.baseUrl}${v!.logoUrl!}',
                    fit: BoxFit.cover,
                    errorWidget: (_,__,___) => _logoFallback(v.storeName.t(lang)))
                : _logoFallback(v?.storeName.t(lang) ?? 'V')))),
        ]),
        const SizedBox(height: 40),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v?.storeName.t(lang) ?? '', style: UT.h1),
            Text(v?.tagline.t(lang) ?? '', style: UT.body),
            const SizedBox(height: 10),
            Row(children: [
              UPill(text: '⭐ ${(v?.avgRating ?? 0).toStringAsFixed(2)}',
                bg: UC.warnBg, fg: const Color(0xFF92400E)),
              const SizedBox(width: 6),
              UPill(text: '${v?.followerCount ?? 0} ${ar ? "متابع" : "followers"}'),
              const SizedBox(width: 6),
              UPill(text: (v?.tier ?? '').toUpperCase(),
                bg: UC.yellowFaint, fg: UC.brown),
            ]),
          ])),
        const SizedBox(height: 14),
        _row(context, Icons.reviews_outlined,
          ar ? 'تقييمات العملاء' : 'Customer reviews',
          ar ? 'كل التقييمات + الرد عليها' : 'All reviews + reply', '/reviews'),
        _row(context, Icons.settings_outlined,
          ar ? 'الإعدادات' : 'Settings',
          ar ? 'بيانات المتجر + اللغة + الإشعارات' : 'Store info + language + notifications',
          '/settings'),
        _row(context, Icons.person_outline,
          ar ? 'ملف التاجر' : 'Vendor profile',
          ar ? 'البيانات التجارية + IBAN' : 'Business info + IBAN', '/profile'),
        _row(context, Icons.bar_chart,
          ar ? 'التحليلات' : 'Analytics',
          ar ? 'المبيعات + أعلى المنتجات' : 'Sales + top products', '/analytics'),
        Padding(padding: const EdgeInsets.all(14),
          child: OutlinedButton.icon(
            onPressed: () async {
              await VendorApi.instance.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              }
            },
            icon: const Icon(Icons.logout, size: 18, color: UC.dangerDk),
            label: Text(ar ? 'تسجيل الخروج' : 'Sign out',
              style: const TextStyle(color: UC.dangerDk, fontWeight: FontWeight.w900)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: UC.dangerBg, width: 1.5),
              minimumSize: const Size(double.infinity, 50)))),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _logoFallback(String name) => Container(color: UC.yellow,
    alignment: Alignment.center,
    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
      style: const TextStyle(color: UC.brown, fontSize: 28, fontWeight: FontWeight.w900)));

  Widget _row(BuildContext c, IconData ic, String title, String sub, String route) =>
    Material(color: Colors.white,
      child: InkWell(onTap: () => Navigator.pushNamed(c, route),
        child: Container(padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: UC.bg))),
          child: Row(children: [
            Container(width: 36, height: 36, alignment: Alignment.center,
              decoration: BoxDecoration(color: UC.yellowFaint,
                borderRadius: BorderRadius.circular(11)),
              child: Icon(ic, color: UC.brown, size: 17)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              Text(sub, style: UT.small, maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            const Icon(Icons.chevron_right, color: UC.muted),
          ]))));
}
