import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n/failure_messages.dart';
import '../../../app/providers/catalog_providers.dart';
import '../../../app/providers/settings_providers.dart';
import '../../../app/router/app_router.dart';
import '../../../core/barcode/barcode_generator.dart';
import '../../../core/money/money.dart';
import '../../../core/quantity/quantity.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/catalog.dart';
import '../../../domain/enums/enums.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'catalog_helpers.dart';

/// Valeur sentinelle des menus « catégorie / fournisseur » (aucune sélection).
const int _noneSelected = -1;

/// Formulaire de création / modification d'un produit.
///
/// Le stock n'est **pas** modifiable ici (il découle du journal des mouvements) ;
/// seule la quantité initiale est saisissable à la création.
class ProductFormScreen extends ConsumerStatefulWidget {
  /// Création d'un produit.
  const ProductFormScreen.create({super.key}) : product = null;

  /// Modification d'un produit existant.
  const ProductFormScreen.edit(this.product, {super.key});

  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _purchase;
  late final TextEditingController _retail;
  late final TextEditingController _wholesale;
  late final TextEditingController _threshold;
  late final TextEditingController _initialStock;
  late final TextEditingController _piecesPerCarton;
  late final TextEditingController _kgPerSack;

  late StockBaseUnit _baseUnit;
  late bool _soldByCarton;
  late bool _soldBySack;
  late bool _isActive;

  int? _categoryId;
  int? _supplierId;

  bool _submitting = false;
  bool _generating = false;
  String? _error;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final Product? product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _barcode = TextEditingController(text: product?.barcode ?? '');
    _purchase = TextEditingController(text: _moneyText(product?.purchasePrice));
    _retail = TextEditingController(text: _moneyText(product?.retailPrice));
    _wholesale = TextEditingController(text: _moneyText(product?.wholesalePrice));
    _threshold = TextEditingController(text: _qtyText(product?.lowStockThreshold));
    _initialStock = TextEditingController();
    _piecesPerCarton = TextEditingController(
      text: product?.packaging.piecesPerCarton?.toString() ?? '',
    );
    _kgPerSack = TextEditingController(
      text: product?.packaging.kgPerSack?.toString() ?? '',
    );
    _baseUnit = product?.packaging.baseUnit ?? StockBaseUnit.piece;
    _soldByCarton = product?.packaging.hasCarton ?? false;
    _soldBySack = product?.packaging.hasSack ?? false;
    _isActive = product?.isActive ?? true;
    _categoryId = product?.categoryId;
    _supplierId = product?.supplierId;
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _purchase.dispose();
    _retail.dispose();
    _wholesale.dispose();
    _threshold.dispose();
    _initialStock.dispose();
    _piecesPerCarton.dispose();
    _kgPerSack.dispose();
    super.dispose();
  }

  static String _moneyText(Money? money) =>
      money == null ? '' : money.toDecimal().toString();

  static String _qtyText(Qty? quantity) {
    if (quantity == null || quantity.isZero) return '';
    return quantity.toDecimal().toString();
  }

  // --- Validation -----------------------------------------------------------

  String? _validateName(String? value) =>
      (value == null || value.trim().isEmpty)
          ? AppLocalizations.of(context).validationRequired
          : null;

  String? _validateBarcode(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final BarcodeFormat? format = BarcodeValidator.detectFormat(text);
    return format == null
        ? AppLocalizations.of(context).validationBarcodeInvalid
        : null;
  }

  String? _validateMoney(String? value, {required bool isRequired}) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (value == null || value.trim().isEmpty) {
      return isRequired ? l10n.validationRequired : null;
    }
    final Money? money = parseMoney(value);
    if (money == null) return l10n.validationNumberInvalid;
    if (money.isNegative) return l10n.validationPositiveNumber;
    return null;
  }

  String? _validateOptionalQuantity(String? value) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (value == null || value.trim().isEmpty) return null;
    final Qty? quantity = parseQuantity(value, _baseUnit);
    if (quantity == null) return l10n.validationNumberInvalid;
    if (quantity.isNegative) return l10n.validationPositiveNumber;
    return null;
  }

  String? _validatePositiveInt(String? value) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? parsed = parseIntValue(value ?? '');
    if (parsed == null || parsed <= 0) return l10n.validationNumberInvalid;
    return null;
  }

  String? _validatePositiveDecimal(String? value) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final num? parsed = parseDecimal(value ?? '');
    if (parsed == null || parsed <= 0) return l10n.validationNumberInvalid;
    return null;
  }

  // --- Actions --------------------------------------------------------------

  Future<void> _scan() async {
    final String? code = await context.push<String>(AppRoutes.barcodeScanner);
    if (!mounted || code == null) return;
    setState(() => _barcode.text = code);
  }

  Future<void> _generate() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final String code = await ref
          .read(catalogControllerProvider)
          .generateBarcode(currentBarcode: widget.product?.barcode);
      if (!mounted) return;
      setState(() {
        _barcode.text = code;
        _generating = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = failureMessage(l10n, error);
        _generating = false;
      });
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final Money? purchase = parseMoney(_purchase.text);
    final Money? retail = parseMoney(_retail.text);
    final Money? wholesale = parseMoney(_wholesale.text);
    if (purchase == null || retail == null) {
      setState(() => _error = l10n.validationNumberInvalid);
      return;
    }

    final PackagingConfig packaging = _baseUnit == StockBaseUnit.piece
        ? PackagingConfig.pieces(
            piecesPerCarton: _soldByCarton
                ? parseIntValue(_piecesPerCarton.text)
                : null,
          )
        : PackagingConfig.kilograms(
            kgPerSack: _soldBySack ? parseDecimal(_kgPerSack.text) : null,
          );

    final String barcode = _barcode.text.trim();
    final Product product = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      barcode: barcode.isEmpty && _isEditing
          ? widget.product!.barcode
          : barcode,
      categoryId: _categoryId,
      supplierId: _supplierId,
      packaging: packaging,
      quantityOnHand: widget.product?.quantityOnHand ??
          (parseQuantity(_initialStock.text, _baseUnit) ?? Qty.zero),
      purchasePrice: purchase,
      retailPrice: retail,
      wholesalePrice: wholesale ?? retail,
      lowStockThreshold:
          parseQuantity(_threshold.text, _baseUnit) ?? Qty.zero,
      imagePath: widget.product?.imagePath,
      isActive: _isActive,
      createdAt: widget.product?.createdAt,
      updatedAt: widget.product?.updatedAt,
    );

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final CatalogController controller = ref.read(catalogControllerProvider);
      if (_isEditing) {
        await controller.updateProduct(product);
      } else {
        await controller.createProduct(product);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = failureMessage(l10n, error);
        _submitting = false;
      });
    }
  }

  // --- Interface ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppSettings settings =
        ref.watch(settingsProvider).valueOrNull ?? AppSettings.defaults;
    final List<Category> categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final List<Supplier> suppliers =
        ref.watch(suppliersProvider).valueOrNull ?? const <Supplier>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.productEditTitle : l10n.productNewTitle),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: <Widget>[
              if (_error != null) ...<Widget>[
                Text(_error!, style: TextStyle(color: scheme.error)),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.fieldName),
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _barcode,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.fieldBarcode,
                  helperText: l10n.productBarcodeHint,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: l10n.actionScan,
                        onPressed: _scan,
                        icon: const Icon(Icons.qr_code_scanner),
                      ),
                      IconButton(
                        tooltip: l10n.actionGenerate,
                        onPressed: _generating ? null : _generate,
                        icon: const Icon(Icons.auto_fix_high),
                      ),
                    ],
                  ),
                ),
                validator: _validateBarcode,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.fieldBaseUnit,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SegmentedButton<StockBaseUnit>(
                showSelectedIcon: false,
                segments: <ButtonSegment<StockBaseUnit>>[
                  ButtonSegment<StockBaseUnit>(
                    value: StockBaseUnit.piece,
                    label: Text(l10n.unitPiece),
                  ),
                  ButtonSegment<StockBaseUnit>(
                    value: StockBaseUnit.kilogram,
                    label: Text(l10n.unitKilogram),
                  ),
                ],
                selected: <StockBaseUnit>{_baseUnit},
                onSelectionChanged: (Set<StockBaseUnit> selection) => setState(
                  () => _baseUnit = selection.first,
                ),
              ),
              if (_baseUnit == StockBaseUnit.piece) ...<Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.productSoldByCarton),
                  value: _soldByCarton,
                  onChanged: (bool value) =>
                      setState(() => _soldByCarton = value),
                ),
                if (_soldByCarton)
                  TextFormField(
                    controller: _piecesPerCarton,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.labelPiecesPerCarton,
                    ),
                    validator: _validatePositiveInt,
                  ),
              ] else ...<Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.productSoldBySack),
                  value: _soldBySack,
                  onChanged: (bool value) =>
                      setState(() => _soldBySack = value),
                ),
                if (_soldBySack)
                  TextFormField(
                    controller: _kgPerSack,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(labelText: l10n.labelKgPerSack),
                    validator: _validatePositiveDecimal,
                  ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: categories.any(
                  (Category category) => category.id == _categoryId,
                )
                    ? _categoryId
                    : _noneSelected,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.fieldCategory),
                items: <DropdownMenuItem<int>>[
                  DropdownMenuItem<int>(
                    value: _noneSelected,
                    child: Text(l10n.productFilterCategory),
                  ),
                  for (final Category category in categories)
                    DropdownMenuItem<int>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (int? value) => setState(
                  () => _categoryId =
                      value == null || value == _noneSelected ? null : value,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: suppliers.any(
                  (Supplier supplier) => supplier.id == _supplierId,
                )
                    ? _supplierId
                    : _noneSelected,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.fieldSupplier),
                items: <DropdownMenuItem<int>>[
                  DropdownMenuItem<int>(
                    value: _noneSelected,
                    child: Text(l10n.productFilterSupplier),
                  ),
                  for (final Supplier supplier in suppliers)
                    DropdownMenuItem<int>(
                      value: supplier.id,
                      child: Text(supplier.displayName),
                    ),
                ],
                onChanged: (int? value) => setState(
                  () => _supplierId =
                      value == null || value == _noneSelected ? null : value,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _purchase,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.fieldPurchasePrice,
                  suffixText: settings.currencySymbol,
                ),
                validator: (String? value) =>
                    _validateMoney(value, isRequired: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _retail,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.fieldRetailPrice,
                  suffixText: settings.currencySymbol,
                ),
                validator: (String? value) =>
                    _validateMoney(value, isRequired: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _wholesale,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.fieldWholesalePrice,
                  suffixText: settings.currencySymbol,
                ),
                validator: (String? value) =>
                    _validateMoney(value, isRequired: false),
              ),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable:
                    Listenable.merge(<Listenable>[_purchase, _retail]),
                builder: (BuildContext context, Widget? child) {
                  final Money? purchase = parseMoney(_purchase.text);
                  final Money? retail = parseMoney(_retail.text);
                  if (purchase == null || retail == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${l10n.productMargin}: '
                      '${formatMoney(settings, retail - purchase)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _threshold,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.fieldLowStockThreshold,
                  suffixText: baseUnitLabel(l10n, _baseUnit),
                ),
                validator: _validateOptionalQuantity,
              ),
              if (!_isEditing) ...<Widget>[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _initialStock,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.productInitialStock,
                    suffixText: baseUnitLabel(l10n, _baseUnit),
                  ),
                  validator: _validateOptionalQuantity,
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.productActive),
                value: _isActive,
                onChanged: (bool value) => setState(() => _isActive = value),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(l10n.actionSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
