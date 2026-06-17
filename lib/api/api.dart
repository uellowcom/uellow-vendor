// Vendor API client + null-safe models.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kVendorBase = String.fromEnvironment(
  'UELLOW_BASE', defaultValue: 'https://www.uellow.com');

class VendorApi {
  VendorApi._();
  static final VendorApi instance = VendorApi._();

  String baseUrl = kVendorBase;
  String? _token;
  Vendor? _vendor;
  String vendorType = 'seller'; // fbu | seller | dropshipper | hybrid | consignment
  bool isAdmin = false;    // user is a marketplace admin (can enter admin mode)
  bool adminOnly = false;  // logged-in user has no vendor record (pure admin)
  final ValueNotifier<String> langNotifier = ValueNotifier<String>('en');

  String get token => _token ?? '';
  Vendor? get vendor => _vendor;
  String get lang => langNotifier.value;
  void setLang(String c) {
    final n = c.toLowerCase().startsWith('ar') ? 'ar' : 'en';
    if (langNotifier.value != n) langNotifier.value = n;
  }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _token = p.getString('vendor_token_v1');
    isAdmin = p.getBool('vendor_is_admin_v1') ?? false;
    adminOnly = p.getBool('vendor_admin_only_v1') ?? false;
    final lng = p.getString('vendor_lang_v1');
    if (lng != null && lng.isNotEmpty) setLang(lng);
    final cached = p.getString('vendor_me_v1');
    if (cached != null) {
      try { _vendor = Vendor.fromJson(jsonDecode(cached) as Map<String, dynamic>); } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    if (_token != null) await p.setString('vendor_token_v1', _token!);
    else await p.remove('vendor_token_v1');
    await p.setBool('vendor_is_admin_v1', isAdmin);
    await p.setBool('vendor_admin_only_v1', adminOnly);
    await p.setString('vendor_lang_v1', langNotifier.value);
    if (_vendor != null) {
      await p.setString('vendor_me_v1', jsonEncode(_vendor!.toJson()));
    } else {
      await p.remove('vendor_me_v1');
    }
  }

  Map<String, String> _headers({bool json = false}) => {
    'Accept': 'application/json',
    if (json) 'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
    'X-Lang': langNotifier.value,
  };

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final r = await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 25));
    return _decode(r);
  }
  Future<Map<String, dynamic>> _post(String path, [Object? body]) async {
    final r = await http.post(Uri.parse('$baseUrl$path'),
        headers: _headers(json: true),
        body: body != null ? jsonEncode(body) : null).timeout(const Duration(seconds: 30));
    return _decode(r);
  }
  Map<String, dynamic> _decode(http.Response r) {
    try { return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>; }
    catch (e) { throw VendorApiException('Bad response (${r.statusCode})', code: 'BAD_RESPONSE'); }
  }
  Map<String, dynamic> _need(Map<String, dynamic> j) {
    if (j['success'] != true) {
      throw VendorApiException((j['error'] ?? 'Failed').toString(),
          code: (j['code'] ?? 'ERROR').toString());
    }
    return j;
  }

  // Auth

  /// FCM push token → backend (mirrored onto the vendor's partner so the
  /// fleet push engine can target it). No-op when not logged in.
  Future<void> registerPushToken(String deviceId, String token) async {
    if (_token == null || _token!.isEmpty) return;
    try {
      await _post('/api/vendor/v1/me/push-token',
          {'push_token': token, 'device_id': deviceId});
    } catch (_) {}
  }

  Future<void> login(String identifier, String password) async {
    final j = _need(await _post('/api/vendor/v1/auth/login', {
      'login': identifier, 'password': password,
      'platform': 'android', 'app_version': '1.0.0',
    }));
    final d = j['data'] as Map<String, dynamic>;
    _token = d['token'] as String?;
    isAdmin = d['is_admin'] == true;
    if (d['vendor'] != null) {
      _vendor = Vendor.fromJson(d['vendor'] as Map<String, dynamic>);
      adminOnly = false;
      await _persist();
      unawaited(capabilities());
    } else {
      _vendor = null;
      adminOnly = true; // pure admin, no vendor record
      await _persist();
    }
  }
  /// Public vendor-account request (no auth). Submits the application form.
  Future<void> applyVendor(Map<String, String> data) async {
    _need(await _post('/api/vendor/v1/auth/apply', data));
  }

  // ── Price-update requests ─────────────────────────────────────────
  Future<List<Map<String, dynamic>>> priceRequests() async {
    final j = _need(await _get('/api/vendor/v1/price-requests'));
    final data = (j['data']?['requests'] as List?) ?? const [];
    return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> priceRequest(int id) async {
    final j = _need(await _get('/api/vendor/v1/price-requests/$id'));
    return (j['data'] as Map).cast<String, dynamic>();
  }

  /// responses: [{'line_id':1,'action':'match'},
  ///             {'line_id':2,'action':'price','price':9.5},
  ///             {'line_id':3,'action':'oos'}]
  Future<Map<String, dynamic>> respondPriceRequest(
      int id, List<Map<String, dynamic>> responses) async {
    final j = _need(await _post(
        '/api/vendor/v1/price-requests/$id/respond', {'responses': responses}));
    return (j['data']?['summary'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  Future<void> logout() async {
    try { await _post('/api/vendor/v1/auth/logout'); } catch (_) {}
    _token = null; _vendor = null; isAdmin = false; adminOnly = false;
    await _persist();
  }

  // ── Admin mode (marketplace admin) ────────────────────────────────
  Future<Map<String, dynamic>> adminDashboard() async {
    final j = _need(await _get('/api/vendor/v1/admin/dashboard'));
    return (j['data'] as Map).cast<String, dynamic>();
  }
  Future<Map<String, dynamic>> adminOrders({String? state, String? search, int page = 1}) async {
    final j = _need(await _get('/api/vendor/v1/admin/orders', query: {
      if (state != null && state.isNotEmpty) 'state': state,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': '$page',
    }));
    return {'data': (j['data'] as List).cast<dynamic>(), 'meta': j['meta'] ?? {}};
  }
  Future<List<Map<String, dynamic>>> adminVendors({String? search, String? state}) async {
    final j = _need(await _get('/api/vendor/v1/admin/vendors', query: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (state != null && state.isNotEmpty) 'state': state,
    }));
    return ((j['data'] as List).cast<Map>()).map((m) => m.cast<String, dynamic>()).toList();
  }
  Future<Map<String, dynamic>> adminVendor(int id) async {
    final j = _need(await _get('/api/vendor/v1/admin/vendors/$id'));
    return (j['data'] as Map).cast<String, dynamic>();
  }
  Future<Map<String, dynamic>> adminSaveVendorSettings(int id, Map<String, dynamic> body) async {
    final j = _need(await _post('/api/vendor/v1/admin/vendors/$id/settings', body));
    return (j['data'] as Map).cast<String, dynamic>();
  }
  Future<Map<String, dynamic>> adminApprovals() async {
    final j = _need(await _get('/api/vendor/v1/admin/approvals'));
    return (j['data'] as Map).cast<String, dynamic>();
  }
  Future<void> adminDecideChange(int id, String decision, {String reason = ''}) async {
    _need(await _post('/api/vendor/v1/admin/changes/$id/$decision', {'reason': reason}));
  }
  Future<void> adminDecideProduct(int id, String decision, {String reason = ''}) async {
    _need(await _post('/api/vendor/v1/admin/products/$id/$decision', {'reason': reason}));
  }
  Future<Vendor> me() async {
    final j = _need(await _get('/api/vendor/v1/me'));
    _vendor = Vendor.fromJson(((j['data'] as Map)['vendor'] as Map).cast<String, dynamic>());
    await _persist();
    unawaited(capabilities());
    return _vendor!;
  }
  Future<Vendor> updateProfile(Map<String, dynamic> body) async {
    final j = _need(await _post('/api/vendor/v1/settings/profile', body));
    _vendor = Vendor.fromJson(((j['data'] as Map)['vendor'] as Map).cast<String, dynamic>());
    await _persist();
    return _vendor!;
  }

  // Dashboard
  Future<Dashboard> dashboard() async {
    final j = _need(await _get('/api/vendor/v1/dashboard'));
    return Dashboard.fromJson((j['data'] as Map).cast<String, dynamic>());
  }

  // Orders
  Future<List<OrderSummary>> orders({String? state, String? search, int page = 1}) async {
    final j = _need(await _get('/api/vendor/v1/orders', query: {
      if (state != null && state.isNotEmpty) 'state': state,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': '$page',
    }));
    return ((j['data'] as List).cast<Map>())
        .map((m) => OrderSummary.fromJson(m.cast<String, dynamic>())).toList();
  }
  Future<OrderDetail> orderDetail(int id) async {
    final j = _need(await _get('/api/vendor/v1/orders/$id'));
    return OrderDetail.fromJson(((j['data'] as Map)['order'] as Map).cast<String, dynamic>());
  }
  Future<void> orderConfirm(int id) async { _need(await _post('/api/vendor/v1/orders/$id/confirm')); }
  Future<void> orderShip(int id) async { _need(await _post('/api/vendor/v1/orders/$id/ship')); }
  Future<void> orderCancel(int id, String reason) async {
    _need(await _post('/api/vendor/v1/orders/$id/cancel', {'reason': reason}));
  }

  // Chat
  Future<List<ChatMsg>> chat(int orderId) async {
    final j = _need(await _get('/api/vendor/v1/chat/$orderId'));
    return ((j['data'] as List).cast<Map>())
        .map((m) => ChatMsg.fromJson(m.cast<String, dynamic>())).toList();
  }
  Future<void> chatSend(int orderId, String body) async {
    _need(await _post('/api/vendor/v1/chat/$orderId/send', {'body': body}));
  }

  // Products
  Future<List<ProductSummary>> products({String? state, String? search, int page = 1}) async {
    final j = _need(await _get('/api/vendor/v1/products', query: {
      if (state != null && state.isNotEmpty) 'state': state,
      if (search != null && search.isNotEmpty) 'search': search,
      'page': '$page',
    }));
    return ((j['data'] as List).cast<Map>())
        .map((m) => ProductSummary.fromJson(m.cast<String, dynamic>())).toList();
  }
  Future<ProductDetail> productDetail(int id) async {
    final j = _need(await _get('/api/vendor/v1/products/$id'));
    return ProductDetail.fromJson(((j['data'] as Map)['product'] as Map).cast<String, dynamic>());
  }
  Future<int> productCreate({required String name, required double price,
      String description = '', String sku = '', Uint8List? image,
      String? nameAr, String? barcode, double? cost, double? weight,
      int? categoryId, List<Uint8List>? gallery}) async {
    final body = <String, dynamic>{
      'name_en': name, 'list_price': price,
      'description_sale': description, 'default_code': sku,
      if (nameAr != null && nameAr.isNotEmpty) 'name_ar': nameAr,
      if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
      if (cost != null) 'standard_price': cost,
      if (weight != null) 'weight': weight,
      if (categoryId != null && categoryId > 0) 'category_id': categoryId,
      if (image != null) 'image_base64': base64Encode(image),
      if (gallery != null && gallery.isNotEmpty)
        'gallery': gallery.map((g) => base64Encode(g)).toList(),
    };
    final j = _need(await _post('/api/vendor/v1/products/create', body));
    return (j['data'] as Map)['id'] as int;
  }
  Future<List<Map<String, dynamic>>> categories() async {
    final j = _need(await _get('/api/vendor/v1/categories'));
    return ((j['data'] as List).cast<Map>()).map((m) => m.cast<String, dynamic>()).toList();
  }
  Future<void> productUpdate(int id, Map<String, dynamic> body) async {
    _need(await _post('/api/vendor/v1/products/$id/update', body));
  }
  Future<void> productSetStock(int id, double qty) async {
    _need(await _post('/api/vendor/v1/products/$id/stock', {'qty': qty}));
  }
  Future<void> productArchive(int id) async {
    _need(await _post('/api/vendor/v1/products/$id/delete'));
  }
  Future<void> productRestore(int id) async {
    _need(await _post('/api/vendor/v1/products/$id/restore'));
  }

  // Reviews
  Future<List<Review>> reviews({int page = 1}) async {
    final j = _need(await _get('/api/vendor/v1/reviews', query: {'page': '$page'}));
    return ((j['data'] as List).cast<Map>())
        .map((m) => Review.fromJson(m.cast<String, dynamic>())).toList();
  }
  Future<void> reviewReply(int id, String text) async {
    _need(await _post('/api/vendor/v1/reviews/$id/reply', {'reply': text}));
  }

  // Wallet + payouts
  Future<WalletData> wallet() async {
    final j = _need(await _get('/api/vendor/v1/wallet'));
    return WalletData.fromJson((j['data'] as Map).cast<String, dynamic>());
  }
  Future<List<PayoutSummary>> payouts() async {
    final j = _need(await _get('/api/vendor/v1/payouts'));
    return ((j['data'] as List).cast<Map>())
        .map((m) => PayoutSummary.fromJson(m.cast<String, dynamic>())).toList();
  }
  Future<CommissionList> commissions({String? state}) async {
    final j = _need(await _get('/api/vendor/v1/commissions',
        query: {if (state != null && state.isNotEmpty) 'state': state}));
    return CommissionList.fromJson((j['data'] as Map).cast<String, dynamic>());
  }
  Future<PayoutSummary> requestPayout() async {
    final j = _need(await _post('/api/vendor/v1/payouts/request'));
    return PayoutSummary.fromJson(((j['data'] as Map)['payout'] as Map).cast<String, dynamic>());
  }

  // Analytics
  Future<SalesTimeseries> salesTimeseries({int days = 30}) async {
    final j = _need(await _get('/api/vendor/v1/analytics/sales', query: {'days': '$days'}));
    return SalesTimeseries.fromJson((j['data'] as Map).cast<String, dynamic>());
  }
  Future<List<TopProduct>> topProducts() async {
    final j = _need(await _get('/api/vendor/v1/analytics/top-products'));
    return ((j['data'] as List).cast<Map>())
        .map((m) => TopProduct.fromJson(m.cast<String, dynamic>())).toList();
  }
  Future<List<TopCustomer>> topCustomers() async {
    final j = _need(await _get('/api/vendor/v1/analytics/top-customers'));
    return ((j['data'] as List).cast<Map>())
        .map((m) => TopCustomer.fromJson(m.cast<String, dynamic>())).toList();
  }

  // Meta
  Future<List<Map<String, dynamic>>> languages() async {
    final j = _need(await _get('/api/vendor/v1/app/languages'));
    return ((j['data'] as List).cast<Map>()).map((m) => m.cast<String, dynamic>()).toList();
  }

  // ── Capabilities (what this vendor may do) ──
  Future<Map<String, dynamic>> capabilities() async {
    final j = _need(await _get('/api/vendor/v1/capabilities'));
    final d = (j['data'] as Map).cast<String, dynamic>();
    final vt = d['vendor_type'];
    if (vt is String && vt.isNotEmpty) vendorType = vt;
    return d;
  }

  List<Map<String, dynamic>> _dataList(Map<String, dynamic> j) =>
      ((j['data'] as List?) ?? const []).cast<Map>()
          .map((m) => m.cast<String, dynamic>()).toList();

  // ── Flash sales ──
  Future<List<Map<String, dynamic>>> flashSales() async =>
      _dataList(_need(await _get('/api/vendor/v1/flash-sales')));
  Future<void> flashCreate(Map<String, dynamic> body) async =>
      _need(await _post('/api/vendor/v1/flash-sales', body));
  Future<void> flashEnd(int id) async =>
      _need(await _post('/api/vendor/v1/flash-sales/$id/end'));

  // ── Promotions ──
  Future<Map<String, dynamic>> promotions() async {
    final j = _need(await _get('/api/vendor/v1/promotions'));
    return (j['data'] as Map).cast<String, dynamic>();
  }
  Future<void> promotionJoin(int promotionId, List<Map<String, dynamic>> items) async =>
      _need(await _post('/api/vendor/v1/promotions/join',
          {'promotion_id': promotionId, 'items': items}));

  // ── Stock ──
  Future<List<Map<String, dynamic>>> stock({String filter = 'all'}) async =>
      _dataList(_need(await _get('/api/vendor/v1/stock', query: {'filter': filter})));

  // ── Restock requests ──
  Future<List<Map<String, dynamic>>> restockList() async =>
      _dataList(_need(await _get('/api/vendor/v1/restock')));
  Future<void> restockCreate(int productId, int qty, String notes) async =>
      _need(await _post('/api/vendor/v1/restock',
          {'product_id': productId, 'qty': qty, 'notes': notes}));

  // ── Store style ──
  Future<Map<String, dynamic>> styleGet() async {
    final j = _need(await _get('/api/vendor/v1/style'));
    return (j['data'] as Map).cast<String, dynamic>();
  }
  Future<void> styleSave(Map<String, dynamic> body) async =>
      _need(await _post('/api/vendor/v1/style', body));
}

class VendorApiException implements Exception {
  VendorApiException(this.message, {this.code = 'ERROR'});
  final String message, code;
  @override
  String toString() => 'VendorApiException($code): $message';
}

// ── Models ────────────────────────────────────────────

class BL {
  final String en, ar;
  const BL(this.en, this.ar);
  factory BL.fromJson(dynamic v) {
    if (v is Map) return BL((v['en'] ?? '').toString(), (v['ar'] ?? v['en'] ?? '').toString());
    return BL((v ?? '').toString(), (v ?? '').toString());
  }
  String t(String l) => l == 'ar' ? (ar.isNotEmpty ? ar : en) : (en.isNotEmpty ? en : ar);
  Map<String, dynamic> toJson() => {'en': en, 'ar': ar};
}

class Money {
  final double amount;
  final String currency, symbol;
  final int digits;
  const Money({required this.amount, required this.currency,
      required this.symbol, required this.digits});
  factory Money.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    return Money(
      amount: ((j['amount'] ?? 0) as num).toDouble(),
      currency: (j['currency'] ?? 'KWD').toString(),
      symbol: (j['symbol'] ?? 'KD').toString(),
      digits: (j['digits'] ?? 3) as int,
    );
  }
  String format([String? lang]) {
    final v = amount.toStringAsFixed(digits);
    final sym = (lang == 'ar') ? (const {'KD':'د.ك','KWD':'د.ك','SAR':'ر.س','AED':'د.إ',
        'EGP':'ج.م','QAR':'ر.ق','OMR':'ر.ع.'}[symbol] ?? symbol) : symbol;
    return '$v $sym';
  }
  Map<String, dynamic> toJson() => {'amount': amount, 'currency': currency,
      'symbol': symbol, 'digits': digits};
}

class Vendor {
  final int id;
  final BL storeName, tagline;
  final String slug, state, tier, brandColor, currency, currencySymbol, country;
  final String businessName, contactPhone, contactEmail, bankIban, bankName;
  final String? logoUrl, bannerUrl;
  final double walletBalance, avgRating, totalSales;
  final int followerCount, orderCount;
  const Vendor({required this.id, required this.storeName, required this.tagline,
      required this.slug, required this.state, required this.tier,
      required this.brandColor, required this.currency, required this.currencySymbol,
      required this.country, required this.businessName, required this.contactPhone,
      required this.contactEmail, required this.bankIban, required this.bankName,
      this.logoUrl, this.bannerUrl, required this.walletBalance,
      required this.avgRating, required this.totalSales,
      required this.followerCount, required this.orderCount});
  factory Vendor.fromJson(Map<String, dynamic> j) => Vendor(
    id: (j['id'] ?? 0) as int,
    storeName: BL.fromJson(j['store_name']),
    tagline: BL.fromJson(j['tagline']),
    slug: (j['slug'] ?? '').toString(),
    state: (j['state'] ?? 'pending').toString(),
    tier: (j['tier'] ?? 'bronze').toString(),
    brandColor: (j['brand_color'] ?? '#F5C320').toString(),
    currency: (j['currency'] ?? 'KWD').toString(),
    currencySymbol: (j['currency_symbol'] ?? 'KD').toString(),
    country: (j['country'] ?? '').toString(),
    businessName: (j['business_name'] ?? '').toString(),
    contactPhone: (j['contact_phone'] ?? '').toString(),
    contactEmail: (j['contact_email'] ?? '').toString(),
    bankIban: (j['bank_iban'] ?? '').toString(),
    bankName: (j['bank_name'] ?? '').toString(),
    logoUrl: j['logo_url'] as String?,
    bannerUrl: j['banner_url'] as String?,
    walletBalance: ((j['wallet_balance'] ?? 0) as num).toDouble(),
    avgRating: ((j['avg_rating'] ?? 0) as num).toDouble(),
    totalSales: ((j['total_sales'] ?? 0) as num).toDouble(),
    followerCount: (j['follower_count'] ?? 0) as int,
    orderCount: (j['order_count'] ?? 0) as int,
  );
  Map<String, dynamic> toJson() => {
    'id': id, 'store_name': storeName.toJson(), 'tagline': tagline.toJson(),
    'slug': slug, 'state': state, 'tier': tier, 'brand_color': brandColor,
    'currency': currency, 'currency_symbol': currencySymbol, 'country': country,
    'business_name': businessName, 'contact_phone': contactPhone,
    'contact_email': contactEmail, 'bank_iban': bankIban, 'bank_name': bankName,
    'logo_url': logoUrl, 'banner_url': bannerUrl,
    'wallet_balance': walletBalance, 'avg_rating': avgRating,
    'total_sales': totalSales, 'follower_count': followerCount,
    'order_count': orderCount,
  };
}

class Dashboard {
  final Money revToday, revWeek, revMonth, revTotal;
  final int ordersPending, ordersNew, ordersConfirmed, ordersCompleted, ordersCancelled;
  final int productsActive, productsPendingApproval, productsLowStock;
  final Money walletBalance;
  final double avgRating;
  final int followerCount;
  final String tier;
  final List<RecentOrder> recentOrders;
  const Dashboard({required this.revToday, required this.revWeek, required this.revMonth,
      required this.revTotal, required this.ordersPending, required this.ordersNew,
      required this.ordersConfirmed, required this.ordersCompleted, required this.ordersCancelled,
      required this.productsActive, required this.productsPendingApproval,
      required this.productsLowStock, required this.walletBalance,
      required this.avgRating, required this.followerCount, required this.tier,
      required this.recentOrders});
  factory Dashboard.fromJson(Map<String, dynamic> j) {
    final rev = (j['revenue'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ord = (j['orders'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pro = (j['products'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Dashboard(
      revToday: Money.fromJson((rev['today'] as Map?)?.cast<String, dynamic>()),
      revWeek: Money.fromJson((rev['week'] as Map?)?.cast<String, dynamic>()),
      revMonth: Money.fromJson((rev['month'] as Map?)?.cast<String, dynamic>()),
      revTotal: Money.fromJson((rev['total'] as Map?)?.cast<String, dynamic>()),
      ordersPending: (ord['pending'] ?? 0) as int,
      ordersNew: (ord['new'] ?? 0) as int,
      ordersConfirmed: (ord['confirmed'] ?? 0) as int,
      ordersCompleted: (ord['completed'] ?? 0) as int,
      ordersCancelled: (ord['cancelled'] ?? 0) as int,
      productsActive: (pro['active'] ?? 0) as int,
      productsPendingApproval: (pro['pending_approval'] ?? 0) as int,
      productsLowStock: (pro['low_stock'] ?? 0) as int,
      walletBalance: Money.fromJson((j['wallet_balance'] as Map?)?.cast<String, dynamic>()),
      avgRating: ((j['avg_rating'] ?? 0) as num).toDouble(),
      followerCount: (j['follower_count'] ?? 0) as int,
      tier: (j['tier'] ?? 'bronze').toString(),
      recentOrders: ((j['recent_orders'] as List?) ?? const [])
        .map((e) => RecentOrder.fromJson((e as Map).cast<String, dynamic>())).toList(),
    );
  }
}

class RecentOrder {
  final int id;
  final String name, customer, state, when;
  final Money amount;
  const RecentOrder({required this.id, required this.name, required this.customer,
      required this.state, required this.when, required this.amount});
  factory RecentOrder.fromJson(Map<String, dynamic> j) => RecentOrder(
    id: (j['id'] ?? 0) as int,
    name: (j['name'] ?? '').toString(),
    customer: (j['customer'] ?? '').toString(),
    state: (j['state'] ?? '').toString(),
    when: (j['when'] ?? '').toString(),
    amount: Money.fromJson((j['amount'] as Map?)?.cast<String, dynamic>()),
  );
}

class OrderSummary {
  final int id;
  final String name, state, when, invoiceStatus;
  final BL stateLabel;
  final Money amount;
  final int itemCount;
  final Map<String, dynamic> customer;
  const OrderSummary({required this.id, required this.name, required this.state,
      required this.when, required this.invoiceStatus, required this.stateLabel,
      required this.amount, required this.itemCount, required this.customer});
  factory OrderSummary.fromJson(Map<String, dynamic> j) => OrderSummary(
    id: (j['id'] ?? 0) as int,
    name: (j['name'] ?? '').toString(),
    state: (j['state'] ?? '').toString(),
    when: (j['when'] ?? '').toString(),
    invoiceStatus: (j['invoice_status'] ?? '').toString(),
    stateLabel: BL.fromJson(j['state_label']),
    amount: Money.fromJson((j['amount'] as Map?)?.cast<String, dynamic>()),
    itemCount: (j['item_count'] ?? 0) as int,
    customer: (j['customer'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
}

class OrderDetail extends OrderSummary {
  final Money subtotal, shipping;
  final Map<String, dynamic> shippingAddress;
  final List<OrderItem> items;
  final String note;
  const OrderDetail({required super.id, required super.name, required super.state,
      required super.when, required super.invoiceStatus, required super.stateLabel,
      required super.amount, required super.itemCount, required super.customer,
      required this.subtotal, required this.shipping, required this.shippingAddress,
      required this.items, required this.note});
  factory OrderDetail.fromJson(Map<String, dynamic> j) {
    final b = OrderSummary.fromJson(j);
    return OrderDetail(
      id: b.id, name: b.name, state: b.state, when: b.when,
      invoiceStatus: b.invoiceStatus, stateLabel: b.stateLabel,
      amount: b.amount, itemCount: b.itemCount, customer: b.customer,
      subtotal: Money.fromJson((j['subtotal'] as Map?)?.cast<String, dynamic>()),
      shipping: Money.fromJson((j['shipping'] as Map?)?.cast<String, dynamic>()),
      shippingAddress: (j['shipping_address'] as Map?)?.cast<String, dynamic>() ?? const {},
      items: ((j['items'] as List?) ?? const [])
        .map((e) => OrderItem.fromJson((e as Map).cast<String, dynamic>())).toList(),
      note: (j['note'] ?? '').toString(),
    );
  }
}

class OrderItem {
  final int id, productId;
  final BL name;
  final double qty;
  final Money price, subtotal;
  final String imageUrl;
  const OrderItem({required this.id, required this.productId, required this.name,
      required this.qty, required this.price, required this.subtotal, required this.imageUrl});
  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    id: (j['id'] ?? 0) as int,
    productId: (j['product_id'] ?? 0) as int,
    name: BL.fromJson(j['name']),
    qty: ((j['qty'] ?? 0) as num).toDouble(),
    price: Money.fromJson((j['price'] as Map?)?.cast<String, dynamic>()),
    subtotal: Money.fromJson((j['subtotal'] as Map?)?.cast<String, dynamic>()),
    imageUrl: (j['image_url'] ?? '').toString(),
  );
}

class ChatMsg {
  final int id;
  final String body, when;
  final bool isSelf;
  final Map<String, dynamic> author;
  const ChatMsg({required this.id, required this.body, required this.when,
      required this.isSelf, required this.author});
  factory ChatMsg.fromJson(Map<String, dynamic> j) => ChatMsg(
    id: (j['id'] ?? 0) as int,
    body: (j['body'] ?? '').toString(),
    when: (j['when'] ?? '').toString(),
    isSelf: (j['is_self'] ?? false) as bool,
    author: (j['author'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
}

class ProductSummary {
  final int id;
  final BL name;
  final Money listPrice, standardPrice;
  final bool isPublished;
  final double qty, salesCount;
  final String approvalState, rejectionReason;
  final String? imageUrl;
  final bool active;
  final bool underReview;
  const ProductSummary({required this.id, required this.name,
      required this.listPrice, required this.standardPrice,
      required this.isPublished, required this.qty, required this.salesCount,
      required this.approvalState, required this.rejectionReason, this.imageUrl,
      this.active = true, this.underReview = false});
  factory ProductSummary.fromJson(Map<String, dynamic> j) => ProductSummary(
    id: (j['id'] ?? 0) as int,
    name: BL.fromJson(j['name']),
    listPrice: Money.fromJson((j['list_price'] as Map?)?.cast<String, dynamic>()),
    standardPrice: Money.fromJson((j['standard_price'] as Map?)?.cast<String, dynamic>()),
    isPublished: (j['is_published'] ?? false) as bool,
    qty: ((j['qty_available'] ?? 0) as num).toDouble(),
    salesCount: ((j['sales_count'] ?? 0) as num).toDouble(),
    approvalState: (j['approval_state'] ?? 'draft').toString(),
    rejectionReason: (j['rejection_reason'] ?? '').toString(),
    imageUrl: j['image_url'] as String?,
    active: (j['active'] ?? true) as bool,
    underReview: (j['under_review'] ?? false) as bool,
  );
}

class ProductDetail extends ProductSummary {
  final String descriptionSale, description, sku, barcode;
  final double weight;
  final List<Map<String, dynamic>> variants;
  final String pendingChange;
  final String nameAr, nameEn;
  final int categoryId;
  final String categoryName;
  final List<String> gallery;
  const ProductDetail({required super.id, required super.name,
      required super.listPrice, required super.standardPrice,
      required super.isPublished, required super.qty, required super.salesCount,
      required super.approvalState, required super.rejectionReason, super.imageUrl,
      super.active, super.underReview,
      required this.descriptionSale, required this.description,
      required this.sku, required this.barcode, required this.weight,
      required this.variants, this.pendingChange = '',
      this.nameAr = '', this.nameEn = '', this.categoryId = 0,
      this.categoryName = '', this.gallery = const []});
  factory ProductDetail.fromJson(Map<String, dynamic> j) {
    final b = ProductSummary.fromJson(j);
    return ProductDetail(
      id: b.id, name: b.name, listPrice: b.listPrice, standardPrice: b.standardPrice,
      isPublished: b.isPublished, qty: b.qty, salesCount: b.salesCount,
      approvalState: b.approvalState, rejectionReason: b.rejectionReason, imageUrl: b.imageUrl,
      active: b.active, underReview: b.underReview,
      descriptionSale: (j['description_sale'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      sku: (j['default_code'] ?? '').toString(),
      barcode: (j['barcode'] ?? '').toString(),
      weight: ((j['weight'] ?? 0) as num).toDouble(),
      variants: ((j['variant_ids'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>()).toList(),
      pendingChange: (j['pending_change'] ?? '').toString(),
      nameAr: (j['name_ar'] ?? '').toString(),
      nameEn: (j['name_en'] ?? '').toString(),
      categoryId: ((j['category'] as Map?)?['id'] ?? 0) as int,
      categoryName: (((j['category'] as Map?)?['name'] as Map?)?['en'] ?? '').toString(),
      gallery: ((j['gallery'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class Review {
  final int id;
  final double rating;
  final String comment, reply, when;
  final Map<String, dynamic>? author, product;
  const Review({required this.id, required this.rating, required this.comment,
      required this.reply, required this.when, this.author, this.product});
  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: (j['id'] ?? 0) as int,
    rating: ((j['rating'] ?? 0) as num).toDouble(),
    comment: (j['comment'] ?? '').toString(),
    reply: (j['reply'] ?? '').toString(),
    when: (j['when'] ?? '').toString(),
    author: (j['author'] is Map) ? (j['author'] as Map).cast<String, dynamic>() : null,
    product: (j['product'] is Map) ? (j['product'] as Map).cast<String, dynamic>() : null,
  );
}

class WalletData {
  final Money balance, pending;
  final List<WalletTx> transactions;
  const WalletData({required this.balance, required this.pending, required this.transactions});
  factory WalletData.fromJson(Map<String, dynamic> j) => WalletData(
    balance: Money.fromJson((j['balance'] as Map?)?.cast<String, dynamic>()),
    pending: Money.fromJson((j['pending'] as Map?)?.cast<String, dynamic>()),
    transactions: ((j['transactions'] as List?) ?? const [])
      .map((e) => WalletTx.fromJson((e as Map).cast<String, dynamic>())).toList(),
  );
}

class WalletTx {
  final int id;
  final Money amount;
  final String type, state, description, when;
  const WalletTx({required this.id, required this.amount, required this.type,
      required this.state, required this.description, required this.when});
  factory WalletTx.fromJson(Map<String, dynamic> j) => WalletTx(
    id: (j['id'] ?? 0) as int,
    amount: Money.fromJson((j['amount'] as Map?)?.cast<String, dynamic>()),
    type: (j['type'] ?? '').toString(),
    state: (j['state'] ?? '').toString(),
    description: (j['description'] ?? '').toString(),
    when: (j['when'] ?? '').toString(),
  );
}

class PayoutSummary {
  final int id;
  final String name, state, when;
  final BL stateLabel;
  final Money amount;
  final int lineCount;
  final String? payoutDate, bankIban;
  const PayoutSummary({required this.id, required this.name, required this.state,
      required this.when, required this.stateLabel, required this.amount,
      required this.lineCount, this.payoutDate, this.bankIban});
  factory PayoutSummary.fromJson(Map<String, dynamic> j) => PayoutSummary(
    id: (j['id'] ?? 0) as int,
    name: (j['name'] ?? '').toString(),
    state: (j['state'] ?? '').toString(),
    when: (j['when'] ?? '').toString(),
    stateLabel: BL.fromJson(j['state_label']),
    amount: Money.fromJson((j['amount'] as Map?)?.cast<String, dynamic>()),
    lineCount: (j['line_count'] ?? 0) as int,
    payoutDate: j['payout_date'] as String?,
    bankIban: j['bank_iban'] as String?,
  );
}

class CommissionList {
  final List<Commission> items;
  final Money pending, released, paidOut;
  const CommissionList({required this.items, required this.pending,
      required this.released, required this.paidOut});
  factory CommissionList.fromJson(Map<String, dynamic> j) {
    final t = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CommissionList(
      items: ((j['items'] as List?) ?? const [])
        .map((e) => Commission.fromJson((e as Map).cast<String, dynamic>())).toList(),
      pending: Money.fromJson((t['pending'] as Map?)?.cast<String, dynamic>()),
      released: Money.fromJson((t['released'] as Map?)?.cast<String, dynamic>()),
      paidOut: Money.fromJson((t['paid_out'] as Map?)?.cast<String, dynamic>()),
    );
  }
}

class Commission {
  final int id, orderId;
  final String orderName, orderDate, state;
  final Money orderAmount, commissionAmount, netAmount;
  final double commissionRate;
  final String? releaseDate;
  const Commission({required this.id, required this.orderId, required this.orderName,
      required this.orderDate, required this.state, required this.orderAmount,
      required this.commissionAmount, required this.netAmount,
      required this.commissionRate, this.releaseDate});
  factory Commission.fromJson(Map<String, dynamic> j) => Commission(
    id: (j['id'] ?? 0) as int,
    orderId: (j['order_id'] ?? 0) as int,
    orderName: (j['order_name'] ?? '').toString(),
    orderDate: (j['order_date'] ?? '').toString(),
    state: (j['state'] ?? '').toString(),
    orderAmount: Money.fromJson((j['order_amount'] as Map?)?.cast<String, dynamic>()),
    commissionAmount: Money.fromJson((j['commission_amount'] as Map?)?.cast<String, dynamic>()),
    netAmount: Money.fromJson((j['net_vendor_amount'] as Map?)?.cast<String, dynamic>()),
    commissionRate: ((j['commission_rate'] ?? 0) as num).toDouble(),
    releaseDate: j['release_date'] as String?,
  );
}

class SalesTimeseries {
  final List<SalesDay> days;
  final double totalRevenue;
  final int totalOrders;
  const SalesTimeseries({required this.days, required this.totalRevenue, required this.totalOrders});
  factory SalesTimeseries.fromJson(Map<String, dynamic> j) => SalesTimeseries(
    days: ((j['days'] as List?) ?? const [])
      .map((e) => SalesDay.fromJson((e as Map).cast<String, dynamic>())).toList(),
    totalRevenue: ((j['total_revenue'] ?? 0) as num).toDouble(),
    totalOrders: (j['total_orders'] ?? 0) as int,
  );
}

class SalesDay {
  final String date;
  final double revenue;
  final int orders;
  const SalesDay({required this.date, required this.revenue, required this.orders});
  factory SalesDay.fromJson(Map<String, dynamic> j) => SalesDay(
    date: (j['date'] ?? '').toString(),
    revenue: ((j['revenue'] ?? 0) as num).toDouble(),
    orders: (j['orders'] ?? 0) as int,
  );
}

class TopProduct {
  final int id;
  final BL name;
  final Money revenue;
  final double qty;
  final String? imageUrl;
  const TopProduct({required this.id, required this.name, required this.revenue,
      required this.qty, this.imageUrl});
  factory TopProduct.fromJson(Map<String, dynamic> j) => TopProduct(
    id: (j['id'] ?? 0) as int,
    name: BL.fromJson(j['name']),
    revenue: Money.fromJson((j['revenue'] as Map?)?.cast<String, dynamic>()),
    qty: ((j['qty'] ?? 0) as num).toDouble(),
    imageUrl: j['image_url'] as String?,
  );
}

class TopCustomer {
  final int id;
  final String name;
  final Money spent;
  final int orders;
  final String? avatarUrl;
  const TopCustomer({required this.id, required this.name, required this.spent,
      required this.orders, this.avatarUrl});
  factory TopCustomer.fromJson(Map<String, dynamic> j) => TopCustomer(
    id: (j['id'] ?? 0) as int,
    name: (j['name'] ?? '').toString(),
    spent: Money.fromJson((j['spent'] as Map?)?.cast<String, dynamic>()),
    orders: (j['orders'] ?? 0) as int,
    avatarUrl: j['avatar_url'] as String?,
  );
}
