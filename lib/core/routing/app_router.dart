import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/hallaq_ui.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/auth_success_screen.dart';
import '../../features/auth/presentation/email_verification_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/auth_entry_screen.dart';
import '../../features/auth/presentation/account_suspended_screen.dart';
import '../../features/about/presentation/about_screen.dart';
import '../../features/awards/presentation/awards_screen.dart';
import '../../features/barber/presentation/barber_profile_screen.dart';
import '../../features/booking/presentation/new_booking_screen.dart';
import '../../features/booking/presentation/booking_details_screen.dart';
import '../../features/dashboard/presentation/admin_dashboard_screen.dart';
import '../../features/dashboard/presentation/barber_dashboard_screen.dart';
import '../../features/dashboard/presentation/barber_earnings_screen.dart';
import '../../features/dashboard/presentation/barber_manage_appointments_screen.dart';
import '../../features/dashboard/presentation/barber_manage_availability_screen.dart';
import '../../features/dashboard/presentation/barber_manage_before_after_screen.dart';
import '../../features/dashboard/presentation/barber_manage_portfolio_screen.dart';
import '../../features/dashboard/presentation/barber_manage_profile_screen.dart';
import '../../features/dashboard/presentation/barber_manage_services_screen.dart';
import '../../features/dashboard/presentation/barber_clients_screen.dart';
import '../../features/dashboard/presentation/barber_client_profile_screen.dart';
import '../../features/dashboard/presentation/barber_manage_offers_screen.dart';
import '../../features/dashboard/presentation/barber_my_reels_screen.dart';
import '../../features/dashboard/presentation/barber_qr_center_screen.dart';
import '../../features/dashboard/presentation/barber_reviews_screen.dart';
import '../../features/dashboard/presentation/barber_settings_screen.dart';
import '../../features/dashboard/presentation/shop_dashboard_screen.dart';
import '../../features/dashboard/presentation/barber_upload_reel_screen.dart';
import '../../features/dashboard/presentation/shop_analytics_screen.dart';
import '../../features/dashboard/presentation/shop_manage_barbers_screen.dart';
import '../../features/dashboard/presentation/shop_manage_bookings_screen.dart';
import '../../features/dashboard/presentation/shop_manage_gallery_screen.dart';
import '../../features/dashboard/presentation/shop_manage_offers_screen.dart';
import '../../features/dashboard/presentation/shop_manage_profile_screen.dart';
import '../../features/dashboard/presentation/shop_manage_reels_screen.dart';
import '../../features/dashboard/presentation/shop_manage_services_screen.dart';
import '../../features/dashboard/presentation/shop_activity_screen.dart';
import '../../features/dashboard/presentation/shop_qr_center_screen.dart';
import '../../features/dashboard/presentation/shop_settings_screen.dart';
import '../../features/dashboard/presentation/shop_upload_reel_screen.dart';
import '../../features/dashboard/presentation/shop_owner_shell.dart';
import '../../features/dashboard/presentation/shop_owner_tabs.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/reviews/presentation/reviews_screen.dart';
import '../../features/social_proof/presentation/bookings_info_screen.dart';
import '../../features/social_proof/presentation/followers_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/shop/presentation/shop_profile_screen.dart';
import '../../features/shop_claim/presentation/admin_create_shop_screen.dart';
import '../../features/shop_claim/presentation/admin_shop_claims_screen.dart';
import '../../features/shop_claim/presentation/shop_claim_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/history/presentation/haircut_history_screen.dart';
import '../../features/following/presentation/following_screen.dart';
import '../../features/offers/presentation/offers_screen.dart';
import '../../features/offers/presentation/my_offers_inbox_screen.dart';
import '../../features/city/presentation/style_barbers_screen.dart';
import '../../features/nearby/presentation/nearby_map_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/scan/presentation/scan_screen.dart';
import '../../features/payments/presentation/payment_methods_screen.dart';
import '../../features/profile/presentation/loyalty_history_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/membership_screen.dart';
import '../../features/profile/presentation/saved_screen.dart';
import '../../features/profile/presentation/addresses_screen.dart';
import '../../features/profile/presentation/my_reviews_screen.dart';
import '../../features/preview/presentation/preview_landing_screen.dart';
import '../../features/debug/presentation/debug_panel_screen.dart';
import '../../features/debug/presentation/build_health_screen.dart';
import '../../features/support/presentation/support_screen.dart';
import '../../features/settings/presentation/privacy_security_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/orders/presentation/checkout_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/orders/presentation/order_details_screen.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/products/presentation/shop_products_screen.dart';
import '../../features/products/presentation/shop_product_editor_screen.dart';
import '../../features/orders/presentation/shop_order_details_screen.dart';
import '../routing/go_router_refresh_stream.dart';
import '../routing/routes.dart';
import '../supabase/supabase_client_provider.dart';
import '../errors/user_facing_error.dart';
import '../models/role.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);

  final refresh = GoRouterRefreshStream(client.auth.onAuthStateChange);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) async {
      final session = authRepo.currentSession;
      final isAuthed = session != null;
      final isAuthRoute = state.matchedLocation.startsWith(Routes.auth);
      final isSplash = state.matchedLocation == Routes.splash;
      final allowAuthedAuthRoutes =
          state.matchedLocation == Routes.resetPassword || state.matchedLocation == Routes.authSuccess;
      final isPreview = state.uri.queryParameters['preview'] == '1' || state.matchedLocation == '/preview';
      final isPublicProfile =
          state.matchedLocation.startsWith('${Routes.barberProfile}/') || state.matchedLocation.startsWith('${Routes.shopProfile}/');
      final isBuildHealth = state.matchedLocation == Routes.buildHealth;

      if (isPreview) return null;
      if (isSplash) return null;
      if (isPublicProfile) return null;
      if (isBuildHealth) return null;
      if (!isAuthed && !isAuthRoute) return Routes.auth;
      if (isAuthed) {
        final gate = await profileRepo.getMyGateInfoFresh();
        final role = gate.role;
        final status = (gate.status ?? '').trim().toLowerCase();
        if (status == 'suspended' || status == 'banned') {
          await authRepo.signOut();
          return Routes.accountSuspended;
        }
        final home = _homeForRole(role);

        if (isAuthRoute && !allowAuthedAuthRoutes) return home;

        final isDashboardRoute = state.matchedLocation.startsWith('/dash') ||
            state.matchedLocation.startsWith(Routes.shopDashboardHome) ||
            state.matchedLocation.startsWith(Routes.barberDashboardHome) ||
            state.matchedLocation.startsWith(Routes.adminHome);
        final isAllowedDashboardRoute = switch (role) {
          AppUserRole.unknown => false,
          AppUserRole.customer => state.matchedLocation == Routes.root,
          AppUserRole.barber =>
            state.matchedLocation.startsWith(Routes.barberDashboard) || state.matchedLocation.startsWith(Routes.barberDashboardHome),
          AppUserRole.shopOwner =>
            state.matchedLocation.startsWith(Routes.shopDashboard) || state.matchedLocation.startsWith(Routes.shopDashboardHome),
          AppUserRole.admin => state.matchedLocation.startsWith(Routes.adminDashboard) || state.matchedLocation.startsWith(Routes.adminHome),
        };
        final isCustomerShellRoute = state.matchedLocation == Routes.root ||
            state.matchedLocation == '/home' ||
            state.matchedLocation == '/explore' ||
            state.matchedLocation == '/discover' ||
            state.matchedLocation == '/city' ||
            state.matchedLocation == '/bookings' ||
            state.matchedLocation == '/me';
        final isCustomerOnlyRoute = state.matchedLocation == Routes.cart ||
            state.matchedLocation == Routes.checkout ||
            state.matchedLocation == Routes.orders ||
            state.matchedLocation == Routes.products ||
            state.matchedLocation.startsWith('${Routes.orders}/');

        if (role == AppUserRole.customer) {
          if (isDashboardRoute) return Routes.root;
          return null;
        } else if (role == AppUserRole.unknown) {
          if (state.matchedLocation == Routes.completeProfile) return null;
          return Routes.completeProfile;
        } else {
          if (isCustomerShellRoute) return home;
          if (isCustomerOnlyRoute) return home;
          if (isDashboardRoute && !isAllowedDashboardRoute) return home;
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/preview', builder: (context, state) => const PreviewLandingScreen()),
      GoRoute(path: Routes.completeProfile, builder: (context, state) => const EditProfileScreen()),
      GoRoute(path: Routes.accountSuspended, builder: (context, state) => const AccountSuspendedScreen()),
      GoRoute(
        path: Routes.auth,
        builder: (context, state) => const AuthEntryScreen(),
        routes: [
          GoRoute(
            path: 'sign-in',
            pageBuilder: (context, state) => _authPage(state, const SignInScreen()),
          ),
          GoRoute(
            path: 'sign-up',
            pageBuilder: (context, state) => _authPage(state, const SignUpScreen()),
          ),
          GoRoute(
            path: 'verify-email',
            pageBuilder: (context, state) {
              final email = state.uri.queryParameters['email'] ?? '';
              return _authPage(state, EmailVerificationScreen(email: email));
            },
          ),
          GoRoute(
            path: 'success',
            pageBuilder: (context, state) => _authPage(state, const AuthSuccessScreen()),
          ),
          GoRoute(
            path: 'forgot-password',
            pageBuilder: (context, state) => _authPage(state, const ForgotPasswordScreen()),
          ),
          GoRoute(
            path: 'reset-password',
            pageBuilder: (context, state) => _authPage(state, const ResetPasswordScreen()),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: Routes.root,
            pageBuilder: (context, state) => const NoTransitionPage(child: AppShellHome()),
          ),
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(child: AppShellHome()),
          ),
          GoRoute(
            path: '/explore',
            redirect: (context, state) => '/discover${state.uri.hasQuery ? '?${state.uri.query}' : ''}',
          ),
          GoRoute(
            path: '/discover',
            pageBuilder: (context, state) => const NoTransitionPage(child: AppShellExplore()),
          ),
          GoRoute(
            path: '/city',
            pageBuilder: (context, state) => const NoTransitionPage(child: AppShellCity()),
          ),
          GoRoute(
            path: '/bookings',
            pageBuilder: (context, state) => const NoTransitionPage(child: AppShellBookings()),
          ),
          GoRoute(
            path: '/me',
            pageBuilder: (context, state) => const NoTransitionPage(child: AppShellProfile()),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => ShopOwnerShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.shopDashboardHome, builder: (context, state) => const ShopOwnerDashboardTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.shopDashboardBookings, builder: (context, state) => const ShopOwnerBookingsTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.shopDashboardBarbers, builder: (context, state) => const ShopOwnerBarbersTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.shopDashboardCustomers, builder: (context, state) => const ShopOwnerCustomersTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.shopDashboardMore, builder: (context, state) => const ShopOwnerMoreTab()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.shopDashboardServices, builder: (context, state) => const ShopOwnerServicesTab()),
            ],
          ),
        ],
      ),
      GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
      GoRoute(path: '/scan', builder: (context, state) => const ScanScreen()),
      GoRoute(path: Routes.settings, builder: (context, state) => const SettingsScreen()),
      GoRoute(
        path: Routes.debugPanel,
        builder: (context, state) {
          return Consumer(
            builder: (context, ref, _) {
              final profile = ref.watch(myProfileProvider).valueOrNull;
              if (profile?.role != AppUserRole.admin) {
                return Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  appBar: AppBar(title: const Text('Debug Panel')),
                  body: const Center(child: Text('Not authorized')),
                );
              }
              return const DebugPanelScreen();
            },
          );
        },
      ),
      GoRoute(path: Routes.buildHealth, builder: (context, state) => const BuildHealthScreen()),
      GoRoute(path: Routes.cart, builder: (context, state) => const CartScreen()),
      GoRoute(
        path: Routes.checkout,
        builder: (context, state) => CheckoutScreen(shopId: state.uri.queryParameters['shopId']),
      ),
      GoRoute(path: Routes.orders, builder: (context, state) => const OrdersScreen()),
      GoRoute(
        path: Routes.products,
        builder: (context, state) => ProductsScreen(shopId: state.uri.queryParameters['shopId']),
      ),
      GoRoute(
        path: '${Routes.orders}/:id',
        builder: (context, state) => OrderDetailsScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
      GoRoute(path: '/favorites', builder: (context, state) => const FavoritesScreen()),
      GoRoute(path: '/following', builder: (context, state) => const FollowingScreen()),
      GoRoute(path: '/payment-methods', builder: (context, state) => const PaymentMethodsScreen()),
      GoRoute(path: '/support', builder: (context, state) => const SupportScreen()),
      GoRoute(path: '/history', builder: (context, state) => const HaircutHistoryScreen()),
      GoRoute(path: '/points', builder: (context, state) => const LoyaltyHistoryScreen()),
      GoRoute(path: '/membership', builder: (context, state) => const MembershipScreen()),
      GoRoute(path: '/edit-profile', builder: (context, state) => const EditProfileScreen()),
      GoRoute(path: '/saved', builder: (context, state) => const SavedScreen()),
      GoRoute(path: '/addresses', builder: (context, state) => const AddressesScreen()),
      GoRoute(path: '/my-reviews', builder: (context, state) => const MyReviewsScreen()),
      GoRoute(path: '/privacy-security', builder: (context, state) => const PrivacySecurityScreen()),
      GoRoute(path: '/offers', builder: (context, state) => const OffersScreen()),
      GoRoute(path: '/offers/inbox', builder: (context, state) => const MyOffersInboxScreen()),
      GoRoute(
        path: '/style/:id',
        builder: (context, state) => StyleBarbersScreen(styleId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/nearby', builder: (context, state) => const NearbyMapScreen()),
      GoRoute(
        path: '${Routes.barberProfile}/:id',
        builder: (context, state) => BarberProfileScreen(ref: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${Routes.shopProfile}/:id',
        builder: (context, state) => ShopProfileScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${Routes.shopProfile}/:id/claim',
        builder: (context, state) => ShopClaimScreen(shopId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.bookingNew,
        builder: (context, state) => NewBookingScreen(
          barberId: state.uri.queryParameters['barberId'],
          shopId: state.uri.queryParameters['shopId'],
          serviceId: state.uri.queryParameters['serviceId'],
          sourcePostId: state.uri.queryParameters['postId'] ?? state.uri.queryParameters['sourcePostId'],
          reelId: state.uri.queryParameters['reelId'],
          offerId: state.uri.queryParameters['offerId'],
          source: state.uri.queryParameters['source'],
          bookAgain: state.uri.queryParameters['bookAgain'] == '1',
        ),
      ),
      GoRoute(
        path: '/booking/:id',
        builder: (context, state) => BookingDetailsScreen(
          bookingId: state.pathParameters['id']!,
          autoOpenReschedule: state.uri.queryParameters['openReschedule'] == '1',
        ),
      ),
      GoRoute(path: Routes.awards, builder: (context, state) => const AwardsScreen()),
      GoRoute(path: Routes.about, builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: Routes.reviews,
        builder: (context, state) => ReviewsScreen(
          targetType: state.uri.queryParameters['targetType'] ?? 'barber',
          targetId: state.uri.queryParameters['targetId'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.followers,
        builder: (context, state) => FollowersScreen(
          targetType: state.uri.queryParameters['targetType'] ?? 'barber',
          targetId: state.uri.queryParameters['targetId'] ?? '',
        ),
      ),
      GoRoute(
        path: Routes.bookingsInfo,
        builder: (context, state) => BookingsInfoScreen(
          barberId: state.uri.queryParameters['barberId'],
          shopId: state.uri.queryParameters['shopId'],
        ),
      ),
      GoRoute(path: Routes.barberDashboard, builder: (context, state) => const BarberDashboardScreen()),
      GoRoute(path: Routes.barberDashboardHome, builder: (context, state) => const BarberDashboardScreen()),
      GoRoute(path: Routes.barberManageProfile, builder: (context, state) => const BarberManageProfileScreen()),
      GoRoute(path: Routes.barberManagePortfolio, builder: (context, state) => const BarberManagePortfolioScreen()),
      GoRoute(path: Routes.barberManageBeforeAfter, builder: (context, state) => const BarberManageBeforeAfterScreen()),
      GoRoute(path: Routes.barberUploadReel, builder: (context, state) => BarberUploadReelScreen(draftId: state.uri.queryParameters['draftId'])),
      GoRoute(path: Routes.barberManageAppointments, builder: (context, state) => const BarberManageAppointmentsScreen()),
      GoRoute(path: Routes.barberManageServices, builder: (context, state) => const BarberManageServicesScreen()),
      GoRoute(path: Routes.barberManageAvailability, builder: (context, state) => const BarberManageAvailabilityScreen()),
      GoRoute(path: Routes.barberManageEarnings, builder: (context, state) => const BarberEarningsScreen()),
      GoRoute(path: Routes.barberManageMyReels, builder: (context, state) => const BarberMyReelsScreen()),
      GoRoute(path: Routes.barberManageReviews, builder: (context, state) => const BarberReviewsScreen()),
      GoRoute(path: Routes.barberManageSettings, builder: (context, state) => const BarberSettingsScreen()),
      GoRoute(path: Routes.barberManageClients, builder: (context, state) => const BarberClientsScreen()),
      GoRoute(
        path: '${Routes.barberManageClients}/:id',
        builder: (context, state) => BarberClientProfileScreen(customerProfileId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.barberManageOffers, builder: (context, state) => const BarberManageOffersScreen()),
      GoRoute(path: Routes.barberQrCenter, builder: (context, state) => const BarberQrCenterScreen()),
      GoRoute(path: Routes.shopDashboard, builder: (context, state) => const ShopDashboardScreen()),
      GoRoute(path: Routes.shopManageProfile, builder: (context, state) => const ShopManageProfileScreen()),
      GoRoute(path: Routes.shopManageGallery, builder: (context, state) => const ShopManageGalleryScreen()),
      GoRoute(path: Routes.shopManageBarbers, builder: (context, state) => const ShopManageBarbersScreen()),
      GoRoute(path: Routes.shopManageBookings, builder: (context, state) => const ShopManageBookingsScreen()),
      GoRoute(path: Routes.shopManageServices, builder: (context, state) => const ShopManageServicesScreen()),
      GoRoute(path: Routes.shopManageProducts, builder: (context, state) => const ShopProductsScreen()),
      GoRoute(path: '${Routes.shopManageProducts}/new', builder: (context, state) => const ShopProductEditorScreen()),
      GoRoute(
        path: '${Routes.shopManageProducts}/:id',
        builder: (context, state) => ShopProductEditorScreen(productId: state.pathParameters['id']),
      ),
      GoRoute(path: Routes.shopManageReels, builder: (context, state) => const ShopManageReelsScreen()),
      GoRoute(path: Routes.shopUploadReel, builder: (context, state) => const ShopUploadReelScreen()),
      GoRoute(path: Routes.shopManageOffers, builder: (context, state) => const ShopManageOffersScreen()),
      GoRoute(path: Routes.shopManageAnalytics, builder: (context, state) => const ShopAnalyticsScreen()),
      GoRoute(path: Routes.shopManageSettings, builder: (context, state) => const ShopSettingsScreen()),
      GoRoute(path: Routes.shopQrCenter, builder: (context, state) => const ShopQrCenterScreen()),
      GoRoute(path: Routes.shopActivity, builder: (context, state) => const ShopActivityScreen()),
      GoRoute(
        path: '${Routes.shopOrderDetails}/:id',
        builder: (context, state) => ShopOrderDetailsScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.adminDashboard, builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: Routes.adminHome, builder: (context, state) => const AdminDashboardScreen()),
      GoRoute(path: Routes.adminShopClaims, builder: (context, state) => const AdminShopClaimsScreen()),
      GoRoute(path: Routes.adminCreateShop, builder: (context, state) => const AdminCreateShopScreen()),
    ],
    errorBuilder: (context, state) {
      final msg = state.error == null ? 'We could not open this page.' : userFacingMessage(context, state.error!);
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: HallaqEmptyState(
                  title: 'Something went wrong',
                  description: msg,
                  compact: true,
                  showMascot: true,
                  actionLabel: 'Go Home',
                  onAction: () => context.go('/home'),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  ref.listen(authStateChangesProvider, (_, __) => profileRepo.clearRoleCache());
  ref.listen(myProfileProvider, (_, __) => router.refresh());

  return router;
});

String _homeForRole(AppUserRole role) {
  switch (role) {
    case AppUserRole.unknown:
      return Routes.completeProfile;
    case AppUserRole.customer:
      return '/home';
    case AppUserRole.barber:
      return Routes.barberDashboardHome;
    case AppUserRole.shopOwner:
      return Routes.shopDashboardHome;
    case AppUserRole.admin:
      return Routes.adminHome;
  }
}

CustomTransitionPage<void> _authPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.02, 0.02), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}
