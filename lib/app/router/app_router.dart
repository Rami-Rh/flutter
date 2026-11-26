import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/catalog.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/recovery_code_screen.dart';
import '../../features/auth/presentation/setup_screen.dart';
import '../../features/catalog/presentation/barcode_scanner_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/catalog/presentation/product_form_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/sales/presentation/sale_cart_screen.dart';
import '../../features/sales/presentation/sale_detail_screen.dart';
import '../../features/sales/presentation/sale_ticket_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../providers/auth_providers.dart';

/// Chemins de navigation de l'application (source unique de vérité).
abstract final class AppRoutes {
  /// Écran d'attente affiché pendant la lecture de l'état d'authentification.
  static const String splash = '/splash';

  /// Configuration du premier accès (création du compte).
  static const String setup = '/setup';

  /// Affichage unique du code de récupération, juste après la création.
  static const String recoveryCode = '/setup/recovery-code';

  /// Connexion (mot de passe ou biométrie).
  static const String login = '/login';

  /// Récupération du mot de passe (code **ou** question secrète).
  static const String forgotPassword = '/forgot-password';

  /// Écran d'accueil (application déverrouillée).
  static const String home = '/home';

  /// Catalogue : produits, catégories et fournisseurs (trois onglets).
  static const String catalog = '/catalog';

  /// Création d'un produit.
  static const String productNew = '/catalog/product/new';

  /// Modèle de route d'édition d'un produit (le produit est passé en `extra`).
  static const String productEditPattern = '/catalog/product/:id';

  /// Scan d'un code-barres ; renvoie le code lu via `pop`.
  static const String barcodeScanner = '/catalog/scan';

  /// Ventes du jour (point d'entrée du module Ventes).
  static const String sales = '/sales';

  /// Composition d'une nouvelle vente.
  static const String saleNew = '/sales/new';

  /// Modèle de route du détail d'une vente.
  static const String saleDetailPattern = '/sales/:id';

  /// Modèle de route du ticket d'une vente (aperçu, impression, PDF).
  static const String saleTicketPattern = '/sales/:id/ticket';

  /// Rapports de ventes + tableau de bord (jour/semaine/mois/période).
  static const String reports = '/reports';

  /// Chemin d'édition d'un produit donné.
  static String productEditPath(int id) => '/catalog/product/$id';

  /// Chemin du détail d'une vente donnée.
  static String saleDetailPath(int id) => '/sales/$id';

  /// Chemin du ticket d'une vente donnée.
  static String saleTicketPath(int id) => '/sales/$id/ticket';

  /// Routes accessibles uniquement lorsque la session est verrouillée.
  static const Set<String> guestRoutes = <String>{login, forgotPassword};

  /// Toutes les routes « hors application » (avant l'ouverture de session).
  static const Set<String> unauthenticatedRoutes = <String>{
    splash,
    setup,
    recoveryCode,
    login,
    forgotPassword,
  };
}

/// Routeur applicatif, construit une seule fois par [ProviderScope].
///
/// La garde d'authentification redirige vers l'écran pertinent selon
/// [AuthController] : configuration du compte, confirmation du code de
/// récupération, verrouillage de la session ou application ouverte.
final Provider<GoRouter> routerProvider = Provider<GoRouter>(
  (Ref ref) {
    final _RouterRefresh refresh = _RouterRefresh();
    ref.onDispose(refresh.dispose);
    ref.listen<AsyncValue<AuthState>>(
      authControllerProvider,
      (AsyncValue<AuthState>? previous, AsyncValue<AuthState> next) =>
          refresh.notify(),
    );

    return GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: refresh,
      redirect: (BuildContext context, GoRouterState state) {
        final AuthState? current = ref.read(authControllerProvider).valueOrNull;
        final String location = state.matchedLocation;

        // État pas encore connu : on patiente sur l'écran d'attente.
        if (current == null) {
          return location == AppRoutes.splash ? null : AppRoutes.splash;
        }

        switch (current.status) {
          case AuthStatus.needsSetup:
            return location == AppRoutes.setup ? null : AppRoutes.setup;
          case AuthStatus.awaitingRecoveryConfirmation:
            return location == AppRoutes.recoveryCode
                ? null
                : AppRoutes.recoveryCode;
          case AuthStatus.locked:
            return AppRoutes.guestRoutes.contains(location)
                ? null
                : AppRoutes.login;
          case AuthStatus.authenticated:
            return AppRoutes.unauthenticatedRoutes.contains(location)
                ? AppRoutes.home
                : null;
        }
      },
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.splash,
          builder: (BuildContext context, GoRouterState state) =>
              const SplashScreen(),
        ),
        GoRoute(
          path: AppRoutes.setup,
          builder: (BuildContext context, GoRouterState state) =>
              const SetupScreen(),
        ),
        GoRoute(
          path: AppRoutes.recoveryCode,
          builder: (BuildContext context, GoRouterState state) =>
              const RecoveryCodeScreen(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (BuildContext context, GoRouterState state) =>
              const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (BuildContext context, GoRouterState state) =>
              const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: AppRoutes.catalog,
          builder: (BuildContext context, GoRouterState state) =>
              const CatalogScreen(),
        ),
        GoRoute(
          path: AppRoutes.productNew,
          builder: (BuildContext context, GoRouterState state) =>
              const ProductFormScreen.create(),
        ),
        GoRoute(
          path: AppRoutes.productEditPattern,
          builder: (BuildContext context, GoRouterState state) =>
              ProductFormScreen.edit(state.extra! as Product),
        ),
        GoRoute(
          path: AppRoutes.barcodeScanner,
          builder: (BuildContext context, GoRouterState state) =>
              const BarcodeScannerScreen(),
        ),
        GoRoute(
          path: AppRoutes.sales,
          builder: (BuildContext context, GoRouterState state) =>
              const SalesScreen(),
        ),
        GoRoute(
          path: AppRoutes.saleNew,
          builder: (BuildContext context, GoRouterState state) =>
              const SaleCartScreen(),
        ),
        GoRoute(
          path: AppRoutes.saleDetailPattern,
          builder: (BuildContext context, GoRouterState state) =>
              SaleDetailScreen(saleId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(
          path: AppRoutes.saleTicketPattern,
          builder: (BuildContext context, GoRouterState state) =>
              SaleTicketScreen(saleId: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(
          path: AppRoutes.reports,
          builder: (BuildContext context, GoRouterState state) =>
              const ReportsScreen(),
        ),
      ],
    );
  },
);

/// Pont [ChangeNotifier] pour `refreshListenable` de go_router.
class _RouterRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}
