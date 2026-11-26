import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_stock/core/money/money.dart';
import 'package:gestion_stock/domain/entities/catalog.dart';
import 'package:gestion_stock/domain/repositories/category_repository.dart';
import 'package:gestion_stock/domain/repositories/product_repository.dart';
import 'package:gestion_stock/domain/repositories/supplier_repository.dart';
import 'package:gestion_stock/domain/units/units.dart';
import 'package:gestion_stock/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

/// Dépôts du catalogue espionnés (aucun accès base dans les tests d'interface).
class MockCategoryRepository extends Mock implements CategoryRepository {}

/// Voir [MockCategoryRepository].
class MockSupplierRepository extends Mock implements SupplierRepository {}

/// Voir [MockCategoryRepository].
class MockProductRepository extends Mock implements ProductRepository {}

/// Produit neutre servant de valeur de repli aux matchers `any()` / `captureAny()`.
final Product sampleProduct = Product(
  id: 1,
  name: 'Produit',
  barcode: '2000000000000',
  packaging: PackagingConfig.pieces(),
  purchasePrice: Money.zero,
  retailPrice: Money.zero,
  wholesalePrice: Money.zero,
);

/// Monte un écran du catalogue isolé, en français, avec les traductions.
Future<void> pumpCatalogScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const <Override>[],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Monte [screen] par-dessus un écran neutre, afin que `Navigator.pop`
/// (fermeture après enregistrement) se comporte comme en navigation réelle.
Future<void> pumpPushedScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const <Override>[],
}) async {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  unawaited(
    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
