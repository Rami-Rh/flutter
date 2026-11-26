import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/drift_category_repository.dart';
import '../../data/repositories/drift_product_repository.dart';
import '../../data/repositories/drift_purchase_repository.dart';
import '../../data/repositories/drift_sale_repository.dart';
import '../../data/repositories/drift_settings_repository.dart';
import '../../data/repositories/drift_stock_repository.dart';
import '../../data/repositories/drift_supplier_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/stock_repository.dart';
import '../../domain/repositories/supplier_repository.dart';
import 'database_providers.dart';

/// Repositories exposés à l'interface sous forme de contrats du domaine.
///
/// Les implémentations Drift dépendent de [databaseProvider] ; les tests
/// peuvent surcharger chaque provider par une implémentation factice.

final Provider<CategoryRepository> categoryRepositoryProvider =
    Provider<CategoryRepository>(
  (Ref ref) => DriftCategoryRepository(ref.watch(databaseProvider)),
  name: 'categoryRepositoryProvider',
);

final Provider<SupplierRepository> supplierRepositoryProvider =
    Provider<SupplierRepository>(
  (Ref ref) => DriftSupplierRepository(ref.watch(databaseProvider)),
  name: 'supplierRepositoryProvider',
);

final Provider<ProductRepository> productRepositoryProvider =
    Provider<ProductRepository>(
  (Ref ref) => DriftProductRepository(ref.watch(databaseProvider)),
  name: 'productRepositoryProvider',
);

final Provider<StockRepository> stockRepositoryProvider =
    Provider<StockRepository>(
  (Ref ref) => DriftStockRepository(ref.watch(databaseProvider)),
  name: 'stockRepositoryProvider',
);

final Provider<SaleRepository> saleRepositoryProvider =
    Provider<SaleRepository>(
  (Ref ref) => DriftSaleRepository(ref.watch(databaseProvider)),
  name: 'saleRepositoryProvider',
);

final Provider<PurchaseRepository> purchaseRepositoryProvider =
    Provider<PurchaseRepository>(
  (Ref ref) => DriftPurchaseRepository(ref.watch(databaseProvider)),
  name: 'purchaseRepositoryProvider',
);

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
  (Ref ref) => DriftSettingsRepository(ref.watch(databaseProvider)),
  name: 'settingsRepositoryProvider',
);
