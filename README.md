# Gestion de stock et de ventes

Application Flutter (Android + iOS) de gestion de stock et de ventes pour un
petit commerçant — **un seul utilisateur, 100 % hors-ligne**, bilingue
**Arabe (RTL) / Français**.

> État actuel : **Phase 7 — Rapports** ✅ livrée. Au socle déjà en place
> (schéma et calculs exacts, couche données Drift, authentification hors-ligne,
> catalogue, ventes, ticket) s'ajoutent les **rapports** : agrégats **jour /
> semaine / mois / période**, **tableau de bord `fl_chart`** et **PDF A4
> multi-pages** partageable. Les modules suivants (import/export…)
> viendront phase par phase (voir [Feuille de route](#6-feuille-de-route)).

---

## 1. Architecture

Séparation stricte en couches (Repository pattern), état géré par Riverpod :

```
UI (features/*)  →  Providers Riverpod  →  Repositories (contrats)
                                              ↓
                                   Implementations Drift (DAO)
                                              ↓
                                    Base locale SQLite / SQLCipher
                           Objets-valeurs du noyau : Money, Qty (précision entière)
```

Principes appliqués :

- **Zéro `double` en finance** : tous les montants sont des entiers en
  **millimes** (`Money`), toutes les quantités en **milli-unités** (`Qty`).
  `2,5 kg` = `2500`, `3,450 D` = `3450`. Les calculs sont donc exacts.
- **Journal de stock immuable** : `stock_movements` est en ajout seul et fait
  foi ; `products.quantityOnHand` n'est qu'un cache recalculable (audit).
- **Aucune chaîne en dur** : tous les textes passent par les fichiers ARB
  (`lib/l10n/app_fr.arb`, `lib/l10n/app_ar.arb`).
- Chiffrement de la base (SQLCipher / AES-256) activable via `PRAGMA key`.

## 2. Structure du projet

```
lib/
├── core/                         # Noyau sans dépendance UI
│   ├── barcode/barcode_generator.dart   # EAN-13 / Code128 + validation
│   ├── constants/app_constants.dart
│   ├── errors/failures.dart             # AppFailure (codes traduisibles)
│   ├── money/money.dart                 # Money (entiers, millimes)
│   ├── money/money_formatter.dart       # Formatage localisé (intl)
│   ├── quantity/quantity.dart           # Qty (entiers, milli-unités)
│   ├── pdf/                             # PDF partagé : capture widget, ticket, rapport A4, partage
│   ├── printing/                        # Ticket : ESC/POS 58/80 mm (arabe en bitmap)
│   └── security/
│       ├── password_hasher.dart         # PBKDF2-HMAC-SHA256 + code de récupération
│       └── biometric_authenticator.dart # Abstraction biométrie (+ impl local_auth)
├── domain/                       # Règles métier pures (testables)
│   ├── entities/                        # Entités du domaine
│   │   ├── catalog.dart                 # Category, Supplier, Product
│   │   ├── cart_line.dart               # CartLine + CartTotals (panier)
│   │   ├── sale.dart                    # Sale, SaleItem, SaleDraft, SalesSummary
│   │   ├── report.dart                  # ReportPeriod, ProductSales, DailySales, ReportData
│   │   ├── purchase.dart                # Purchase, PurchaseItem, brouillons
│   │   ├── stock_movement.dart          # StockMovement (journal)
│   │   ├── user.dart                    # AppUser, UserRegistration
│   │   └── app_settings.dart            # AppSettings (paramètres)
│   ├── enums/enums.dart                 # SaleMode, StockMovementType, ...
│   ├── repositories/                    # Contrats (interfaces) des dépôts
│   ├── services/pricing.dart            # PricingContext, MarginCalculator
│   ├── services/report_builder.dart     # Agrégation des rapports (fonction pure)
│   ├── services/stock_calculator.dart   # Solde, statut, valeur du stock
│   └── units/units.dart                 # PackagingConfig, UnitConverter
├── data/
│   ├── local/                    # Persistance Drift
│   │   ├── connection.dart              # Ouverture SQLite/SQLCipher
│   │   ├── converters.dart              # Money/Qty ↔ entiers SQL
│   │   ├── database.dart                # AppDatabase (@DriftDatabase)
│   │   ├── mappers/                     # Lignes Drift ↔ entités du domaine
│   │   └── tables/                      # Les 10 tables du schéma
│   │       ├── users_table.dart
│   │       ├── catalog_tables.dart      # categories, suppliers, products
│   │       ├── purchase_tables.dart     # purchases, purchase_items
│   │       ├── sale_tables.dart         # sales, sale_items
│   │       ├── stock_movement_table.dart
│   │       └── settings_table.dart
│   └── repositories/                    # Implémentations Drift des dépôts
├── app/                          # Coquille d'application
│   ├── app.dart                         # MaterialApp.router (thème, langue, RTL)
│   ├── router/app_router.dart           # go_router + garde d'authentification
│   ├── theme/app_theme.dart             # thèmes clair / sombre (Material 3)
│   ├── l10n/failure_messages.dart       # FailureCode → clés ARB
│   ├── providers/                       # Providers Riverpod (base, dépôts, auth, paramètres, catalogue, ventes, rapports)
├── features/                     # Interface, une fonctionnalité par dossier
│   ├── splash/presentation/             # écran d'attente
│   ├── auth/presentation/               # 1er accès, code de récupération, connexion, mot de passe oublié
│   ├── catalog/presentation/            # catalogue : 3 onglets
│   │   ├── catalog_screen.dart          # produits / catégories / fournisseurs
│   │   ├── products_view.dart           # recherche, filtres, liste, suppression
│   │   ├── product_form_screen.dart     # création / édition (stock initial, carton/sac, marge)
│   │   ├── categories_view.dart + category_form_sheet.dart
│   │   ├── suppliers_view.dart + supplier_form_sheet.dart  # appel direct (`tel:`)
│   │   ├── barcode_scanner_screen.dart  # scan caméra (mobile_scanner)
│   │   ├── catalog_helpers.dart         # analyse / formatage sans `double`
│   │   └── widgets/                     # product_tile, stock_status_chip, états, dialogue
│   ├── sales/presentation/              # ventes : panier et encaissement
│   │   ├── sales_screen.dart            # ventes du jour
│   │   ├── sale_cart_screen.dart        # panier, mode de vente, remise, encaissement
│   │   ├── sale_detail_screen.dart      # détail d'une vente + annulation
│   │   ├── sale_ticket_screen.dart      # aperçu du ticket + impression / PDF
│   │   ├── sales_helpers.dart           # libellés / formatages propres aux ventes
│   │   └── widgets/                     # sale_tile, cart_line_tile, cart_line_editor, product_picker_sheet
│   ├── reports/presentation/            # rapports de ventes + tableau de bord
│   │   └── reports_screen.dart          # période (jour/semaine/mois/custom) + fl_chart + partage PDF
│   └── home/presentation/               # accueil (post-authentification) + accès ventes / catalogue / rapports
├── l10n/                         # app_fr.arb / app_ar.arb (+ generated/ par gen-l10n)
└── main.dart                     # point d'entrée (ProviderScope)
```

## 3. Packages principaux

| Domaine | Packages |
|---|---|
| État | `flutter_riverpod`, `riverpod_annotation` (+ `riverpod_generator`) |
| Navigation | `go_router` |
| Base locale | `drift`, `sqlite3`, `sqlcipher_flutter_libs`, `path_provider` |
| Sécurité | `cryptography` (PBKDF2), `flutter_secure_storage`, `local_auth` |
| Codes-barres | `mobile_scanner`, `barcode`, `barcode_widget` |
| Impression thermique | `print_bluetooth_thermal`, `esc_pos_utils_plus`, `image` |
| PDF / partage | `pdf`, `printing`, `share_plus` |
| Graphiques | `fl_chart` |
| Fichiers | `file_picker`, `csv`, `excel`, `image_picker`, `url_launcher` |
| Notifications | `flutter_local_notifications`, `timezone` |
| Divers | `uuid`, `collection`, `equatable`, `logger`, `intl` |

## 4. Schéma de base de données

| Table | Rôle | Points clés |
|---|---|---|
| `users` | Utilisateur unique | `passwordHash` + sel (PBKDF2), code de récupération (+ sel) et question secrète hachés ; verrouillage de la question secrète (`secretAnswerFailures`, `secretAnswerLockLevel`, `secretAnswerLockedUntil`) |
| `categories` | Catégories | `name` unique ; suppression bloquée si produits liés (`ON DELETE RESTRICT`) |
| `suppliers` | Fournisseurs | `companyName`, `phone`, `notes` |
| `products` | Produits | `barcode` unique, unité de base, `piecesPerCarton`, `kgPerSackMilli`, 3 prix, seuil d'alerte |
| `purchases` / `purchase_items` | Achats / réapprovisionnements | Historique d'achat par fournisseur |
| `sales` / `sale_items` | Ventes | mode détail/gros, remise, coût, bénéfice, annulation |
| `stock_movements` | **Journal immuable** | `type`, `quantity` (signée pour `adjustment`), `balanceAfter`, référence vente/achat |
| `settings` | Paramètres (ligne unique) | langue, thème, devise, magasin, imprimante, chiffrement |

Détails et contraintes : voir les fichiers sous `lib/data/local/tables/`.

## 5. Commandes

```bash
flutter create . --platforms=android,ios   # 1) générer les dossiers natifs (une seule fois)
flutter pub get                            # 2) dépendances
dart run build_runner build --delete-conflicting-outputs   # 3) drift + riverpod
flutter gen-l10n                           # 4) traductions (ARB → lib/l10n/generated)
flutter analyze                            # 5) vérification statique (doit être sans avertissement)
flutter test                               # 6) tests (calculs, repositories, widgets)
flutter run                                # 7) lancer sur appareil/émulateur
```

> `AppDatabase` a besoin de `database.g.dart` (généré par `build_runner`) et les
> écrans d'`AppLocalizations` (généré par `gen-l10n`) : **lancez les étapes 3 et
> 4 avant les tests**, car `test/data/` vérifie les repositories sur une base en
> mémoire et `test/features/` monte des écrans traduits.

Configuration Android/iOS (permissions caméra, Bluetooth, notifications,
biométrie) : **[docs/BUILD_AND_SETUP.md](docs/BUILD_AND_SETUP.md)**.

## 6. Feuille de route

| Phase | Contenu | Statut |
|---|---|---|
| 1 | Fondations : structure, schéma, noyau de calculs + tests | ✅ livré |
| 2 | Couche données : entités, mappers, contrats + implémentations Drift, providers Riverpod, tests d'intégration | ✅ livré |
| 3 | Authentification (email/mot de passe haché, biométrie, récupération hors-ligne) | ✅ livré |
| 4 | Catégories, Fournisseurs, Produits (CRUD, scanner, génération de code-barres) | ✅ livré |
| 5 | Ventes : panier, modes détail/gros, validation, déstockage, annulation | ✅ livré |
| 6 | Ticket : aperçu, impression ESC/POS 58/80 mm (arabe en bitmap), PDF partageable | ✅ livré |
| 7 | Rapports PDF (jour/semaine/mois/période) + tableau de bord (fl_chart) | ✅ livré |
| 8 | Import/Export codes-barres (CSV/Excel/PDF) + planches d'étiquettes | à venir |
| 9 | Paramètres, sauvegarde/restauration, chiffrement de la base | à venir |
| 10 | Notifications d'alerte de stock, thème clair/sombre, UI RTL complète | à venir |

## 7. Règles d'authentification et de récupération

- **Mot de passe** : PBKDF2-HMAC-SHA256, sel aléatoire par secret, comparaison à
  temps constant. Jamais stocké en clair.
- **Code de récupération** : généré à la création du compte puis affiché **une
  seule fois** ; utilisable **seul**, **sans limitation** d'essais.
- **Question secrète** : utilisable **seule** mais limitée à **5 essais**, puis
  **blocage temporaire de 15 min**, **doublé** à chaque nouvelle série d'échecs
  (15 → 30 → 60 min…). L'état (compteur, niveau, date de déblocage) est
  **persisté en base** et remis à zéro après une réussite, un changement de mot
  de passe ou une régénération du code.
- **Régénération du code** (depuis les paramètres) : exige le **mot de passe
  courant**, puis remplace l'ancien code et lève tout blocage résiduel.
- **Flux UI** : 1er accès → affichage unique du code → connexion ; en cas
  d'oubli, récupération par **code** *ou* **question secrète**, puis nouveau mot
  de passe. La garde du routeur (`go_router`) impose l'écran pertinent selon
  l'état (`needsSetup`, `awaitingRecoveryConfirmation`, `locked`,
  `authenticated`).
