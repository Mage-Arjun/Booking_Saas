import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'features/auth/application/auth_session.dart';
import 'shared/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: BookingApp()));
}

/// Root widget assembling global application services and presentation.
class BookingApp extends ConsumerWidget {
  const BookingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final router = AppRouter.createRouter(session);

    return MaterialApp.router(
      title: 'Booking SaaS',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
