import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/language_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/website_builder/screens/website_builder_screen.dart';
import '../layout/app_shell.dart';
import '../../features/onboarding/screens/shop_type_screen.dart';
import '../../features/onboarding/screens/shop_details_screen.dart';
import '../../features/onboarding/screens/banner_upload_screen.dart';
import '../../features/onboarding/screens/delivery_setup_screen.dart';
import '../../features/onboarding/screens/payment_setup_screen.dart';
import '../../features/onboarding/screens/setup_complete_screen.dart';
import '../../features/orders/screens/orders_list_screen.dart';
import '../../features/orders/screens/order_detail_screen.dart';
import '../../features/products/screens/products_list_screen.dart';
import '../../features/products/screens/add_product_screen.dart';
import '../../features/products/screens/batch_scan_screen.dart';
import '../../features/products/screens/live_scan_screen.dart';
import '../../features/products/screens/print_labels_screen.dart';
import '../../features/products/screens/live_barcode_scan_screen.dart';
import '../../features/products/screens/import_products_screen.dart';
import '../../features/products/screens/starter_catalog_screen.dart';
import '../../features/products/screens/stock_alerts_screen.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/settings/screens/shop_settings_screen.dart';
import '../../features/settings/screens/account_settings_screen.dart';
import '../../features/settings/screens/staff_management_screen.dart';
import '../../features/settings/screens/printer_settings_screen.dart';
import '../../features/shops/screens/manage_shops_screen.dart';
import '../../features/share/screens/share_screen.dart';
import '../../features/help/screens/help_screen.dart';
import '../../features/subscription/screens/subscription_screen.dart';
import '../../features/credits/screens/credits_screen.dart';
import '../../features/credits/screens/add_credit_screen.dart';
import '../../features/billing/screens/billing_screen.dart';
import '../../features/billing/screens/bill_history_screen.dart';
import '../../features/billing/screens/gstr1_screen.dart';
import '../../features/kot/screens/kot_screen.dart';
import '../../features/billing/screens/bill_detail_screen.dart';
import '../../features/billing/screens/cash_counter_screen.dart';
import '../../features/customers/screens/customers_screen.dart';
import '../../models/customer_model.dart';
import '../../features/customers/screens/customer_detail_screen.dart';
import '../../features/suppliers/screens/suppliers_list_screen.dart';
import '../../features/suppliers/screens/add_supplier_screen.dart';
import '../../features/suppliers/screens/supplier_detail_screen.dart';
import '../../features/suppliers/screens/stock_receive_screen.dart';
import '../../features/orders/screens/voice_order_screen.dart';
import '../../features/reorder/screens/reorder_screen.dart';
import '../../features/festival/screens/festival_screen.dart';
import '../../features/settings/screens/ondc_settings_screen.dart';
import '../../features/settings/screens/ai_settings_screen.dart';
import '../../features/settings/screens/whatsapp_notifications_screen.dart';
import '../../features/marketing/screens/broadcast_screen.dart';
import '../../features/marketing/screens/flash_sale_screen.dart';
import '../../features/marketing/screens/loyalty_screen.dart';
import '../../features/marketing/screens/udhar_screen.dart';
import '../../features/products/screens/bulk_import_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/bill_model.dart';
import '../../models/supplier_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';

// Routes that do NOT require Firebase auth
const _publicRoutes = {
  '/splash', '/language', '/website-builder',
};

// Routes that require phone OTP auth
const _authRoutes = {'/login', '/verify'};

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (BuildContext context, GoRouterState state) async {
      final path = state.matchedLocation;

      // Splash handles its own redirect
      if (path == '/splash') return null;

      // Wait for Firebase auth to resolve
      if (authState.isLoading) return null;

      final user = authState.value;
      final isAuthenticated = user != null;

      // Public routes (no auth needed)
      if (_publicRoutes.any((r) => path.startsWith(r))) return null;

      // Auth screens — don't redirect if going there intentionally
      if (_authRoutes.contains(path)) return null;

      // All other routes (shop dashboard, orders, etc.) require phone auth
      if (!isAuthenticated) {
        final prefs = await SharedPreferences.getInstance();
        final hasLang = prefs.getString('language') != null;
        return hasLang ? '/login' : '/language';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/language', builder: (_, __) => const LanguageScreen()),

      // --- Phone OTP auth ---
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/verify',
        builder: (_, state) => OtpScreen(phoneNumber: state.extra as String? ?? ''),
      ),

      // --- Main app shell ---
      GoRoute(path: '/home', builder: (_, __) => const AppShell()),

      // --- Shop owner dashboard (requires phone auth) ---
      GoRoute(path: '/onboard/type', builder: (_, __) => const ShopTypeScreen()),
      GoRoute(path: '/onboard/details', builder: (_, __) => const ShopDetailsScreen()),
      GoRoute(path: '/onboard/banner', builder: (_, __) => const BannerUploadScreen()),
      GoRoute(path: '/onboard/delivery', builder: (_, __) => const DeliverySetupScreen()),
      GoRoute(path: '/onboard/payment', builder: (_, __) => const PaymentSetupScreen()),
      GoRoute(path: '/onboard/done', builder: (_, __) => const SetupCompleteScreen()),
      GoRoute(path: '/orders', builder: (_, __) => const OrdersListScreen()),
      GoRoute(
        path: '/orders/:id',
        builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/products', builder: (_, __) => const ProductsListScreen()),
      GoRoute(path: '/products/add', builder: (_, __) => const AddProductScreen()),
      GoRoute(path: '/products/batch', builder: (_, __) => const BatchScanScreen()),
      GoRoute(path: '/products/live-scan', builder: (_, __) => const LiveScanScreen()),
      GoRoute(path: '/products/live-barcode', builder: (_, __) => const LiveBarcodeScanScreen()),
      GoRoute(path: '/products/print-labels', builder: (_, __) => const PrintLabelsScreen()),
      GoRoute(path: '/products/import', builder: (_, __) => const ImportProductsScreen()),
      GoRoute(path: '/products/catalog', builder: (_, __) => const StarterCatalogScreen()),
      GoRoute(path: '/stock-alerts', builder: (_, __) => const StockAlertsScreen()),
      GoRoute(
        path: '/products/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return AddProductScreen(key: ValueKey(id), productId: id);
        },
      ),
      GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
      GoRoute(path: '/settings/shop', builder: (_, __) => const ShopSettingsScreen()),
      GoRoute(path: '/settings/account', builder: (_, __) => const AccountSettingsScreen()),
      GoRoute(path: '/settings/printer', builder: (_, __) => const PrinterSettingsScreen()),
      GoRoute(
        path: '/settings/staff',
        builder: (_, state) =>
            StaffManagementScreen(shopId: state.extra as String? ?? ''),
      ),
      GoRoute(path: '/shops', builder: (_, __) => const ManageShopsScreen()),
      GoRoute(path: '/shops/new', builder: (_, __) => const ShopTypeScreen()),
      GoRoute(path: '/share', builder: (_, __) => const ShareScreen()),
      GoRoute(path: '/help', builder: (_, __) => const HelpScreen()),
      GoRoute(path: '/subscription', builder: (_, __) => const SubscriptionScreen()),
      GoRoute(path: '/credits', builder: (_, __) => const CreditsScreen()),
      GoRoute(path: '/credits/add', builder: (_, __) => const AddCreditScreen()),
      GoRoute(path: '/billing', builder: (_, __) => const BillingScreen()),
      GoRoute(path: '/bill-history', builder: (_, __) => const BillHistoryScreen()),
      GoRoute(path: '/gstr1', builder: (_, __) => const Gstr1Screen()),
      GoRoute(path: '/cash-counter', builder: (_, __) => const CashCounterScreen()),
      GoRoute(path: '/kot', builder: (_, __) => const KotScreen()),
      GoRoute(
        path: '/bills/:billId',
        builder: (context, state) {
          final bill = state.extra;
          if (bill is BillModel) return BillDetailScreen(bill: bill);
          // Deep link (notification/cold start): load bill from Firestore
          final billId = state.pathParameters['billId'] ?? '';
          return _BillDeepLinkLoader(billId: billId);
        },
      ),
      GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
        GoRoute(
          path: '/customers/detail',
          builder: (_, state) {
            final customer = state.extra;
            if (customer is! CustomerModel) {
              // Deep link without data object: fall back to customers list
              return const CustomersScreen();
            }
            return CustomerDetailScreen(customer: customer);
          },
        ),
      GoRoute(path: '/suppliers', builder: (_, __) => const SuppliersListScreen()),
      GoRoute(
        path: '/stock-receive',
        builder: (_, state) {
          final extra = state.extra as Map<String, String?>?;
          return StockReceiveScreen(
            supplierId: extra?['supplierId'],
            supplierName: extra?['supplierName'],
          );
        },
      ),
      GoRoute(
        path: '/suppliers/add',
        builder: (_, state) => AddSupplierScreen(supplier: state.extra as SupplierModel?),
      ),
      GoRoute(
        path: '/suppliers/:supplierId',
        builder: (_, state) {
          final supplier = state.extra;
          if (supplier is! SupplierModel) {
            // Deep link without data object: fall back to suppliers list
            return const SuppliersListScreen();
          }
          return SupplierDetailScreen(supplier: supplier);
        },
      ),
      GoRoute(path: '/voice-order', builder: (_, __) => const VoiceOrderScreen()),
      GoRoute(path: '/reorder', builder: (_, __) => const ReorderScreen()),
      GoRoute(path: '/festival', builder: (_, __) => const FestivalScreen()),
      GoRoute(path: '/settings/ondc', builder: (_, __) => const OndcSettingsScreen()),
      GoRoute(path: '/settings/ai', builder: (_, __) => const AiSettingsScreen()),
      GoRoute(path: '/settings/whatsapp-notifications', builder: (_, __) => const WhatsappNotificationsScreen()),
      GoRoute(path: '/marketing/broadcast', builder: (_, __) => const BroadcastScreen()),
      GoRoute(path: '/marketing/flash-sale', builder: (_, __) => const FlashSaleScreen()),
      GoRoute(path: '/marketing/loyalty', builder: (_, __) => const LoyaltyScreen()),
      GoRoute(path: '/marketing/udhar', builder: (_, __) => const UdharScreen()),
      GoRoute(path: '/products/bulk-import', builder: (_, __) => const BulkImportScreen()),
      GoRoute(
        path: '/website-builder',
        builder: (_, state) => WebsiteBuilderScreen(url: state.extra as String? ?? ''),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});

// Loads a bill by ID from Firestore for deep links / notification taps.
// Falls back to BillHistoryScreen if the bill cannot be fetched.
class _BillDeepLinkLoader extends ConsumerWidget {
  final String billId;
  const _BillDeepLinkLoader({required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopIdAsync = ref.watch(activeShopIdProvider);

    return shopIdAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const BillHistoryScreen(),
      data: (shopId) {
        if (shopId == null || shopId.isEmpty || billId.isEmpty) {
          return const BillHistoryScreen();
        }
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('shops')
              .doc(shopId)
              .collection('bills')
              .doc(billId)
              .get(),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError || !snap.hasData || !snap.data!.exists) {
              return const BillHistoryScreen();
            }
            try {
              final bill = BillModel.fromFirestore(snap.data!);
              return BillDetailScreen(bill: bill);
            } catch (_) {
              return const BillHistoryScreen();
            }
          },
        );
      },
    );
  }
}
