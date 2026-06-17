import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/api.dart';
import 'fcm_service.dart';
import 'theme/theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/product_edit_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/payouts_screen.dart';
import 'screens/commissions_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/reviews_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/flash_sales_screen.dart';
import 'screens/promotions_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/restock_screen.dart';
import 'screens/style_screen.dart';
import 'screens/price_requests_screen.dart';
import 'screens/admin/admin_screens.dart';
import 'screens/returns_screen.dart';
import 'screens/reports_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await VendorApi.instance.init();
  unawaited(FcmService.instance.init());
  runApp(const VendorApp());
}

class VendorApp extends StatelessWidget {
  const VendorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: VendorApi.instance.langNotifier,
      builder: (context, lang, _) {
        final isAr = lang == 'ar';
        return MaterialApp(
          title: 'Uellow Vendor',
          debugShowCheckedModeBanner: false,
          theme: uellowVendorTheme(),
          locale: isAr ? const Locale('ar') : const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
          initialRoute: '/',
          routes: {
            '/':            (_) => const SplashScreen(),
            '/login':       (_) => const LoginScreen(),
            '/home':        (_) => const HomeScreen(),
            '/payouts':     (_) => const PayoutsScreen(),
            '/commissions': (_) => const CommissionsScreen(),
            '/wallet':      (_) => const WalletScreen(),
            '/reviews':     (_) => const ReviewsScreen(),
            '/analytics':   (_) => const AnalyticsScreen(),
            '/profile':     (_) => const ProfileScreen(),
            '/settings':    (_) => const SettingsScreen(),
            '/flash':       (_) => const FlashSalesScreen(),
            '/promotions':  (_) => const PromotionsScreen(),
            '/stock':       (_) => const StockScreen(),
            '/restock':     (_) => const RestockScreen(),
            '/style':       (_) => const StyleScreen(),
            '/price-requests': (_) => const PriceRequestsScreen(),
            '/admin':       (_) => const AdminHomeScreen(),
            '/returns':     (_) => const ReturnsScreen(),
            '/reports':     (_) => const ReportsScreen(),
          },
          onGenerateRoute: (settings) {
            final args = (settings.arguments as Map?) ?? const {};
            switch (settings.name) {
              case '/order':
                return MaterialPageRoute(settings: settings,
                    builder: (_) => OrderDetailScreen(orderId: args['id'] as int? ?? 0));
              case '/product':
                return MaterialPageRoute(settings: settings,
                    builder: (_) => ProductDetailScreen(productId: args['id'] as int? ?? 0));
              case '/product-edit':
                return MaterialPageRoute(settings: settings,
                    builder: (_) => ProductEditScreen(productId: args['id'] as int?));
              case '/chat':
                return MaterialPageRoute(settings: settings,
                    builder: (_) => ChatScreen(orderId: args['id'] as int? ?? 0,
                                                title: args['title'] as String? ?? ''));
            }
            return null;
          },
        );
      },
    );
  }
}
