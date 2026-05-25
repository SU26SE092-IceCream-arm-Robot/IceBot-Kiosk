import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// App router configuration using GoRouter for Kiosk.
class AppRouter {
  AppRouter._();

  static const String initial = '/';
  static const String home = '/home';

  static final GoRouter router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: initial,
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(
            body: Center(
              child: Text(
                'IceBot Kiosk Splash Screen',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: home,
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(
            body: Center(
              child: Text(
                'IceBot Kiosk Home Screen',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
}
