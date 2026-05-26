// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/pantry/screens/pantry_screen.dart';
import '../../features/recipes/screens/recipes_screen.dart';
import '../../features/recipes/screens/recipe_detail_screen.dart';
import '../../features/shopping/screens/shopping_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/meal_plan/screens/meal_plan_screen.dart';
import '../../models/models.dart';

// ── Shell with bottom navigation ──────────────────────────────────────────────
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});

  static const _navItems = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.kitchen_outlined),
      selectedIcon: Icon(Icons.kitchen_rounded),
      label: 'Pantry',
    ),
    NavigationDestination(
      icon: Icon(Icons.restaurant_menu_outlined),
      selectedIcon: Icon(Icons.restaurant_menu_rounded),
      label: 'Recipes',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month_rounded),
      label: 'Plan',
    ),
    NavigationDestination(
      icon: Icon(Icons.shopping_cart_outlined),
      selectedIcon: Icon(Icons.shopping_cart_rounded),
      label: 'Shopping',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (i) => navigationShell.goBranch(
        i,
        initialLocation: i == navigationShell.currentIndex,
      ),
      destinations: _navItems,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
  );
}

// ── Splash Screen ─────────────────────────────────────────────────────────────
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for auth state changes and redirect accordingly
    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        GoRouter.of(context).go('/home');
      } else if (next.status == AuthStatus.unauthenticated) {
        GoRouter.of(context).go('/login');
      }
    });

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_rounded, size: 72, color: Color(0xFF2D6A4F)),
            SizedBox(height: 24),
            Text(
              'FreshPlan',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2D6A4F),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Smart Pantry & Meal Planning',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(
              color: Color(0xFF2D6A4F),
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Forgot Password Screen ────────────────────────────────────────────────────
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _sent = false, _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Reset Password'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Forgot your password?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
            ),
            const SizedBox(height: 32),
            if (!_sent) ...[
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (_emailCtrl.text.trim().isEmpty) return;
                        setState(() => _isLoading = true);
                        await ref
                            .read(authNotifierProvider.notifier)
                            .sendPasswordReset(_emailCtrl.text.trim());
                        if (mounted) setState(() { _sent = true; _isLoading = false; });
                      },
                child: _isLoading
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Send Reset Link'),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF43A047).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mark_email_read_outlined, color: Color(0xFF43A047), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Check your inbox!\n\nWe\'ve sent a reset link to ${_emailCtrl.text.trim()}. '
                        'Also check your spam folder.',
                        style: const TextStyle(color: Color(0xFF43A047), height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to Sign In'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Router Provider ───────────────────────────────────────────────────────────
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      // Still initializing — stay on splash
      if (authState.status == AuthStatus.initial) return '/splash';

      final isAuth = authState.isAuthenticated;
      final isOnAuthRoute = ['/login', '/register', '/forgot-password', '/splash']
          .any((r) => loc.startsWith(r));

      // Authenticated user on auth page → go home
      if (isAuth && isOnAuthRoute) return '/home';

      // Unauthenticated user on protected page → go login
      if (!isAuth && !isOnAuthRoute) return '/login';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

      // ── Main App Shell ────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => MainShell(navigationShell: shell),
        branches: [
          // Home
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const HomeScreen(),
              routes: [
                GoRoute(path: 'profile', builder: (_, __) => const ProfileScreen()),
                GoRoute(path: 'analytics', builder: (_, __) => const AnalyticsScreen()),
              ],
            ),
          ]),

          // Pantry
          StatefulShellBranch(routes: [
            GoRoute(path: '/pantry', builder: (_, __) => const PantryScreen()),
          ]),

          // Recipes
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/recipes',
              builder: (_, __) => const RecipesScreen(),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (ctx, state) {
                    final recipe = state.extra as Recipe;
                    return RecipeDetailScreen(recipe: recipe);
                  },
                ),
              ],
            ),
          ]),

          // Meal Plan
          StatefulShellBranch(routes: [
            GoRoute(path: '/meal-plan', builder: (_, __) => const MealPlanScreen()),
          ]),

          // Shopping
          StatefulShellBranch(routes: [
            GoRoute(path: '/shopping', builder: (_, __) => const ShoppingScreen()),
          ]),
        ],
      ),

      // Profile (accessible outside shell too)
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    ],

    errorBuilder: (ctx, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFE63946)),
            const SizedBox(height: 16),
            const Text(
              'Page not found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.toString() ?? 'Unknown error',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => GoRouter.of(ctx).go('/home'),
              icon: const Icon(Icons.home_rounded),
              label: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
