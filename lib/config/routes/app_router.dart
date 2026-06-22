import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/screens/cart_screen.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/screens/checkout_screen.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/screens/kiosk_placeholder_screen.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/screens/kiosk_splash_screen.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/screens/menu_screen.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/screens/order_tracking_screen.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/screens/payment_screen.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/screens/product_detail_screen.dart';

/// App router configuration using GoRouter.
class AppRouter {
  AppRouter._();

  static const String initial = '/';
  static const String menu = '/menu';
  static const String productDetail = '/products/:menuItemId';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String payment = '/payment/:orderId';
  static const String orders = '/orders/:orderId';
  static const String success = '/success';
  static const String error = '/error';

  static String productPath(String menuItemId) => '/products/$menuItemId';

  static String paymentPath(String orderId) => '/payment/$orderId';

  static String orderPath(String orderId) => '/orders/$orderId';

  static final GoRouter router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: initial,
        builder: (BuildContext context, GoRouterState state) {
          return const KioskSplashScreen();
        },
      ),
      GoRoute(
        path: menu,
        builder: (BuildContext context, GoRouterState state) {
          return const MenuScreen();
        },
      ),
      GoRoute(
        path: productDetail,
        builder: (BuildContext context, GoRouterState state) {
          final menuItemId = state.pathParameters['menuItemId'] ?? '';
          return ProductDetailScreen(menuItemId: menuItemId);
        },
      ),
      GoRoute(
        path: cart,
        builder: (BuildContext context, GoRouterState state) {
          return const CartScreen();
        },
      ),
      GoRoute(
        path: checkout,
        builder: (BuildContext context, GoRouterState state) {
          return const CheckoutScreen();
        },
      ),
      GoRoute(
        path: payment,
        builder: (BuildContext context, GoRouterState state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return PaymentScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: orders,
        builder: (BuildContext context, GoRouterState state) {
          final orderId = state.pathParameters['orderId'] ?? '';
          return OrderTrackingScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: success,
        builder: (BuildContext context, GoRouterState state) {
          return const KioskPlaceholderScreen(
            title: 'Nhận kem thành công',
            subtitle: 'Màn hình hoàn tất giao dịch cho khách hàng.',
            routeLabel: '/success',
          );
        },
      ),
      GoRoute(
        path: error,
        builder: (BuildContext context, GoRouterState state) {
          return const KioskPlaceholderScreen(
            title: 'Có lỗi xảy ra',
            subtitle: 'Màn hình lỗi sẽ hướng dẫn khách hủy hoặc gọi nhân viên.',
            routeLabel: '/error',
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Không tìm thấy màn hình: ${state.uri}')),
    ),
  );
}
